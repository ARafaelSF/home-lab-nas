#!/usr/bin/env python3
"""JSON da temperatura do MiniPC (host Proxmox). Só lê sysfs local."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json

BIND = "192.168.3.20"
PORT = 9108
PREFERRED = ("x86_pkg_temp", "coretemp", "k10temp", "acpitz")


def read_temps():
    zones = {}
    thermal = Path("/sys/class/thermal")
    for zone in sorted(thermal.glob("thermal_zone*")):
        try:
            typ = (zone / "type").read_text(encoding="utf-8").strip()
            raw = int((zone / "temp").read_text(encoding="utf-8").strip())
            if raw <= 0:
                continue
            zones[typ] = round(raw / 1000.0, 1)
        except (OSError, ValueError):
            continue
    cpu = next((zones[name] for name in PREFERRED if name in zones), None)
    if cpu is None and zones:
        cpu = next(iter(zones.values()))
    return {"cpu_c": cpu, "zones": zones}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/temp"):
            self.send_error(404)
            return
        body = json.dumps(read_temps()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return


if __name__ == "__main__":
    HTTPServer((BIND, PORT), Handler).serve_forever()
