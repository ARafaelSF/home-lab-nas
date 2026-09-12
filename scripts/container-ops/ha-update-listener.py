#!/usr/bin/env python3
"""Listener LAN para o Home Assistant disparar o ops.sh do repositório homelab."""
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

_REPO = Path(__file__).resolve().parent
OPS_SH = os.environ.get("CONTAINER_OPS_SH", str(_REPO / "ops.sh"))
SHUTDOWN_SH = os.environ.get(
    "CONTAINER_OPS_SHUTDOWN_SH", str(_REPO / "safe-shutdown.sh")
)
APPS_CONF = os.environ.get("CONTAINER_OPS_APPS", str(_REPO / "apps.conf"))
TOKEN = os.environ.get("DOCKER_OPS_TOKEN", "")
HA_WEBHOOK = os.environ.get(
    "HA_WEBHOOK_URL",
    "http://192.168.3.10:8123/api/webhook/docker_ops_update_result",
)
HA_SHUTDOWN_WEBHOOK = os.environ.get(
    "HA_SHUTDOWN_WEBHOOK_URL",
    "http://192.168.3.10:8123/api/webhook/homelab_safe_shutdown_result",
)
LISTEN_HOST = os.environ.get("LISTEN_HOST", "192.168.3.21")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "8787"))
ALLOWED_PREFIXES = tuple(
    p.strip()
    for p in os.environ.get("ALLOWED_PREFIXES", "192.168.3.10,127.0.0.1").split(",")
    if p.strip()
)
LOG_DIR = Path(os.environ.get("CONTAINER_OPS_LOG_DIR", "/opt/container-ops/logs"))
APP_RE = re.compile(r"^(all|pending|catalog|everything|[a-z0-9]+(?:-[a-z0-9]+)*)$")
SHUTDOWN_CONFIRM = "DESLIGAR"

_lock = threading.Lock()
_busy_app: str | None = None
_shutdown_pending = False


def log(msg: str) -> None:
    print(f"[ha-update] {msg}", flush=True)


def known_apps() -> set[str]:
    apps: set[str] = {"all", "pending", "catalog", "everything"}
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
    "all": "containers pendentes",
    "pending": "containers pendentes",
    "catalog": "todo o catálogo Docker",
    "everything": "todo o catálogo Docker",
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


FALHOU_RE = re.compile(r"FALHOU:\s+(\S+)")
FAILED_APPS_RE = re.compile(r"FAILED_APPS=(.+)")
UPDATED_APPS_RE = re.compile(r"UPDATED_APPS=(.+)")
VERSION_RE = re.compile(r"VERSION_(FROM|TO)=([^|\s]+)\|([^\n]+)")
OK_APP_RE = re.compile(r"\] OK: ([a-z0-9]+(?:-[a-z0-9]+)*)\s*$", re.M)


