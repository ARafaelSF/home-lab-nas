#!/usr/bin/env python3
"""DEPRECATED: usar rest_command + automação. Publica device_availability no Influx (mesma lógica do sensor.dispositivos_offline)."""
from __future__ import annotations

import json
import os
import sys
import traceback
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

LOG = Path("/config/www/device_availability_export.log")

# Mesma regra do contador; inclui online e offline. Legenda = Área — Nome do dispositivo.
TEMPLATE = r"""
{% set domains = ['light', 'switch', 'climate', 'cover', 'fan', 'lock', 'vacuum', 'media_player', 'binary_sensor', 'sensor'] %}
{% set ns = namespace(seen=[], lines=[]) %}
{% for d in domains %}
  {% for e in states[d] %}
    {% set eid = e.entity_id %}
    {% if 'ap_unifi_led' not in eid
         and 'alarme_indicacao' not in eid
         and 'termocirculador' not in eid
         and 'embaralhar' not in eid
         and 'repita' not in eid
         and 'firestick' not in eid
         and 'fire_tv' not in eid
         and 'camera' not in eid
         and 'choro' not in eid
         and 'alexa_app_for_pc' not in eid
         and 'usina_' not in eid
         and 'inkbird' not in eid
         and 'umidificador' not in eid
         and 'unifi_network' not in eid
         and 'grupo_de_som' not in eid
         and '_dispositivos' not in eid
         and 'announcements' not in eid
         and 'communications' not in eid
         and 'linkquality' not in eid
         and 'last_seen' not in eid
         and '_action' not in eid
         and 'dispositivos_offline' not in eid
         and 'amazfit' not in eid
         and 'system_monitor' not in eid
         and 'tarifas_cemig' not in eid
         and 'this_device_' not in eid
         and 'energy_production' not in eid
         and 'energy_current' not in eid
         and 'energy_next' not in eid
         and 'power_production' not in eid
         and 'power_highest' not in eid
         and 'wifi_visitantes' not in eid
         and 'contadores_da_casa' not in eid
         and 'time_remaining' not in eid
         and 'total_duration' not in eid
         and 'time_format' not in eid
         and '_voltage' not in eid
         and '_bateria_' not in eid
         and 'battery' not in eid %}
      {% set incluir = true %}
      {% if d == 'media_player' %}
        {% set incluir = ('echo' in eid) %}
      {% elif 'echo' in eid or 'alexa' in eid or 'mediaplayer' in eid %}
        {% set incluir = false %}
      {% elif d == 'sensor' %}
        {% set incluir = ('_z2m_' in eid or '_tuya_' in eid or 'localtuya' in eid or 'presenca' in eid or 'occupancy' in eid) %}
      {% elif d == 'binary_sensor' %}
        {% set incluir = (
          'presenca' in eid or 'occupancy' in eid or 'motion' in eid or 'movimento' in eid
          or 'door' in eid or 'porta' in eid or 'window' in eid or 'janela' in eid
          or 'moisture' in eid or 'smoke' in eid or 'leak' in eid
          or '_z2m_' in eid or '_tuya_' in eid or 'localtuya' in eid
        ) %}
      {% endif %}
      {% if incluir %}
        {% set did = device_id(eid) %}
        {% set key = ('echo:' ~ (area_id(eid) or eid)) if (d == 'media_player' and 'echo' in eid) else (did if did else eid) %}
        {% if key not in ns.seen %}
          {% set ns.seen = ns.seen + [key] %}
          {% set area = area_name(eid) or 'Sem área' %}
          {% set nm = (device_attr(did, 'name_by_user') if did else none) or (device_attr(did, 'name') if did else none) or state_attr(eid, 'friendly_name') or eid %}
          {% set label = area ~ ' — ' ~ nm %}
          {% set esc = label | replace('\\', '\\\\') | replace(' ', '\\ ') | replace(',', '\\,') | replace('=', '\\=') %}
          {% set off = 1 if e.state in ['unavailable', 'unknown'] else 0 %}
          {% set on = 0 if off == 1 else 1 %}
          {% set ns.lines = ns.lines + ['device_availability,device=' ~ esc ~ ' online=' ~ on ~ 'i,offline=' ~ off ~ 'i'] %}
        {% endif %}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endfor %}
{{ ns.lines | join('\n') }}
""".strip()


def log(msg: str) -> None:
    line = msg.rstrip() + "\n"
    try:
        prev = LOG.read_text(encoding="utf-8") if LOG.exists() else ""
        # keep last ~50 KB
        LOG.write_text((prev + line)[-50000:], encoding="utf-8")
    except Exception:
        pass
    print(msg)


def load_influx_config() -> dict:
    entries = json.loads(Path("/config/.storage/core.config_entries").read_text(encoding="utf-8"))
    for entry in entries.get("data", {}).get("entries", []):
        if entry.get("domain") == "influxdb":
            data = entry.get("data", {})
            if data.get("token") and data.get("bucket"):
                return data
    raise SystemExit("Config entry influxdb não encontrada")


def ha_render_template(template: str) -> str:
    token = os.environ.get("SUPERVISOR_TOKEN")
    if not token:
        raise SystemExit("SUPERVISOR_TOKEN ausente")
    body = json.dumps({"template": template}).encode("utf-8")
    last_err = None
    for url in (
        "http://supervisor/core/api/template",
        "http://127.0.0.1:8123/api/template",
    ):
        req = urllib.request.Request(
            url,
            data=body,
            method="POST",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read().decode("utf-8")
        except Exception as exc:  # noqa: BLE001
            last_err = exc
    raise RuntimeError(f"Falha ao renderizar template: {last_err}")


def influx_write(url: str, org: str, bucket: str, token: str, lines: list[str]) -> None:
    body = ("\n".join(lines) + "\n").encode("utf-8")
    auth = token if token.lower().startswith("token ") else f"Token {token}"
    req = urllib.request.Request(
        f"{url.rstrip('/')}/api/v2/write?"
        + urllib.parse.urlencode({"org": org, "bucket": bucket, "precision": "s"}),
        data=body,
        method="POST",
        headers={
            "Authorization": auth,
            "Content-Type": "text/plain; charset=utf-8",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Influx write HTTP {exc.code}: {detail}") from exc


def main() -> None:
    cfg = load_influx_config()
    payload = ha_render_template(TEMPLATE).strip()
    if not payload:
        raise RuntimeError("Template devolveu payload vazio")
    lines = [ln for ln in payload.splitlines() if ln.strip()]
    offline = sum(1 for ln in lines if "offline=1i" in ln)
    for i in range(0, len(lines), 200):
        influx_write(cfg["url"], cfg["organization"], cfg["bucket"], cfg["token"], lines[i : i + 200])
    log(f"OK devices={len(lines)} offline={offline}")


if __name__ == "__main__":
    try:
        main()
    except BaseException:
        log("ERRO:\n" + traceback.format_exc())
        sys.exit(1)
