#!/usr/bin/env python3
"""Ajusta a view Servidor e o helper de temperatura CPU."""
from __future__ import annotations

import json
import os
import sys
from typing import Any

import websocket

HA_URL = os.environ.get("HA_URL", "http://192.168.3.10:8123")
TOKEN = os.environ.get("HA_TOKEN", "")
URL_PATH = "dashboard-casa"

BACKUP_SECTION = {
    "type": "grid",
    "visibility": [
        {
            "condition": "state",
            "entity": "switch.escritorio_servidor_minipc_tasmota",
            "state": "on",
        }
    ],
    "cards": [
        {
            "type": "heading",
            "heading": "Mini backup (Tasmota)",
            "heading_style": "subtitle",
            "icon": "mdi:nas",
            "grid_options": {"columns": 12, "rows": 1},
        },
        {
            "square": False,
            "type": "grid",
            "columns": 2,
            "cards": [
                {
                    "type": "tile",
                    "entity": "switch.escritorio_servidor_minipc_tasmota",
                    "name": "Energia do mini backup",
                    "icon": "mdi:power-plug",
                    "color": "green",
                    "features_position": "bottom",
                },
                {
                    "type": "tile",
                    "entity": "sensor.escritorio_servidor_minipc_potencia_tasmota",
                    "name": "Consumo backup",
                    "icon": "mdi:flash",
                    "color": "amber",
                },
            ],
            "grid_options": {"columns": 12, "rows": 1},
        },
    ],
}

HELPER_STATE = """{% set cpu = states('sensor.sistema_temperatura_cpu_minipc') %}
{% if cpu in ['unknown', 'unavailable', 'none', 'None', ''] %}
  {{ none }}
{% else %}
  {{ cpu }}
{% endif %}"""


class WSClient:
    def __init__(self, ha_url: str, token: str):
        parsed = ha_url.replace("https://", "wss://").replace("http://", "ws://")
        self.url = parsed.rstrip("/") + "/api/websocket"
        self.token = token
        self.conn = None
        self.msg_id = 0

    def connect(self) -> None:
        self.conn = websocket.create_connection(self.url, timeout=60)
        hello = json.loads(self.conn.recv())
        if hello.get("type") != "auth_required":
            raise RuntimeError(hello)
        self.conn.send(json.dumps({"type": "auth", "access_token": self.token}))
        auth = json.loads(self.conn.recv())
        if auth.get("type") != "auth_ok":
            raise RuntimeError(auth)

    def send(self, payload: dict[str, Any]) -> dict[str, Any]:
        assert self.conn
        self.msg_id += 1
        self.conn.send(json.dumps({**payload, "id": self.msg_id}))
        while True:
            data = json.loads(self.conn.recv())
            if data.get("id") == self.msg_id:
                return data

    def close(self) -> None:
        if self.conn:
            self.conn.close()


def find_view(config: dict[str, Any]) -> dict[str, Any]:
    for view in config.get("views", []):
        if view.get("path") == "servidor":
            return view
    raise SystemExit("view servidor não encontrada")


def patch_server_section(section: dict[str, Any]) -> bool:
    cards = section.get("cards") or []
    if not cards or cards[0].get("heading") != "Servidor":
        return False

    new_cards = []
    for card in cards:
        if card.get("type") == "grid" and any(
            (c.get("entity") or "").endswith("_tasmota")
            or (c.get("entity") or "") == "switch.sistema_home_assistant_sonoff"
            for c in card.get("cards") or []
        ):
            new_cards.append(
                {
                    "square": False,
                    "type": "grid",
                    "columns": 2,
                    "cards": [
                        {
                            "type": "tile",
                            "entity": "switch.sistema_home_assistant_sonoff",
                            "name": "Energia do servidor",
                            "icon": "mdi:power-plug",
                            "color": "green",
                            "features_position": "bottom",
                        },
                        {
                            "type": "tile",
                            "entity": "sensor.sistema_home_assistant_potencia_sonoff",
                            "name": "Consumo agora",
                            "icon": "mdi:flash",
                            "color": "amber",
                        },
                    ],
                    "grid_options": {"columns": 12, "rows": 1},
                }
            )
            continue

        if card.get("type") == "button" and card.get("entity") in {
            "switch.escritorio_servidor_minipc_tasmota",
            "switch.sistema_home_assistant_sonoff",
        }:
            new_cards.append(
                {
                    "show_name": True,
                    "show_icon": True,
                    "type": "button",
                    "entity": "switch.sistema_home_assistant_sonoff",
                    "name": "Servidor HomeLab",
                    "icon": "mdi:home-assistant",
                    "grid_options": {"columns": 12, "rows": 2},
                }
            )
            continue

        if card.get("entity") == "switch.escritorio_estacao_trabalho_sonoff":
            continue

        if card.get("type") == "entities" and card.get("title") == "Resumo rápido":
            for row in card.get("entities") or []:
                if row.get("entity") == "sensor.sistema_temperatura_cpu":
                    row["name"] = "Temperatura CPU MiniPC"
            new_cards.append(card)
            continue

        new_cards.append(card)

    section["cards"] = new_cards
    return True