def _unique_apps(apps: list[str]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for app in apps:
        if app and app not in seen:
            seen.add(app)
            ordered.append(app)
    return ordered


def parse_failed_apps(text: str) -> list[str]:
    apps: list[str] = []
    for match in FAILED_APPS_RE.finditer(text):
        apps.extend(a for a in match.group(1).replace(",", " ").split() if a)
    if not apps:
        apps = FALHOU_RE.findall(text)
    return _unique_apps(apps)


def parse_updated_apps(text: str) -> list[str]:
    apps: list[str] = []
    for match in UPDATED_APPS_RE.finditer(text):
        apps.extend(a for a in match.group(1).replace(",", " ").split() if a)
    if not apps:
        apps = OK_APP_RE.findall(text)
    return _unique_apps(apps)


def _clean_ver(ver: str) -> str:
    v = (ver or "").strip()
    if not v or v == "?":
        return ""
    return v


def parse_versions(text: str) -> tuple[dict[str, str], dict[str, str]]:
    froms: dict[str, str] = {}
    tos: dict[str, str] = {}
    for match in VERSION_RE.finditer(text):
        kind, app, ver = match.group(1), match.group(2).strip(), _clean_ver(match.group(3))
        if not ver:
            continue
        if kind == "FROM":
            froms[app] = ver
        else:
            tos[app] = ver
    return froms, tos


def version_lines(
    froms: dict[str, str],
    tos: dict[str, str],
    failed: list[str],
    updated: list[str] | None = None,
) -> list[str]:
    failed_set = set(failed)
    apps: list[str] = []
    for app in list(updated or []) + list(froms) + list(tos) + failed:
        if app not in apps:
            apps.append(app)
    lines: list[str] = []
    for app in apps:
        nome = friendly_name(app)
        atual, nova = froms.get(app), tos.get(app)
        if app in failed_set:
            if atual:
                lines.append(f"{nome}: falhou (estava {atual})")
            else:
                lines.append(f"{nome}: falhou")
        elif atual and nova:
            lines.append(f"{nome}: {atual} → {nova}")
        elif nova:
            lines.append(f"{nome}: → {nova}")
        elif atual:
            lines.append(f"{nome}: estava {atual}")
        else:
            lines.append(f"{nome}: atualizado")
    return lines


def friendly_summary(
    ok: bool,
    app: str,
    failed: list[str] | None = None,
    froms: dict[str, str] | None = None,
    tos: dict[str, str] | None = None,
    updated: list[str] | None = None,
) -> str:
    nome = friendly_name(app)
    failed = failed or []
    updated = list(updated or [])
    if app != "all" and app not in updated and ok:
        updated = [app] + updated
    lines = version_lines(froms or {}, tos or {}, failed, updated)
    extra = ("\n" + "\n".join(lines)) if lines else ""
    if app == "all":
        if ok:
            return "Atualizei os containers com update pendente." + extra
        if failed:
            nomes = ", ".join(friendly_name(a) for a in failed)
            return f"Não atualizei: {nomes}. Os outros ficaram ok." + extra
        return "Alguns containers não atualizaram. Vê o detalhe no Home Assistant." + extra
    if ok:
        if extra:
            return f"O {nome} foi atualizado.{extra}"
        return f"O {nome} foi atualizado e já está a correr."
    return f"Não consegui atualizar o {nome}. Vê o detalhe no Home Assistant." + extra



def notify_ha(
    ok: bool,
    app: str,
    message: str,
    summary: str | None = None,
    webhook: str | None = None,
) -> None:
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
        webhook or HA_WEBHOOK,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            log(f"webhook HA {resp.status} app={app} ok={ok}")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        log(f"webhook HA falhou: {exc}")


def notify_shutdown(ok: bool, message: str) -> None:
    data = json.dumps({"ok": ok, "message": message[:3500]}).encode()
    req = urllib.request.Request(
        HA_SHUTDOWN_WEBHOOK,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            log(f"webhook shutdown HA {resp.status} ok={ok}")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        log(f"webhook shutdown HA falhou (esperado se HA já estiver a desligar): {exc}")


def run_shutdown() -> None:
    global _shutdown_pending
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOG_DIR / "ha-shutdown-last.log"
    cmd = [SHUTDOWN_SH]
    log(f"a correr: {' '.join(cmd)}")
    try:
        with log_path.open("w") as fh:
            proc = subprocess.run(
                cmd,
                stdout=fh,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=120,
                check=False,
            )
        text = log_path.read_text(errors="replace")
        ok = proc.returncode == 0
        msg = (
            "Desligamento seguro aceite: Home Assistant → Docker → Proxmox."
            if ok
            else f"Falha ao iniciar desligamento (código {proc.returncode})."
        )
        log(msg)
        notify_shutdown(ok, msg + ("\n" + text[-1500:] if text else ""))
    except subprocess.TimeoutExpired:
        notify_shutdown(False, "O script de desligamento demorou demais a responder.")
    except OSError as exc:
        notify_shutdown(False, f"Falha ao iniciar o script: {exc}")
    finally:
        with _lock:
            _shutdown_pending = False
        log("shutdown: livre (se o host continuar online)")


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
        ok = proc.returncode == 0
        failed = parse_failed_apps(text)
        updated = parse_updated_apps(text)
        froms, tos = parse_versions(text)
        summary = friendly_summary(ok, app, failed, froms, tos, updated)
        log(f"resumo: {summary.replace(chr(10), ' | ')}")
        notify_ha(ok, app, summary, summary=summary)
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
        json_bytes(
            {"ok": True, "busy": _busy_app, "shutdown_pending": _shutdown_pending},
            200,
            self,
        )

    def do_POST(self) -> None:  # noqa: N802
        global _busy_app, _shutdown_pending
        path = self.path.rstrip("/")
        if path not in {"/update", "/shutdown"}:
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

        if path == "/shutdown":
            confirm = str(payload.get("confirm") or "").strip()
            if confirm != SHUTDOWN_CONFIRM:
                json_bytes(
                    {
                        "error": "confirmacao invalida",
                        "hint": f'envie {{"confirm":"{SHUTDOWN_CONFIRM}"}}',
                    },
                    400,
                    self,
                )
                return
            with _lock:
                if _shutdown_pending or _busy_app:
                    json_bytes(
                        {
                            "error": "busy",
                            "app": _busy_app,
                            "shutdown_pending": _shutdown_pending,
                        },
                        409,
                        self,
                    )
                    return
                _shutdown_pending = True
            threading.Thread(target=run_shutdown, daemon=True).start()
            json_bytes({"accepted": True, "action": "safe-shutdown"}, 202, self)
            return

        app = str(payload.get("app") or "").strip()
        if not APP_RE.match(app) or app not in known_apps():
            json_bytes({"error": "app desconhecida", "app": app}, 400, self)
            return
        with _lock:
            if _busy_app or _shutdown_pending:
                json_bytes(
                    {
                        "error": "busy",
                        "app": _busy_app,
                        "shutdown_pending": _shutdown_pending,
                    },
                    409,
                    self,
                )
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
