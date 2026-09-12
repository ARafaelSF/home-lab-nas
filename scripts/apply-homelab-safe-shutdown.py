#!/usr/bin/env python3
"""Aplica botão/script de desligamento seguro no Home Assistant (via Proxmox guest agent)."""
from __future__ import annotations

import base64
import json
import re
import subprocess
import sys
from pathlib import Path

VMID = "101"
CONF = "/mnt/data/supervisor/homeassistant"


def guest(cmd: str, check: bool = True) -> str:
    out = subprocess.check_output(
        ["ssh", "proxmox", f"qm guest exec {VMID} -- bash -lc {json.dumps(cmd)}"],
        text=True,
    )
    data = json.loads(out)
    code = data.get("exitcode")
    if check and code not in (0, None):
        err = data.get("err-data") or data.get("out-data") or data
        raise RuntimeError(f"guest exec failed ({code}): {err}")
    return data.get("out-data") or ""


def guest_write(path: str, content: str | bytes) -> None:
    raw = content if isinstance(content, bytes) else content.encode()
    if len(raw) > 1_000_000:
        raise RuntimeError(f"ficheiro demasiado grande para guest stdin: {path} ({len(raw)} bytes)")
    local = Path(f"/tmp/ha-guest-write-{Path(path).name}")
    local.write_bytes(raw)
    # qm guest exec --pass-stdin encaminha STDIN (máx. ~1 MiB)
    proc = subprocess.run(
        [
            "ssh",
            "proxmox",
            f"qm guest exec {VMID} --pass-stdin 1 --timeout 120 -- dd of={path} status=none",
        ],
        input=raw,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"scp/ssh falhou: {proc.stderr.decode(errors='replace')}")
    try:
        data = json.loads(proc.stdout.decode())
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"resposta guest inválida: {proc.stdout[:500]!r}") from exc
    if data.get("exitcode") not in (0, None):
        raise RuntimeError(f"guest write failed: {data}")
    local.unlink(missing_ok=True)


def guest_read(path: str) -> str:
    b64 = guest(f"base64 -w0 {path}").strip()
    return base64.b64decode(b64).decode()


def main() -> int:
    bearer = Path("/tmp/ha_docker_ops_bearer").read_text().strip()
    if len(bearer) < 20:
        print("Bearer em falta — corre antes a extracção", file=sys.stderr)
        return 1

    secrets = guest_read(f"{CONF}/secrets.yaml")
    if "docker_ops_shutdown_curl" not in secrets:
        block = (
            "\n# Desligamento seguro Homelab (HA → Docker → Proxmox)\n"
            "docker_ops_shutdown_curl: >-\n"
            "  curl -sS -f --max-time 20 -X POST\n"
            f'  -H "Authorization: Bearer {bearer}"\n'
            '  -H "Content-Type: application/json"\n'
            "  -d '{\"confirm\": \"DESLIGAR\"}'\n"
            "  http://192.168.3.21:8787/shutdown\n"
        )
        # insert after docker_ops_update_curl block (before next top-level key that isn't indented)
        if "docker_ops_update_curl:" not in secrets:
            secrets = secrets.rstrip() + "\n" + block
        else:
            # append near docker_ops
            secrets = secrets.rstrip() + "\n" + block
        guest_write(f"{CONF}/secrets.yaml", secrets)
        print("secrets.yaml: adicionou docker_ops_shutdown_curl")
    else:
        print("secrets.yaml: já tinha docker_ops_shutdown_curl")

    conf = guest_read(f"{CONF}/configuration.yaml")
    if "docker_ops_shutdown:" not in conf:
        conf = conf.replace(
            "  docker_ops_update: !secret docker_ops_update_curl\n",
            "  docker_ops_update: !secret docker_ops_update_curl\n"
            "  docker_ops_shutdown: !secret docker_ops_shutdown_curl\n",
        )
        if "docker_ops_shutdown:" not in conf:
            raise RuntimeError("não consegui inserir shell_command docker_ops_shutdown")
        guest_write(f"{CONF}/configuration.yaml", conf)
        print("configuration.yaml: shell_command docker_ops_shutdown")
    else:
        print("configuration.yaml: já tinha docker_ops_shutdown")

    scripts = guest_read(f"{CONF}/scripts.yaml")
    if "sistema_homelab_desligar_seguro:" not in scripts:
        scripts = scripts.rstrip() + "\n" + SCRIPT_YAML
        guest_write(f"{CONF}/scripts.yaml", scripts)
        print("scripts.yaml: sistema_homelab_desligar_seguro")
    else:
        print("scripts.yaml: já tinha sistema_homelab_desligar_seguro")

    autos = guest_read(f"{CONF}/automations.yaml")
    if "homelab_safe_shutdown_result_20260912" not in autos:
        # automations.yaml is a list — append item
        autos = autos.rstrip() + "\n" + AUTOMATION_YAML
        guest_write(f"{CONF}/automations.yaml", autos)
        print("automations.yaml: webhook resultado")
    else:
        print("automations.yaml: já tinha webhook")

    # Lovelace
    raw = guest_read(f"{CONF}/.storage/lovelace.dashboard_casa")
    store = json.loads(raw)
    views = store["data"]["config"]["views"]
    view = next(v for v in views if v.get("path") == "servidor")
    sec = view["sections"][1]
    cards = sec["cards"]
    already = any(
        (c.get("name") == "Desligar com segurança")
        or (c.get("tap_action", {}).get("service") == "script.sistema_homelab_desligar_seguro")
        for c in cards
    )
    if not already:
        btn = {
            "type": "button",
            "name": "Desligar com segurança",
            "icon": "mdi:power",
            "show_name": True,
            "show_icon": True,
            "grid_options": {"columns": 12, "rows": 2},
            "tap_action": {
                "action": "call-service",
                "service": "script.sistema_homelab_desligar_seguro",
                "confirmation": {
                    "text": "Vai desligar Home Assistant, a VM Docker e o Proxmox. Continuar?"
                },
            },
        }
        # depois do grid de energia (index 1), antes do botão de tomada
        cards.insert(2, btn)
        guest_write(
            f"{CONF}/.storage/lovelace.dashboard_casa",
            json.dumps(store, ensure_ascii=False, indent=2) + "\n",
        )
        Path("/tmp/lovelace.dashboard_casa.patched.json").write_text(
            json.dumps(store, ensure_ascii=False, indent=2) + "\n"
        )
        print("lovelace: botão inserido na view Servidor")
    else:
        print("lovelace: botão já existia")

    print("A verificar config…")
    print(guest("ha core check", check=False)[:500])
    print("A reiniciar o Core do HA para carregar shell_command/script…")
    print(guest("ha core restart", check=False)[:500])
    print("OK — HA a reiniciar (1–2 min).")
    return 0


