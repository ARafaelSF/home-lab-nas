#!/usr/bin/env python3
"""Publica métricas do Glances no MQTT do Home Assistant (discovery + estado)."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request

import paho.mqtt.client as mqtt

GLANCES_URL = os.environ.get("GLANCES_URL", "http://glances:61208").rstrip("/")
MQTT_HOST = os.environ.get("MQTT_HOST", "192.168.3.10")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("MQTT_USER", "homeassistant")
MQTT_PASSWORD = os.environ.get("MQTT_PASSWORD", "")
INTERVAL = int(os.environ.get("POLL_INTERVAL", "60"))
DEVICE_ID = "escritorio_homelab_nas"
PREFIX = "homeassistant"


def glances_get(path: str) -> dict | list | str:
    url = f"{GLANCES_URL}/api/4{path}"
    with urllib.request.urlopen(url, timeout=15) as resp:
        return json.loads(resp.read().decode())


def gib(bytes_val: float) -> float:
    return round(bytes_val / (1024**3), 2)


def root_fs(fs_list: list) -> dict | None:
    for entry in fs_list:
        if entry.get("mnt_point") in ("/rootfs", "/"):
            return entry
    return fs_list[0] if fs_list else None


def build_sensors() -> list[dict]:
    cpu = glances_get("/quicklook")
    mem = glances_get("/mem")
    fs = root_fs(glances_get("/fs"))
    uptime = glances_get("/uptime")

    sensors: list[dict] = [
        {
            "object_id": f"{DEVICE_ID}_cpu",
            "name": "CPU",
            "state": round(float(cpu.get("cpu", 0)), 1),
            "unit": "%",
            "icon": "mdi:cpu-64-bit",
            "state_class": "measurement",
        },
        {
            "object_id": f"{DEVICE_ID}_memoria",
            "name": "Memória",
            "state": round(float(mem.get("percent", 0)), 1),
            "unit": "%",
            "icon": "mdi:memory",
            "state_class": "measurement",
        },
        {
            "object_id": f"{DEVICE_ID}_memoria_usada_gib",
            "name": "Memória usada",
            "state": gib(float(mem.get("used", 0))),
            "unit": "GiB",
            "icon": "mdi:memory",
            "state_class": "measurement",
        },
        {
            "object_id": f"{DEVICE_ID}_memoria_livre_gib",
            "name": "Memória livre",
            "state": gib(float(mem.get("available", 0))),
            "unit": "GiB",
            "icon": "mdi:memory",
            "state_class": "measurement",
        },
    ]

    if fs:
        sensors.extend(
            [
                {
                    "object_id": f"{DEVICE_ID}_disco",
                    "name": "Disco",
                    "state": round(float(fs.get("percent", 0)), 1),
                    "unit": "%",
                    "icon": "mdi:harddisk",
                    "state_class": "measurement",
                },
                {
                    "object_id": f"{DEVICE_ID}_disco_usado_gib",
                    "name": "Disco usado",
                    "state": gib(float(fs.get("used", 0))),
                    "unit": "GiB",
                    "icon": "mdi:harddisk",
                    "state_class": "measurement",
                },
                {
                    "object_id": f"{DEVICE_ID}_disco_livre_gib",
                    "name": "Disco livre",
                    "state": gib(float(fs.get("free", 0))),
                    "unit": "GiB",
                    "icon": "mdi:harddisk",
                    "state_class": "measurement",
                },
            ]
        )

    sensors.append(
        {
            "object_id": f"{DEVICE_ID}_uptime",
            "name": "Uptime",
            "state": str(uptime).strip('"'),
            "unit": None,
            "icon": "mdi:clock-outline",
            "state_class": None,
        }
    )
    return sensors


def device_payload() -> dict:
    return {
        "identifiers": [DEVICE_ID],
        "name": "Homelab NAS",
        "manufacturer": "Homelab",
        "model": "VM Docker (Proxmox)",
        "sw_version": "Glances",
    }


def discovery_payload(sensor: dict) -> dict:
    payload: dict = {
        "name": sensor["name"],
        "unique_id": sensor["object_id"],
        "state_topic": f"homelab/{DEVICE_ID}/{sensor['object_id']}/state",
        "icon": sensor["icon"],
        "device": device_payload(),
    }
    if sensor.get("unit"):
        payload["unit_of_measurement"] = sensor["unit"]
    if sensor.get("state_class"):
        payload["state_class"] = sensor["state_class"]
    return payload


def main() -> int:
    if not MQTT_PASSWORD:
        print("MQTT_PASSWORD não definido", file=sys.stderr)
        return 1

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.username_pw_set(MQTT_USER, MQTT_PASSWORD)
    client.connect(MQTT_HOST, MQTT_PORT, 60)
    client.loop_start()

    # Aguardar Glances
    for _ in range(30):
        try:
            glances_get("/status")
            break
        except (urllib.error.URLError, TimeoutError):
            time.sleep(2)
    else:
        print("Glances indisponível", file=sys.stderr)
        return 1

    sensors = build_sensors()
    for sensor in sensors:
        topic = f"{PREFIX}/sensor/{sensor['object_id']}/config"
        client.publish(topic, json.dumps(discovery_payload(sensor)), retain=True)
    print(f"Discovery: {len(sensors)} sensores ({DEVICE_ID})", flush=True)

    while True:
        try:
            for sensor in build_sensors():
                client.publish(
                    f"homelab/{DEVICE_ID}/{sensor['object_id']}/state",
                    str(sensor["state"]),
                    retain=True,
                )
        except Exception as exc:  # noqa: BLE001
            print(f"Erro no ciclo: {exc}", file=sys.stderr)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    raise SystemExit(main())
