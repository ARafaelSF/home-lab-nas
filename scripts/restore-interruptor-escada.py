#!/usr/bin/env python3
"""Restore Corredor - Interruptor Escada após re-parear Zigbee2MQTT.

Usa HA MCP (preferencial) ou WebSocket API com HASS_TOKEN.
Referência: /root/homelab/homeassistant/restore-interruptor-escada.md
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from typing import Any
from urllib.parse import urlparse

MCP_URLS = [
    os.environ.get("HA_MCP_URL", ""),
    "http://192.168.3.10:9583/private_cbP3OVdrkSd57EOXSZERlw",
    "https://mcphomeassistant.antonio.rafael.nom.br/private_cbP3OVdrkSd57EOXSZERlw",
]
HA_URL = os.environ.get("HASS_URL", os.environ.get("HA_URL", "http://192.168.3.10:8123"))
TOKEN = os.environ.get("HASS_TOKEN", os.environ.get("HA_TOKEN", ""))
TOKEN_FILE = os.environ.get("HA_TOKEN_FILE", "/root/.ha-token")

CHANNELS = [
    {
        "name": "Balizador",
        "switch_new": "switch.corredor_interruptor_escada_z2m_l1_balizador",
        "light_new": "light.corredor_interruptor_escada_z2m_l1_balizador",
        "light_area": "corredor",
        "light_icon": "mdi:floor-lamp-torchiere-variant-outline",
        "switch_candidates": [
            "switch.corredor_interruptor_escada_l1",
            "switch.corredor_-_interruptor_escada_l1",
        ],
    },
    {
        "name": "Trilho Corredor",
        "switch_new": "switch.corredor_interruptor_escada_z2m_l2_trilho_corredor",
        "light_new": "light.corredor_interruptor_escada_z2m_l2_trilho_corredor",
        "light_area": "corredor",
        "light_icon": "hue:ceiling-buratto-four",
        "switch_candidates": [
            "switch.corredor_interruptor_escada_l2",
            "switch.corredor_-_interruptor_escada_l2",
        ],
    },
    {
        "name": "Jardim Japonês",
        "switch_new": "switch.corredor_interruptor_escada_z2m_l3_jardim_japones",
        "light_new": "light.corredor_interruptor_escada_z2m_l3_jardim_japones",
        "light_area": "corredor",
        "light_icon": "phu:floor-lantern",
        "switch_candidates": [
            "switch.corredor_interruptor_escada_l3",
            "switch.corredor_-_interruptor_escada_l3",
        ],
    },
    {
        "name": "Pé Direito",
        "switch_new": "switch.corredor_interruptor_escada_z2m_l4_pe_direito",
        "light_new": "light.sala_de_jantar_interruptor_escada_z2m_l4_pe_direito",
        "light_area": "sala_de_jantar",
        "light_icon": "mdi:lightbulb-fluorescent-tube-outline",
        "switch_candidates": [
            "switch.corredor_interruptor_escada_l4",
            "switch.corredor_-_interruptor_escada_l4",
        ],
    },
]


def load_token() -> str:
    if TOKEN:
        return TOKEN.strip()
    if os.path.isfile(TOKEN_FILE):
        return open(TOKEN_FILE, encoding="utf-8").read().strip()
    return ""


def mcp_call(url: str, tool: str, arguments: dict[str, Any]) -> Any:
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {"name": tool, "arguments": arguments},
    }
    out = subprocess.check_output(
        [
            "curl",
            "-sS",
            "-m",
            "180",
            "-X",
            "POST",
            "-H",
            "Content-Type: application/json",
            "-H",
            "Accept: application/json, text/event-stream",
            "-d",
            json.dumps(payload),
            url,
        ],
        text=True,
    )
    for line in out.splitlines():
        if line.startswith("data: "):
            body = json.loads(line[6:])
            if body.get("error"):
                raise RuntimeError(body["error"])
            text = body["result"]["content"][0]["text"]
            try:
                return json.loads(text)
            except json.JSONDecodeError:
                return text
    raise RuntimeError(out[:800])


class MCPClient:
    def __init__(self, url: str):
        self.url = url

    def call(self, tool: str, arguments: dict[str, Any]) -> Any:
        return mcp_call(self.url, tool, arguments)

    def set_entity(self, **kwargs: Any) -> Any:
        return self.call("ha_set_entity", kwargs)

    def set_helper(self, **kwargs: Any) -> Any:
        return self.call("ha_config_set_helper", kwargs)

    def set_device(self, **kwargs: Any) -> Any:
        return self.call("ha_set_device", kwargs)

    def get_state(self, entity_id: str | list[str]) -> Any:
        return self.call("ha_get_state", {"entity_id": entity_id})

    def search(self, query: str, limit: int = 20) -> Any:
        return self.call("ha_search", {"query": query, "limit": limit})


class WSClient:
    def __init__(self, ha_url: str, token: str):
        import websocket  # type: ignore

        self.ws = websocket
        parsed = urlparse(ha_url)
        scheme = "wss" if parsed.scheme == "https" else "ws"
        self.url = f"{scheme}://{parsed.netloc}/api/websocket"
        self.token = token
        self.conn = None
        self.msg_id = 0

    def connect(self) -> None:
        self.conn = self.ws.create_connection(self.url, timeout=30)
        hello = json.loads(self.conn.recv())
        assert hello.get("type") == "auth_required", hello
        self.conn.send(json.dumps({"type": "auth", "access_token": self.token}))
        auth = json.loads(self.conn.recv())
        if auth.get("type") != "auth_ok":
            raise RuntimeError(f"Auth failed: {auth}")

    def send(self, payload: dict[str, Any]) -> dict[str, Any]:
        assert self.conn
        self.msg_id += 1
        msg = {**payload, "id": self.msg_id}
        self.conn.send(json.dumps(msg))
        while True:
            raw = self.conn.recv()
            data = json.loads(raw)
            if data.get("id") == self.msg_id:
                return data

    def entity_exists(self, entity_id: str) -> bool:
        r = self.send({"type": "config/entity_registry/get", "entity_id": entity_id})
        return bool(r.get("success"))

    def set_entity(self, entity_id: str, **kwargs: Any) -> dict[str, Any]:
        body = {"type": "config/entity_registry/update", "entity_id": entity_id, **kwargs}
        return self.send(body)

    def close(self) -> None:
        if self.conn:
            self.conn.close()


def pick_mcp_url() -> str:
    for url in MCP_URLS:
        if not url:
            continue
        try:
            subprocess.check_output(
                ["curl", "-sS", "-m", "5", "-o", "/dev/null", "-w", "%{http_code}", url],
                text=True,
            ).strip()
            # POST initialize probe
            payload = json.dumps(
                {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {},
                        "clientInfo": {"name": "restore", "version": "1.0"},
                    },
                }
            )
            out = subprocess.check_output(
                [
                    "curl",
                    "-sS",
                    "-m",
                    "10",
                    "-X",
                    "POST",
                    "-H",
                    "Content-Type: application/json",
                    "-H",
                    "Accept: application/json, text/event-stream",
                    "-d",
                    payload,
                    url,
                ],
                text=True,
            )
            if "error code: 502" in out or "Connection refused" in out:
                continue
            if "serverInfo" in out or out.startswith("data:"):
                print(f"MCP OK: {url}")
                return url
        except Exception:
            continue
    return ""


def resolve_switch(client: MCPClient | WSClient, candidates: list[str], target: str) -> str:
    if isinstance(client, MCPClient):
        for eid in candidates + [target]:
            try:
                r = client.call("ha_get_entity", {"entity_id": eid})
                if r and not r.get("error"):
                    return eid
            except Exception:
                pass
        raise RuntimeError(f"Nenhum switch encontrado entre: {candidates}")

    for eid in candidates + [target]:
        if client.entity_exists(eid):
            return eid
    raise RuntimeError(f"Nenhum switch encontrado entre: {candidates}")


def get_bps_key(client: MCPClient) -> str:
    guide = client.call(
        "ha_get_skill_guide",
        {"skill": "home-assistant-best-practices", "file": "SKILL.md"},
    )
    if isinstance(guide, dict):
        content = guide.get("content", "")
        import re

        m = re.search(r"Acknowledgment key: (I-HAVE-READ-THE-BEST-PRACTICES-GUIDE-[a-f0-9]+)", content)
        if m:
            return m.group(1)
    raise RuntimeError("Não foi possível obter BestPracticeKey do ha-mcp")


def restore_via_mcp(client: MCPClient) -> None:
    bps = get_bps_key(client)
    print("\n==> Renomear switches")
    renamed: list[tuple[str, dict[str, Any]]] = []
    for ch in CHANNELS:
        old = resolve_switch(client, ch["switch_candidates"], ch["switch_new"])
        print(f"  {old} -> {ch['switch_new']} ({ch['name']})")
        client.set_entity(
            entity_id=old,
            new_entity_id=ch["switch_new"],
            name=ch["name"],
            hidden=False,
        )
        renamed.append((ch["switch_new"], ch))

    print("\n==> Criar helpers switch_as_x")
    for switch_id, ch in renamed:
        print(f"  {switch_id} -> light")
        client.set_helper(
            helper_type="switch_as_x",
            name=ch["name"],
            config={"entity_id": switch_id, "target_domain": "light"},
            BestPracticeKey=bps,
            MandatoryBPS=False,
        )

    print("\n==> Renomear luzes switch_as_x")
    for switch_id, ch in renamed:
        # HA gera nomes variados; procurar candidatos
        suffix = switch_id.split(".", 1)[1].replace("switch.", "")
        light_candidates = [
            ch["light_new"],
            f"light.corredor_corredor_interruptor_escada_{switch_id.rsplit('_', 1)[-1].replace('balizador','l1').replace('trilho_corredor','l2').replace('jardim_japones','l3').replace('pe_direito','l4')}",
        ]
        if "l1" in switch_id or "balizador" in switch_id:
            light_candidates.append("light.corredor_corredor_interruptor_escada_l1")
        elif "l2" in switch_id or "trilho" in switch_id:
            light_candidates.append("light.corredor_corredor_interruptor_escada_l2")
        elif "l3" in switch_id or "jardim" in switch_id:
            light_candidates.append("light.corredor_corredor_interruptor_escada_l3")
        elif "l4" in switch_id or "pe_direito" in switch_id:
            light_candidates.append("light.corredor_corredor_interruptor_escada_l4")

        found = resolve_switch(client, light_candidates, ch["light_new"])
        kwargs: dict[str, Any] = {
            "entity_id": found,
            "new_entity_id": ch["light_new"],
            "name": ch["name"],
        }
        if ch.get("light_icon"):
            kwargs["icon"] = ch["light_icon"]
        if ch.get("light_area"):
            kwargs["area_id"] = ch["light_area"]
        print(f"  {found} -> {ch['light_new']}")
        client.set_entity(**kwargs)

    print("\n==> Dispositivo e áreas")
    search = client.search("Corredor - Interruptor Escada", limit=5)
    devices = search.get("devices") or []
    if devices:
        dev_id = devices[0].get("id") or devices[0].get("device_id")
        if dev_id:
            client.set_device(device_id=dev_id, name="Corredor - Interruptor Escada", area_id="corredor")
            print(f"  device {dev_id} -> Corredor - Interruptor Escada / corredor")

    for ch in CHANNELS:
        if ch["light_area"] == "corredor":
            client.set_entity(entity_id=ch["light_new"], area_id="corredor")

    print("\n==> Verificação")
    states = client.get_state(
        [
            ch["light_new"] for ch in CHANNELS
        ]
        + [
            "switch.cozinha_interruptor_corredor_z2m_l3_balizador_virtual",
            "switch.corredor_interruptor_corredor_z2m_l4_trilho_corredor_virtual",
        ]
    )
    print(json.dumps(states, indent=2, ensure_ascii=False)[:2000])


def restore_via_ws(client: WSClient) -> None:
    raise SystemExit(
        "WebSocket direto ainda não implementa switch_as_x (precisa config flow). "
        "Inicie o add-on HA MCP (porta 9583) ou use este script com MCP disponível."
    )


def main() -> int:
    print("Restore: Corredor - Interruptor Escada")
    mcp_url = pick_mcp_url()
    if mcp_url:
        restore_via_mcp(MCPClient(mcp_url))
        print("\nRestore concluído via MCP.")
        return 0

    token = load_token()
    if token:
        ws = WSClient(HA_URL, token)
        ws.connect()
        try:
            restore_via_ws(ws)
        finally:
            ws.close()
        return 0

    print(
        "\nERRO: Sem acesso ao Home Assistant.\n"
        "- Add-on HA MCP: porta 9583 fechada em 192.168.3.10\n"
        "- MCP público (mcphomeassistant): 502\n"
        "- HASS_TOKEN não definido\n\n"
        "Solução:\n"
        "  1. No HA: Configurações → Add-ons → HA MCP → Iniciar (e expor porta 9583)\n"
        "  2. Ou: echo 'SEU_TOKEN' > /root/.ha-token && chmod 600 /root/.ha-token\n"
        "  3. Executar: python3 /root/homelab/scripts/restore-interruptor-escada.py",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