SCRIPT_YAML = """
sistema_homelab_desligar_seguro:
  alias: Homelab — desligar com segurança
  description: Desliga HA (VM 101), Docker (VM 100) e o host Proxmox, por ordem.
  icon: mdi:power
  mode: single
  sequence:
  - action: persistent_notification.create
    data:
      title: Homelab — a desligar
      message: A iniciar desligamento seguro (HA → Docker → Proxmox)…
      notification_id: homelab_safe_shutdown
  - action: script.enviar_notificacao_telegram
    continue_on_error: true
    data:
      destinatarios: antonio
      titulo: "⏻ Homelab"
      mensagem: A desligar com segurança — Home Assistant, Docker e Proxmox.
      parse_mode: html
  - action: shell_command.docker_ops_shutdown
    continue_on_error: true
    response_variable: shutdown_ops
  - if:
    - condition: template
      value_template: "{{ shutdown_ops is not defined or shutdown_ops['returncode'] | default(1) | int != 0 }}"
    then:
    - action: persistent_notification.create
      data:
        title: Homelab — falhou a iniciar desligamento
        message: O host Docker não aceitou o pedido de desligamento seguro.
        notification_id: homelab_safe_shutdown
    - action: script.enviar_notificacao_telegram
      continue_on_error: true
      data:
        destinatarios: antonio
        titulo: "⏻ Homelab: problema"
        mensagem: Não consegui iniciar o desligamento seguro.
        parse_mode: html
    - stop: shutdown recusado
  - action: persistent_notification.create
    data:
      title: Homelab — desligamento aceite
      message: Sequência aceite. Este Home Assistant vai desligar em breve.
      notification_id: homelab_safe_shutdown
"""

AUTOMATION_YAML = """
- id: homelab_safe_shutdown_result_20260912
  alias: Homelab — resultado desligamento seguro
  description: Webhook do listener Docker quando o shutdown é aceite ou falha cedo.
  mode: single
  trigger:
  - platform: webhook
    webhook_id: homelab_safe_shutdown_result
    allowed_methods:
    - POST
    local_only: true
  action:
  - action: persistent_notification.create
    data:
      title: Homelab — desligamento
      message: "{{ trigger.json.message | default('sem detalhe') }}"
      notification_id: homelab_safe_shutdown
  - action: script.enviar_notificacao_telegram
    continue_on_error: true
    data:
      destinatarios: antonio
      titulo: "⏻ Homelab"
      mensagem: "{{ trigger.json.message | default('sem detalhe') }}"
      parse_mode: html
"""


if __name__ == "__main__":
    raise SystemExit(main())
