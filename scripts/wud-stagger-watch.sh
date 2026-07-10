#!/usr/bin/env bash
# Verifica updates WUD um container de cada vez (fila horária).
# Evita 429 no ghcr.io quando vários containers são consultados em batch.
set -euo pipefail

STATE_DIR="${WUD_STAGGER_STATE_DIR:-/var/lib/wud-stagger}"
STATE_FILE="${STATE_DIR}/last-check.json"
LOG_TAG="wud-stagger"

log() { logger -t "$LOG_TAG" "$*"; echo "[$(date '+%F %T')] $*"; }

mkdir -p "$STATE_DIR"
export TODAY="$(date '+%F')"
export STATE_FILE

if ! docker inspect wud >/dev/null 2>&1; then
  log "container wud não encontrado — ignorado"
  exit 0
fi

mapfile -t PICK < <(
  docker exec wud curl -sf http://127.0.0.1:3000/api/containers 2>/dev/null \
    | python3 -c "
import json, os, sys

today = os.environ['TODAY']
state_path = os.environ['STATE_FILE']
try:
    with open(state_path) as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    state = {}

rows = []
for c in json.load(sys.stdin):
    if c.get('watch') is False:
        continue
    cid = c['id']
    name = c['name']
    registry = (c.get('image') or {}).get('registry') or {}
    reg_name = registry.get('name', '')
    last = state.get(cid, '')
    rows.append((last == today, last, reg_name == 'ghcr.public', name, cid))

if not rows:
    sys.exit(0)

rows.sort(key=lambda r: (r[0], not r[2], r[1], r[3]))
if rows[0][0]:
    sys.exit(0)

print(rows[0][4])
print(rows[0][3])
" 
)

if [[ ${#PICK[@]} -lt 2 ]]; then
  log "todos os containers já verificados hoje — nada a fazer"
  exit 0
fi

CID="${PICK[0]}"
NAME="${PICK[1]}"

log "verificando: ${NAME} (${CID:0:8}…)"
if docker exec wud curl -sf -X POST "http://127.0.0.1:3000/api/containers/${CID}/watch" >/dev/null; then
  python3 -c "
import json, datetime, pathlib
p = pathlib.Path('$STATE_FILE')
try:
    s = json.loads(p.read_text())
except (FileNotFoundError, json.JSONDecodeError):
    s = {}
s['$CID'] = datetime.date.today().isoformat()
p.write_text(json.dumps(s, indent=2, sort_keys=True) + '\n')
"
  log "OK: ${NAME}"
else
  log "FALHA: ${NAME} — tentará de novo na próxima hora"
  exit 1
fi
