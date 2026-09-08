#!/usr/bin/env python3
"""Listener LAN para o Home Assistant disparar /opt/container-ops/ops.sh."""
from __future__ import annotations

import json
import os
import re
import subprocess
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

OPS_SH = os.environ.get("CONTAINER_OPS_SH", "/opt/container-ops/ops.sh")
APPS_CONF = os.environ.get("CONTAINER_OPS_APPS", "/opt/container-ops/apps.conf")
TOKEN = os.environ.get("DOCKER_OPS_TOKEN", "")
HA_WEBHOOK = os.environ.get(
    "HA_WEBHOOK_URL",
    "http://192.168.3.10:8123/api/webhook/docker_ops_update_result",
)
LISTEN_HOST = os.environ.get("LISTEN_HOST", "192.168.3.21")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "8787"))
ALLOWED_PREFIXES = tuple(
    p.strip()
    for p in os.environ.get("ALLOWED_PREFIXES", "192.168.3.10,127.0.0.1").split(",")
    if p.strip()
)
LOG_DIR = Path(os.environ.get("CONTAINER_OPS_LOG_DIR", "/opt/container-ops/logs"))
APP_RE = re.compile(r"^(all|[a-z0-9]+(?:-[a-z0-9]+)*)$")

_lock = threading.Lock()
_busy_app: str | None = None


def log(msg: str) -> None:
    print(f"[ha-update] {msg}", flush=True)


def known_apps() -> set[str]:
    apps: set[str] = {"all"}
    path = Path(APPS_CONF)
    if not path.exists():
        return apps
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or "|" not in line:
            continue
        apps.add(line.split("|", 1)[0].strip())
    return apps


def authorized(handler: BaseHTTPRequestHandler) -> bool:
    if not TOKEN:
        return False
    header = handler.headers.get("Authorization", "")
    expected = TOKEN if TOKEN.lower().startswith("bearer ") else f"Bearer {TOKEN}"
    if header.strip() != expected:
        return False
    peer = handler.client_address[0]
    return any(peer == p or peer.startswith(p) for p in ALLOWED_PREFIXES)


def json_bytes(payload: dict, code: int, handler: BaseHTTPRequestHandler) -> None:
    body = json.dumps(payload).encode()
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


APP_LABELS = {
    "all": "todos os containers",
    "adguard": "AdGuard Home",
    "cadvisor": "cAdvisor",
    "cloudflare": "Cloudflare Tunnel",
    "dozzle": "Dozzle",
    "duplicati": "Duplicati",
    "filebrowser": "Filebrowser",
    "firefly": "Firefly III",
    "grafana": "Grafana",
    "hermes": "Hermes",
    "homepage": "Homepage",
    "immich": "Immich",
    "immich-ml": "Immich ML",
    "influx": "Influx",
    "jellyfin": "Jellyfin",
    "mealie": "Mealie",
    "npm": "Nginx Proxy Manager",
    "node-exporter": "Node Exporter",
    "prometheus": "Prometheus",
    "uptime-kuma": "Uptime Kuma",
    "vaultwarden": "Vaultwarden",
    "wud": "WUD",
    "ping-exporter": "Ping Exporter",
    "blackbox-exporter": "Blackbox Exporter",
    "speedtest-exporter": "Speedtest Exporter",
    "unifi-mcp": "UniFi Network MCP",
}


def friendly_name(app: str) -> str:
    return APP_LABELS.get(app, app)


def friendly_summary(ok: bool, app: str) -> str:
    nome = friendly_name(app)
    if app == "all":
        if ok:
            return "Atualizei todos os containers. Já estão a correr."
        return "Alguns containers não atualizaram. Vê o detalhe no Home Assistant."
    if ok:
        return f"O {nome} foi atualizado e já está a correr."
    return f"Não consegui atualizar o {nome}. Vê o detalhe no Home Assistant."


def notify_ha(ok: bool, app: str, message: str, summary: str | None = None) -> None:
    data = json.dumps(
        {
            "ok": ok,
            "app": app,
            "nome": friendly_name(app),
            "summary": summary or friendly_summary(ok, app),
            "message": message[:3500],
        }
    ).encode()
    req = urllib.request.Request(
        HA_WEBHOOK,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            log(f"webhook HA {resp.status} app={app} ok={ok}")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        log(f"webhook HA falhou: {exc}")


def run_update(app: str) -> None:
    global _busy_app
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOG_DIR / "ha-update-last.log"
    cmd = [OPS_SH, "update", app]
    log(f"a correr: {' '.join(cmd)}")
    try:
        with log_path.open("w") as fh:
            proc = subprocess.run(
                cmd,
                stdout=fh,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=7200,
                check=False,
            )
        text = log_path.read_text(errors="replace")
        useful = [
            ln
            for ln in text.splitlines()
            if ln.strip()
            and "Extracting" not in ln
            and "Downloading" not in ln
            and "Pull complete" not in ln
        ]
        tail = "\n".join(useful[-12:]) or "(sem output)"
        ok = proc.returncode == 0
        notify_ha(ok, app, tail)
    except subprocess.TimeoutExpired:
        notify_ha(
            False,
            app,
            "A atualização demorou mais de 2 horas e foi interrompida.",
        )
    except OSError as exc:
        notify_ha(False, app, f"Falha ao iniciar o script: {exc}")
    finally:
        with _lock:
            _busy_app = None
        log("livre")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        log("%s - " % self.address_string() + fmt % args)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.rstrip("/") != "/health":
            json_bytes({"error": "not found"}, 404, self)
            return
        json_bytes({"ok": True, "busy": _busy_app}, 200, self)

    def do_POST(self) -> None:  # noqa: N802
        global _busy_app
        if self.path.rstrip("/") != "/update":
            json_bytes({"error": "not found"}, 404, self)
            return
        if not authorized(self):
            json_bytes({"error": "forbidden"}, 403, self)
            return
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length > 4096:
            json_bytes({"error": "payload too large"}, 413, self)
            return
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except json.JSONDecodeError:
            json_bytes({"error": "invalid json"}, 400, self)
            return
        app = str(payload.get("app") or "").strip()
        if not APP_RE.match(app) or app not in known_apps():
            json_bytes({"error": "app desconhecida", "app": app}, 400, self)
            return
        with _lock:
            if _busy_app:
                json_bytes({"error": "busy", "app": _busy_app}, 409, self)
                return
            _busy_app = app
        threading.Thread(target=run_update, args=(app,), daemon=True).start()
        json_bytes({"accepted": True, "app": app}, 202, self)


def main() -> None:
    if not TOKEN:
        raise SystemExit("DOCKER_OPS_TOKEN vazio")
    httpd = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    log(f"à escuta em {LISTEN_HOST}:{LISTEN_PORT}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
