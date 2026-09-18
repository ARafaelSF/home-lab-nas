#!/usr/bin/env python3
"""Append calibração rows to CSV. Payload JSON via argv[1] or stdin."""
from __future__ import annotations

import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

OUT_DIR = Path("/share/calibracao")
OUT_CSV = OUT_DIR / "termo_higro_amostras.csv"
LOG = Path("/config/www/calib_termo_guardar.log")

HEADERS = [
    "timestamp_iso",
    "device_id",
    "device_name",
    "referencia_temp_c",
    "referencia_rh_pct",
    "entity_temp",
    "temp_c",
    "delta_temp",
    "entity_rh",
    "rh_pct",
    "delta_rh",
]


def log(msg: str) -> None:
    line = f"{datetime.now().isoformat(timespec='seconds')} {msg}\n"
    try:
        prev = LOG.read_text(encoding="utf-8") if LOG.exists() else ""
        LOG.write_text(prev + line, encoding="utf-8")
    except OSError:
        print(line, end="", file=sys.stderr)


def num(v):
    if v is None:
        return None
    s = str(v).strip()
    if s in ("", "unknown", "unavailable", "none", "None"):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def main() -> int:
    raw = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        log(f"JSON inválido: {exc}")
        print("ERRO: payload JSON inválido")
        return 2

    ref_temp = num(payload.get("ref_temp"))
    ref_rh = num(payload.get("ref_rh"))
    devices = payload.get("devices") or []
    if ref_temp is None:
        print("ERRO: referência de temperatura em falta")
        return 2

    ts = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    rows = []
    for d in devices:
        temp_v = num(d.get("temp"))
        rh_v = num(d.get("rh"))
        delta_t = (temp_v - ref_temp) if temp_v is not None else None
        delta_rh = (rh_v - ref_rh) if (rh_v is not None and ref_rh is not None) else None
        rows.append(
            {
                "timestamp_iso": ts,
                "device_id": d.get("id", ""),
                "device_name": d.get("name", ""),
                "referencia_temp_c": f"{ref_temp:.1f}",
                "referencia_rh_pct": f"{ref_rh:.0f}" if ref_rh is not None else "",
                "entity_temp": d.get("entity_temp", ""),
                "temp_c": f"{temp_v:.2f}" if temp_v is not None else "",
                "delta_temp": f"{delta_t:.2f}" if delta_t is not None else "",
                "entity_rh": d.get("entity_rh", ""),
                "rh_pct": f"{rh_v:.1f}" if rh_v is not None else "",
                "delta_rh": f"{delta_rh:.1f}" if delta_rh is not None else "",
            }
        )

    if not rows:
        print("ERRO: nenhum dispositivo Em uso")
        return 3

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    new_file = not OUT_CSV.exists()
    with OUT_CSV.open("a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=HEADERS)
        if new_file:
            w.writeheader()
        w.writerows(rows)

    msg = f"OK {len(rows)} linhas → {OUT_CSV}"
    log(msg)
    print(msg)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        log(f"FAIL {exc}")
        print(f"ERRO: {exc}")
        raise SystemExit(1) from exc
