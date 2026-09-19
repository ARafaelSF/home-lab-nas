#!/usr/bin/env python3
"""Failover do DNAT UniFi (DNS forçado) entre AdGuard .21 e backup .22.

Quando o AdGuard principal (192.168.3.21) deixa de responder em :53, as regras
DNAT «DNS → AdGuard» passam a apontar para 192.168.3.22 — assim clientes com
DNS hardcoded (8.8.8.8) continuam a resolver. Ao recuperar o .21, reverte.

Corre no Pi (adguard-backup), que permanece ligado se o servidor principal cair.
"""
from __future__ import annotations

import json
import os
import socket
import ssl
import struct
import sys
import time
import urllib.error
import urllib.request
from http.cookiejar import CookieJar
from pathlib import Path

PRIMARY = os.environ.get("ADGUARD_PRIMARY", "192.168.3.21")
BACKUP = os.environ.get("ADGUARD_BACKUP", "192.168.3.22")
FAIL_THRESHOLD = int(os.environ.get("FAIL_THRESHOLD", "3"))
OK_THRESHOLD = int(os.environ.get("OK_THRESHOLD", "3"))
STATE_PATH = Path(os.environ.get("STATE_PATH", str(Path.home() / ".cache/adguard-dnat-failover.json")))

UNIFI_HOST = os.environ.get("UNIFI_HOST", "192.168.3.1").rstrip("/")
if not UNIFI_HOST.startswith("http"):
    UNIFI_HOST = "https://" + UNIFI_HOST
UNIFI_USER = os.environ["UNIFI_USERNAME"]
UNIFI_PASS = os.environ["UNIFI_PASSWORD"]


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def dns_alive(server: str, timeout: float = 1.5) -> bool:
    """Consulta A mínima a example.com — basta o servidor responder (mesmo NXDOMAIN)."""
    def encode(name: str) -> bytes:
        out = b""
        for part in name.split("."):
            out += bytes([len(part)]) + part.encode()
        return out + b"\x00"

    pkt = (
        b"\xab\xcd\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00"
        + encode("example.com")
        + b"\x00\x01\x00\x01"
    )
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(timeout)
    try:
        sock.sendto(pkt, (server, 53))
        data, _ = sock.recvfrom(512)
        return len(data) >= 12
    except OSError:
        return False
    finally:
        sock.close()


class UniFi:
    def __init__(self) -> None:
        self.ctx = ssl._create_unverified_context()
        self.cj = CookieJar()
        self.csrf: str | None = None
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPSHandler(context=self.ctx),
            urllib.request.HTTPCookieProcessor(self.cj),
        )

    def _capture_csrf(self, resp) -> None:
        t = resp.headers.get("X-Csrf-Token") or resp.headers.get("x-updated-csrf-token")
        if t:
            self.csrf = t

    def login(self) -> None:
        last_err: Exception | None = None
        for attempt in range(1, 6):
            try:
                req = urllib.request.Request(
                    f"{UNIFI_HOST}/api/auth/login",
                    data=json.dumps({"username": UNIFI_USER, "password": UNIFI_PASS}).encode(),
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                with self.opener.open(req, timeout=15) as resp:
                    self._capture_csrf(resp)
                    resp.read()
                if not self.csrf:
                    for c in self.cj:
                        if c.name == "TOKEN":
                            self.csrf = c.value
                            break
                return
            except urllib.error.HTTPError as e:
                last_err = e
                if e.code == 429:
                    wait = min(30, 2 ** attempt)
                    log(f"UniFi login 429 — a aguardar {wait}s (tentativa {attempt})")
                    time.sleep(wait)
                    continue
                raise
        raise RuntimeError(f"UniFi login falhou após retries: {last_err}")

    def api(self, method: str, path: str, data=None):
        headers = {"Content-Type": "application/json", "X-CSRF-Token": self.csrf or ""}
        body = None if data is None else json.dumps(data).encode()
        last_err: Exception | None = None
        for attempt in range(1, 6):
            req = urllib.request.Request(
                f"{UNIFI_HOST}{path}", data=body, headers=headers, method=method
            )
            try:
                with self.opener.open(req, timeout=20) as resp:
                    self._capture_csrf(resp)
                    raw = resp.read()
                    return resp.status, (json.loads(raw) if raw else None)
            except urllib.error.HTTPError as e:
                last_err = e
                err = e.read().decode(errors="replace")
                if e.code == 429:
                    wait = min(30, 2 ** attempt)
                    log(f"UniFi {method} {path} 429 — a aguardar {wait}s (tentativa {attempt})")
                    time.sleep(wait)
                    continue
                raise RuntimeError(f"UniFi {method} {path} -> {e.code}: {err[:300]}") from e
        raise RuntimeError(f"UniFi {method} {path} falhou após retries: {last_err}")

    def list_nat(self):
        st, rules = self.api("GET", "/proxy/network/v2/api/site/default/nat")
        if st != 200 or not isinstance(rules, list):
            raise RuntimeError(f"list nat failed: {st}")
        return rules

    def put_nat(self, rule: dict):
        rid = rule["_id"]
        st, res = self.api("PUT", f"/proxy/network/v2/api/site/default/nat/{rid}", rule)
        if st != 200:
            raise RuntimeError(f"put nat {rid} failed: {st} {res}")
        return res


def load_state() -> dict:
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text())
        except Exception:
            pass
    return {"target": PRIMARY, "fail_streak": 0, "ok_streak": 0}


