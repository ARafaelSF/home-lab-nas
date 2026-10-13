#!/usr/bin/env python3
"""Passive, read-only health monitor for SMLIGHT SLZB-06.

It polls the controller's read-only HTTP status/log endpoints and subscribes
to diagnostic Zigbee2MQTT MQTT topics.  It never opens the Zigbee TCP port,
publishes MQTT messages, or sends commands to the controller.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import threading
import time
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:  # pragma: no cover - deployment dependency check
    requests = None

SLZB_URL = os.getenv("SLZB_STATUS_URL", "http://192.168.2.237/api2?action=0&page=0")
SLZB_LOG_URL = os.getenv("SLZB_LOG_URL", "http://192.168.2.237/api2?action=5")
MQTT_HOST = os.getenv("MQTT_HOST", "192.168.3.10")
MQTT_PORT = os.getenv("MQTT_PORT", "1883")
MQTT_USER = os.getenv("MQTT_USER", "homeassistant")
LOG_DIR = Path(os.getenv("SLZB_MONITOR_STATE", "/var/lib/slzb-monitor"))
LOG_FILE = LOG_DIR / "events.jsonl"
POLL_SECONDS = int(os.getenv("SLZB_POLL_SECONDS", "60"))
MAX_BYTES = 100 * 1024 * 1024
MAX_AGE = dt.timedelta(days=14)
TOPICS = (
    "zigbee2mqtt/bridge/state",
    "zigbee2mqtt/bridge/health",
    "zigbee2mqtt/bridge/log",
    "zigbee2mqtt/bridge/logging",
)
TECHNICAL = re.compile(
    r"SRSP|NWK_|MAC_|APS_|Data request|Adapter disconnected|ECONNRESET|"
    r"timeout|failed to ping|disconnected|offline|reset|serial|socket|watchdog",
    re.I,
)


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _value(values: dict[str, str], *names: str) -> str | None:
    for name in names:
        if name in values:
            return values[name]
    return None


def parse_status_header(header: str) -> dict[str, Any]:
    """Parse SMLIGHT's respValuesArr header without retaining the full page."""
    try:
        decoded = json.loads(header)
    except (TypeError, json.JSONDecodeError):
        decoded = None
    if isinstance(decoded, dict):
        values = {str(key): str(value) for key, value in decoded.items()}
    else:
        values = {}
        for part in header.split(","):
            if "=" in part:
                key, value = part.split("=", 1)
                values[key.strip()] = value.strip().strip('"')
    result: dict[str, Any] = {
        "device": _value(values, "DEVICE"),
        "core_firmware": _value(values, "BUILD", "espRev"),
        "zigbee_firmware": _value(values, "zbRev"),
        "zigbee_hardware": _value(values, "zbHw"),
        "ip": _value(values, "ethIp"),
        "ethernet_connected": _value(values, "ethConn"),
        "zigbee_status": _value(values, "zbStatus"),
        "uptime": _value(values, "uptime"),
        "radio_uptime": _value(values, "zbConnT"),
        "crash_info": _value(values, "crash_info"),
    }
    for source, target in (("zbTemp", "zigbee_temp_c"), ("esp32Temp", "core_temp_c")):
        raw = _value(values, source)
        if raw is not None:
            try:
                result[target] = float(raw)
            except ValueError:
                result[target] = None
    return {key: value for key, value in result.items() if value is not None}