def patch_temp_section(section: dict[str, Any]) -> bool:
    cards = section.get("cards") or []
    if not cards or cards[0].get("heading") != "Servidor — temperatura":
        return False
    for card in cards:
        if card.get("type") == "grid":
            card["columns"] = 2
            for gauge in card.get("cards") or []:
                if gauge.get("entity") == "sensor.sistema_temperatura_cpu":
                    gauge["name"] = "Temperatura CPU MiniPC"
    return True


def ensure_backup_section(view: dict[str, Any]) -> None:
    sections = view.get("sections") or []
    already = any(
        (sec.get("cards") or [{}])[0].get("heading") == "Mini backup (Tasmota)"
        for sec in sections
    )
    if already:
        for sec in sections:
            cards = sec.get("cards") or []
            if cards and cards[0].get("heading") == "Mini backup (Tasmota)":
                sec["visibility"] = BACKUP_SECTION["visibility"]
        return
    insert_at = None
    for i, sec in enumerate(sections):
        cards = sec.get("cards") or []
        if cards and cards[0].get("heading") == "Servidor":
            insert_at = i + 1
            break
    if insert_at is None:
        raise SystemExit("secção Servidor não encontrada para inserir backup")
    sections.insert(insert_at, BACKUP_SECTION)
    view["sections"] = sections


def patch_graficos(config: dict[str, Any]) -> None:
    for view in config.get("views", []):
        if view.get("path") != "graficos_servidor":
            continue
        for sec in view.get("sections") or []:
            for card in sec.get("cards") or []:
                if card.get("type") != "history-graph":
                    continue
                for ent in card.get("entities") or []:
                    if ent.get("entity") == "sensor.sistema_temperatura_cpu":
                        ent["name"] = "CPU MiniPC"


def main() -> int:
    if not TOKEN:
        print("HA_TOKEN em falta", file=sys.stderr)
        return 1
    ws = WSClient(HA_URL, TOKEN)
    ws.connect()
    try:
        loaded = ws.send({"type": "lovelace/config", "url_path": URL_PATH})
        if not loaded.get("success"):
            print(loaded, file=sys.stderr)
            return 1
        config = loaded["result"]
        view = find_view(config)
        patched_server = patched_temp = False
        for sec in view.get("sections") or []:
            patched_server = patch_server_section(sec) or patched_server
            patched_temp = patch_temp_section(sec) or patched_temp
        if not patched_server:
            print("falhou a ajustar a secção Servidor", file=sys.stderr)
            return 1
        if not patched_temp:
            print("falhou a ajustar a secção de temperatura", file=sys.stderr)
            return 1
        ensure_backup_section(view)
        patch_graficos(config)
        saved = ws.send(
            {
                "type": "lovelace/config/save",
                "url_path": URL_PATH,
                "config": config,
            }
        )
        print("lovelace", json.dumps(saved.get("success"), ensure_ascii=False), saved.get("error"))

        helper = ws.send(
            {
                "type": "config_entries/update",
                "entry_id": "01KR3KVEYXSA3W1XTN1N3NPR3C",
                "title": "Temperatura CPU MiniPC",
                "options": {
                    "device_class": "temperature",
                    "name": "Temperatura CPU MiniPC",
                    "state": HELPER_STATE,
                    "state_class": "measurement",
                    "template_type": "sensor",
                    "unit_of_measurement": "°C",
                },
            }
        )
        print("helper", helper.get("success"), helper.get("error"))

        renamed = ws.send(
            {
                "type": "config/entity_registry/update",
                "entity_id": "sensor.sistema_temperatura_cpu",
                "name": "Temperatura CPU MiniPC",
            }
        )
        print("rename", renamed.get("success"), renamed.get("error"))
    finally:
        ws.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