def save_state(state: dict) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, indent=2) + "\n")


def desired_target(primary_ok: bool, backup_ok: bool, state: dict) -> str | None:
    """Devolve o IP alvo desejado, ou None se ainda dentro da histerese."""
    current = state.get("target") or PRIMARY
    if primary_ok:
        state["ok_streak"] = int(state.get("ok_streak") or 0) + 1
        state["fail_streak"] = 0
        if current != PRIMARY and state["ok_streak"] >= OK_THRESHOLD:
            return PRIMARY
        return None
    # primary down
    state["fail_streak"] = int(state.get("fail_streak") or 0) + 1
    state["ok_streak"] = 0
    if not backup_ok:
        log(f"AVISO: {PRIMARY} em baixo e {BACKUP} também não responde — sem failover")
        return None
    if current != BACKUP and state["fail_streak"] >= FAIL_THRESHOLD:
        return BACKUP
    return None


def apply_target(u: UniFi, target: str) -> int:
    rules = u.list_nat()
    changed = 0
    for rule in rules:
        rtype = rule.get("type")
        desc = rule.get("description") or ""
        if rtype == "DNAT" and "DNS" in desc and "AdGuard" in desc:
            if rule.get("ip_address") == target:
                continue
            upd = dict(rule)
            upd["ip_address"] = target
            u.put_nat(upd)
            log(f"DNAT actualizado: {desc} → {target}")
            changed += 1
        elif rtype == "MASQUERADE" and "AdGuard" in desc:
            df = dict(rule.get("destination_filter") or {})
            if df.get("address") == target and str(df.get("port")) == "53":
                continue
            upd = dict(rule)
            df["address"] = target
            df["port"] = "53"
            df["filter_type"] = df.get("filter_type") or "ADDRESS_AND_PORT"
            upd["destination_filter"] = df
            u.put_nat(upd)
            log(f"MASQUERADE actualizado: {desc} → {target}:53")
            changed += 1
    return changed


def current_dnat_target(u: UniFi) -> str | None:
    for rule in u.list_nat():
        if rule.get("type") == "DNAT" and "DNS" in (rule.get("description") or ""):
            return rule.get("ip_address")
    return None


def main() -> int:
    state = load_state()
    primary_ok = dns_alive(PRIMARY)
    backup_ok = dns_alive(BACKUP)
    log(
        f"probe primary={PRIMARY} {'OK' if primary_ok else 'DOWN'} · "
        f"backup={BACKUP} {'OK' if backup_ok else 'DOWN'} · "
        f"state_target={state.get('target')} fail={state.get('fail_streak')} ok={state.get('ok_streak')}"
    )

    want = desired_target(primary_ok, backup_ok, state)
    if want is None:
        # Sem mudança: não contactar UniFi (evita rate-limit). Só grava histerese.
        save_state(state)
        return 0

    u = UniFi()
    u.login()
    live = current_dnat_target(u)
    log(f"failover → {want} (UniFi estava em {live})")
    n = apply_target(u, want)
    state["target"] = want
    if want == PRIMARY:
        state["ok_streak"] = 0
    else:
        state["fail_streak"] = 0
    save_state(state)
    log(f"concluído: {n} regra(s) alterada(s)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log(f"ERRO: {e}")
        sys.exit(1)
