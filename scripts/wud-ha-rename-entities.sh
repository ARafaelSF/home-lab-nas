#!/usr/bin/env bash
# Renomeia entidades WUD no Home Assistant para o padrão curto:
#   nome: "Hermes Agent"  |  entity_id: update.sistema_docker_hermes
#
# Uso:
#   HASS_TOKEN=eyJ... /root/homelab/scripts/wud-ha-rename-entities.sh

set -euo pipefail

HA_URL="${HA_URL:-http://192.168.3.10:8123}"
MAP="${WUD_RENAME_MAP:-/root/homelab/homeassistant/wud-ha-rename-map.json}"
TOKEN="${HASS_TOKEN:-${HA_TOKEN:-}}"

if [[ -z "$TOKEN" ]]; then
  echo "ERRO: defina HASS_TOKEN (Perfil HA → Tokens de acesso de longa duração)."
  exit 1
fi
[[ -f "$MAP" ]] || { echo "ERRO: mapa não encontrado: $MAP"; exit 1; }

python3 - "$HA_URL" "$TOKEN" "$MAP" <<'PY'
import json, sys, uuid
from urllib.parse import urlparse

try:
    import websocket
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "websocket-client"])
    import websocket

ha_url, token, map_path = sys.argv[1:4]
data = json.load(open(map_path))
parsed = urlparse(ha_url)
ws_scheme = "wss" if parsed.scheme == "https" else "ws"
ws_url = f"{ws_scheme}://{parsed.netloc}/api/websocket"

ws = websocket.create_connection(ws_url, timeout=30)
msg_id = 0

def recv_until(typ=None, mid=None):
    while True:
        raw = ws.recv()
        msg = json.loads(raw)
        if typ and msg.get("type") != typ:
            continue
        if mid is not None and msg.get("id") != mid:
            continue
        return msg

def send(payload):
    global msg_id
    msg_id += 1
    payload = {**payload, "id": msg_id}
    ws.send(json.dumps(payload))
    return recv_until(mid=msg_id)

# auth
hello = json.loads(ws.recv())
assert hello.get("type") == "auth_required", hello
ws.send(json.dumps({"type": "auth", "access_token": token}))
auth = json.loads(ws.recv())
if auth.get("type") != "auth_ok":
    print("ERRO auth:", auth)
    sys.exit(1)

area = data.get("area_id", "sistema")
ok = fail = 0

for e in data.get("entities", []) + data.get("aggregates", []):
    old_id, name, new_id = e["old"], e["name"], e["new"]
    # Tentar old; se falhar, já pode estar no new
    for eid in (old_id, new_id):
        body = {
            "type": "config/entity_registry/update",
            "entity_id": eid,
            "name": name,
            "area_id": area,
        }
        if eid == old_id and new_id != old_id:
            body["new_entity_id"] = new_id
        resp = send(body)
        if resp.get("success"):
            print(f"OK  {eid} → {new_id} ({name})")
            ok += 1
            break
    else:
        print(f"FALHA {old_id}: {resp.get('error')}")
        fail += 1

ws.close()
print(f"\nConcluído: {ok} ok, {fail} falhas")
sys.exit(0 if fail == 0 else 1)
PY
