#!/usr/bin/env python3
"""Importa dashboard comparativo Geladeira Midea no Grafana.
Executar no Terminal add-on (dentro do HA):
  python3 /config/packages/influxdb_energia/import_grafana_geladeira_comparativo.py
"""
import base64
import json
import pathlib
import urllib.request

BASE = "http://a0d7b954-grafana:3000"
AUTH = base64.b64encode(b"admin:hassio").decode()
PAYLOAD = pathlib.Path(__file__).with_name("grafana_geladeira_midea_comparativo.json").read_text(encoding="utf-8")

req = urllib.request.Request(
    f"{BASE}/api/dashboards/db",
    data=PAYLOAD.encode(),
    headers={"Authorization": f"Basic {AUTH}", "Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=30) as resp:
    out = json.load(resp)
print(json.dumps(out, indent=2))
print("Dashboard:", out.get("url", "?"))