def summarize_health(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise ValueError("health payload is not an object")
    process = payload.get("process") if isinstance(payload.get("process"), dict) else {}
    mqtt = payload.get("mqtt") if isinstance(payload.get("mqtt"), dict) else {}
    os_info = payload.get("os") if isinstance(payload.get("os"), dict) else {}
    devices = payload.get("devices") if isinstance(payload.get("devices"), dict) else {}
    messages = []
    for item in devices.values():
        if isinstance(item, dict) and isinstance(item.get("messages"), int):
            messages.append(item["messages"])
    return {
        "process_uptime_sec": process.get("uptime_sec"),
        "mqtt_connected": mqtt.get("connected"),
        "mqtt_received": mqtt.get("received"),
        "mqtt_published": mqtt.get("published"),
        "load": os_info.get("load_average"),
        "device_count": len(devices),
        "device_messages_total": sum(messages),
    }


def technical_log(topic: str, payload: Any) -> dict[str, Any] | None:
    if isinstance(payload, dict):
        level = str(payload.get("level", "")).lower()
        message = str(payload.get("message", ""))
        namespace = payload.get("namespace")
    else:
        level, message, namespace = "", str(payload), None
    if level not in {"warn", "warning", "error", "fatal"} and not TECHNICAL.search(message):
        return None
    return {"topic": topic, "level": level, "namespace": namespace, "message": message[:800]}


def mqtt_command(password: str) -> list[str]:
    return [
        "mosquitto_sub", "-h", MQTT_HOST, "-p", str(MQTT_PORT), "-u", MQTT_USER,
        "-P", password, "-v", "-F", "%t\\t%p", *sum((["-t", topic] for topic in TOPICS), []),
    ]


class EventLog:
    def __init__(self, path: Path = LOG_FILE) -> None:
        self.path = path
        self.lock = threading.Lock()
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, event: dict[str, Any]) -> None:
        event = {"ts_utc": now(), **event}
        line = json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n"
        with self.lock:
            with self.path.open("a", encoding="utf-8") as stream:
                stream.write(line)
            self.prune()

    def prune(self) -> None:
        cutoff = time.time() - MAX_AGE.total_seconds()
        files = [p for p in self.path.parent.glob("events.jsonl*") if p.is_file()]
        for item in files:
            if item != self.path and item.stat().st_mtime < cutoff:
                item.unlink(missing_ok=True)
        total = sum(item.stat().st_size for item in files if item.exists())
        if total > MAX_BYTES:
            for item in sorted((p for p in files if p != self.path), key=lambda p: p.stat().st_mtime):
                item.unlink(missing_ok=True)
                total -= item.stat().st_size if item.exists() else 0
                if total <= MAX_BYTES:
                    break


def poll_slzb(log: EventLog, previous_lines: set[str]) -> set[str]:
    if requests is None:
        log.write({"kind": "http_error", "error": "python requests is unavailable"})
        return previous_lines
    try:
        response = requests.get(SLZB_URL, timeout=8)
        response.raise_for_status()
        header = response.headers.get("respValuesArr", "")
        log.write({"source": "slzb", "kind": "status", "data": parse_status_header(header)})
    except Exception as exc:  # read-only monitor must survive transient failures
        log.write({"source": "slzb", "kind": "http_error", "endpoint": "status", "error": type(exc).__name__})
    time.sleep(1)
    try:
        response = requests.get(SLZB_LOG_URL, timeout=8)
        response.raise_for_status()
        lines = set(response.text.splitlines())
        new_lines = lines - previous_lines
        for line in sorted(new_lines):
            if TECHNICAL.search(line):
                log.write({"source": "slzb", "kind": "internal_log", "line": line[:800], "line_sha256": hashlib.sha256(line.encode()).hexdigest()})
        return lines
    except Exception as exc:
        log.write({"source": "slzb", "kind": "http_error", "endpoint": "internal_log", "error": type(exc).__name__})
        return previous_lines


def mqtt_loop(log: EventLog) -> None:
    password = os.getenv("WUD_MQTT_PASSWORD")
    if not password:
        log.write({"source": "mqtt", "kind": "config_missing"})
        return
    while True:
        process = None
        try:
            process = subprocess.Popen(mqtt_command(password), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            log.write({"source": "mqtt", "kind": "subscriber_started", "topics": list(TOPICS)})
            assert process.stdout is not None
            for raw in process.stdout:
                raw = raw.rstrip("\r\n")
                if "\t" not in raw:
                    continue
                topic, payload = raw.split("\t", 1)
                try:
                    decoded = json.loads(payload)
                except json.JSONDecodeError:
                    decoded = payload
                if topic.endswith("/state"):
                    log.write({"source": "mqtt", "kind": "bridge_state", "state": decoded if isinstance(decoded, str) else str(decoded)[:40]})
                elif topic.endswith("/health"):
                    try:
                        log.write({"source": "mqtt", "kind": "bridge_health", "data": summarize_health(decoded)})
                    except ValueError:
                        log.write({"source": "mqtt", "kind": "health_invalid"})
                else:
                    event = technical_log(topic, decoded)
                    if event:
                        log.write({"source": "mqtt", "kind": "technical_log", **event})
        except Exception as exc:
            log.write({"source": "mqtt", "kind": "subscriber_error", "error": type(exc).__name__})
        finally:
            if process is not None:
                process.kill()
                process.wait()
            log.write({"source": "mqtt", "kind": "subscriber_exit"})
        time.sleep(5)


def main() -> None:
    log = EventLog()
    log.write({"kind": "monitor_started", "poll_seconds": POLL_SECONDS, "topics": list(TOPICS)})
    threading.Thread(target=mqtt_loop, args=(log,), daemon=True).start()
    lines: set[str] = set()
    while True:
        started = time.monotonic()
        lines = poll_slzb(log, lines)
        time.sleep(max(1, POLL_SECONDS - (time.monotonic() - started)))


if __name__ == "__main__":
    main()
