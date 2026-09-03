#!/usr/bin/env python3
"""Renomeia entidades SmartThings → _cloud e LocalThings → nomes _smartthings."""
from __future__ import annotations

import json
import sys
import time
import urllib.request

MCP_URL = "http://192.168.3.10:9583/private_cbP3OVdrkSd57EOXSZERlw"

ROOMS = ("suite", "escritorio", "sala_de_tv")

ST_SUFFIX_ENTITIES = [
    "climate.{p}_ar_condicionado_smartthings",
    "select.{p}_ar_condicionado_dust_filter_alarm_threshold_smartthings",
    "sensor.{p}_ar_condicionado_diferenca_de_energia_smartthings",
    "sensor.{p}_ar_condicionado_potencia_da_energia_smartthings",
    "sensor.{p}_ar_condicionado_energia_economizada_smartthings",
    "switch.{p}_ar_condicionado_display_lighting_smartthings",
    "sensor.{p}_ar_condicionado_temperatura_smartthings",
    "sensor.{p}_ar_condicionado_umidade_smartthings",
    "sensor.{p}_ar_condicionado_volume_smartthings",
    "sensor.{p}_ar_condicionado_potencia_smartthings",
    "switch.{p}_ar_condicionado_sound_effect_smartthings",
    "sensor.{p}_ar_condicionado_energia_smartthings",
]

LT_MAP = {
    "suite": {
        "suffix": "",
        "device_id": "8535a782f8e5671442e47d8eff25659a",
        "device_name": "Suíte - Ar condicionado",
        "area_id": "suite",
        "entities": {
            "climate.samsung_airconditioner_ara_ww_tp1_22_common": "climate.suite_ar_condicionado_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_temperature": "sensor.suite_ar_condicionado_temperatura_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_humidity": "sensor.suite_ar_condicionado_umidade_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_power": "sensor.suite_ar_condicionado_potencia_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_energy": "sensor.suite_ar_condicionado_energia_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_energy_saved": "sensor.suite_ar_condicionado_energia_economizada_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_display_light": "switch.suite_ar_condicionado_display_lighting_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_beep": "switch.suite_ar_condicionado_sound_effect_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_usage": "sensor.suite_ar_condicionado_filter_usage_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_usage_hours": "sensor.suite_ar_condicionado_filter_usage_hours_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_status": "sensor.suite_ar_condicionado_filter_status_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_progress": "sensor.suite_ar_condicionado_auto_clean_progress_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_alarm_code": "sensor.suite_ar_condicionado_alarm_code_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_outdoor_temperature": "sensor.suite_ar_condicionado_outdoor_temperature_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_odor_controller_progress": "sensor.suite_ar_condicionado_odor_controller_progress_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_connection_mode": "sensor.suite_ar_condicionado_connection_mode_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_running": "binary_sensor.suite_ar_condicionado_auto_clean_running_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_odor_controller_active": "binary_sensor.suite_ar_condicionado_odor_controller_active_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_firmware_update_available": "binary_sensor.suite_ar_condicionado_firmware_update_available_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean": "switch.suite_ar_condicionado_auto_clean_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_mute_once": "switch.suite_ar_condicionado_mute_once_smartthings",
            "number.samsung_airconditioner_ara_ww_tp1_22_common_tropical_night_mode": "number.suite_ar_condicionado_tropical_night_mode_smartthings",
        },
    },
    "escritorio": {
        "suffix": "_2",
        "device_id": "f58eabfc63c826b41a95769e4a7986d4",
        "device_name": "Escritório - Ar condicionado",
        "area_id": "escritorio",
        "entities": {
            "climate.samsung_airconditioner_ara_ww_tp1_22_common_2": "climate.escritorio_ar_condicionado_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_temperature_2": "sensor.escritorio_ar_condicionado_temperatura_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_humidity_2": "sensor.escritorio_ar_condicionado_umidade_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_power_2": "sensor.escritorio_ar_condicionado_potencia_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_energy_2": "sensor.escritorio_ar_condicionado_energia_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_energy_saved_2": "sensor.escritorio_ar_condicionado_energia_economizada_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_display_light_2": "switch.escritorio_ar_condicionado_display_lighting_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_beep_2": "switch.escritorio_ar_condicionado_sound_effect_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_usage_2": "sensor.escritorio_ar_condicionado_filter_usage_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_usage_hours_2": "sensor.escritorio_ar_condicionado_filter_usage_hours_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_status_2": "sensor.escritorio_ar_condicionado_filter_status_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_progress_2": "sensor.escritorio_ar_condicionado_auto_clean_progress_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_alarm_code_2": "sensor.escritorio_ar_condicionado_alarm_code_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_outdoor_temperature_2": "sensor.escritorio_ar_condicionado_outdoor_temperature_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_odor_controller_progress_2": "sensor.escritorio_ar_condicionado_odor_controller_progress_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_connection_mode_2": "sensor.escritorio_ar_condicionado_connection_mode_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_running_2": "binary_sensor.escritorio_ar_condicionado_auto_clean_running_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_odor_controller_active_2": "binary_sensor.escritorio_ar_condicionado_odor_controller_active_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_firmware_update_available_2": "binary_sensor.escritorio_ar_condicionado_firmware_update_available_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_2": "switch.escritorio_ar_condicionado_auto_clean_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_mute_once_2": "switch.escritorio_ar_condicionado_mute_once_smartthings",
            "number.samsung_airconditioner_ara_ww_tp1_22_common_tropical_night_mode_2": "number.escritorio_ar_condicionado_tropical_night_mode_smartthings",
        },
    },
    "sala_de_tv": {
        "suffix": "_3",
        "device_id": "a93f3966a635418652066d3622172b84",
        "device_name": "Sala de TV - Ar condicionado",
        "area_id": "sala_de_tv",
        "entities": {
            "climate.samsung_airconditioner_ara_ww_tp1_22_common_3": "climate.sala_de_tv_ar_condicionado_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_temperature_3": "sensor.sala_de_tv_ar_condicionado_temperatura_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_humidity_3": "sensor.sala_de_tv_ar_condicionado_umidade_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_power_3": "sensor.sala_de_tv_ar_condicionado_potencia_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_energy_3": "sensor.sala_de_tv_ar_condicionado_energia_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_display_light_3": "switch.sala_de_tv_ar_condicionado_display_lighting_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_beep_3": "switch.sala_de_tv_ar_condicionado_sound_effect_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_usage_3": "sensor.sala_de_tv_ar_condicionado_filter_usage_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_usage_hours_3": "sensor.sala_de_tv_ar_condicionado_filter_usage_hours_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_filter_status_3": "sensor.sala_de_tv_ar_condicionado_filter_status_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_progress_3": "sensor.sala_de_tv_ar_condicionado_auto_clean_progress_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_alarm_code_3": "sensor.sala_de_tv_ar_condicionado_alarm_code_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_outdoor_temperature_3": "sensor.sala_de_tv_ar_condicionado_outdoor_temperature_smartthings",
            "sensor.samsung_airconditioner_ara_ww_tp1_22_common_connection_mode_3": "sensor.sala_de_tv_ar_condicionado_connection_mode_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_running_3": "binary_sensor.sala_de_tv_ar_condicionado_auto_clean_running_smartthings",
            "binary_sensor.samsung_airconditioner_ara_ww_tp1_22_common_firmware_update_available_3": "binary_sensor.sala_de_tv_ar_condicionado_firmware_update_available_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_auto_clean_3": "switch.sala_de_tv_ar_condicionado_auto_clean_smartthings",
            "switch.samsung_airconditioner_ara_ww_tp1_22_common_mute_once_3": "switch.sala_de_tv_ar_condicionado_mute_once_smartthings",
            "number.samsung_airconditioner_ara_ww_tp1_22_common_tropical_night_mode_3": "number.sala_de_tv_ar_condicionado_tropical_night_mode_smartthings",
        },
    },
}

ST_DEVICES = {
    "suite": ("e26dd34dffafbc1553647b8d27914d23", "Suíte - Ar condicionado Cloud"),
    "escritorio": ("091508cc582e51050660017950a15482", "Escritório - Ar condicionado Cloud"),
    "sala_de_tv": ("5f039e502ea6def656d01613c1b3172d", "Sala de TV - Ar condicionado Cloud"),
}


def mcp_call(tool: str, arguments: dict, req_id: int = 1) -> dict:
    body = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": "tools/call",
        "params": {"name": tool, "arguments": arguments},
    }
    req = urllib.request.Request(
        MCP_URL,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Accept": "application/json, text/event-stream"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode()
    for line in raw.splitlines():
        if line.startswith("data: "):
            payload = json.loads(line[6:])
            break
    else:
        raise RuntimeError(f"Resposta MCP inválida: {raw[:500]}")
    content = payload.get("result", {}).get("content", [])
    if not content:
        return payload
    text = content[0].get("text", "{}")
    return json.loads(text)


def rename_entity(old: str, new: str, name: str | None = None) -> None:
    args = {"entity_id": old, "new_entity_id": new}
    if name is not None:
        args["name"] = name
    result = mcp_call("ha_set_entity", args)
    if not result.get("success", True) and result.get("error"):
        raise RuntimeError(f"{old} → {new}: {result['error']}")
    print(f"  OK {old} → {new}")


def main() -> int:
    req_id = 1

    print("=== Fase 1: SmartThings → _cloud ===")
    for room in ROOMS:
        print(f"\n[{room}]")
        for pattern in ST_SUFFIX_ENTITIES:
            old = pattern.format(p=room)
            new = old.replace("_smartthings", "_cloud")
            try:
                rename_entity(old, new)
            except Exception as exc:
                print(f"  SKIP {old}: {exc}")
            req_id += 1
            time.sleep(0.15)

    print("\n=== Fase 2: LocalThings → nomes SmartThings ===")
    for room, cfg in LT_MAP.items():
        print(f"\n[{room}]")
        for old, new in cfg["entities"].items():
            try:
                rename_entity(old, new)
            except Exception as exc:
                print(f"  FAIL {old}: {exc}")
            req_id += 1
            time.sleep(0.15)

    print("\n=== Fase 3: Dispositivos ===")
    for room, cfg in LT_MAP.items():
        result = mcp_call(
            "ha_set_device",
            {
                "device_id": cfg["device_id"],
                "name": cfg["device_name"],
                "area_id": cfg["area_id"],
            },
            req_id,
        )
        req_id += 1
        print(f"  LT {cfg['device_name']}: {result.get('success', result)}")

    for room, (device_id, name) in ST_DEVICES.items():
        result = mcp_call("ha_set_device", {"device_id": device_id, "name": name}, req_id)
        req_id += 1
        print(f"  ST {name}: {result.get('success', result)}")

    print("\nConcluído.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
