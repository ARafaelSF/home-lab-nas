#!/usr/bin/env bash
# Verifica updates WUD um container de cada vez (fila horária).
# Evita 429 no ghcr.io quando vários containers são consultados em batch.
# Não marca como OK se a API devolver error (429/403/etc.) — tenta de novo.
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
    has_err = 1 if c.get('error') else 0
    # Prioridade: ainda não ok hoje; com erro; ghcr; mais antigo; nome
    rows.append((last == today and not has_err, not has_err, reg_name != 'ghcr.public', last, name, cid))

if not rows:
    sys.exit(0)

rows.sort()
done, _ok, _ghcr, _last, name, cid = rows[0]
if done:
    sys.exit(0)

print(cid)
print(name)
"
)

if [[ ${#PICK[@]} -lt 2 ]]; then
  log "todos os containers já verificados hoje — nada a fazer"
  exit 0
fi

CID="${PICK[0]}"
NAME="${PICK[1]}"

log "verificando: ${NAME} (${CID:0:8}…)"
RESP="$(docker exec wud curl -sf -X POST "http://127.0.0.1:3000/api/containers/${CID}/watch" 2>/dev/null || true)"
if [[ -z "$RESP" ]]; then
  log "FALHA: ${NAME} — sem resposta da API"
  exit 1
fi

ERR="$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    print('parse'); sys.exit(0)
err = d.get('error') if isinstance(d, dict) else None
if isinstance(err, dict):
    print(err.get('message') or err)
elif err:
    print(err)
" "$RESP")"

if [[ -n "$ERR" ]]; then
  log "FALHA: ${NAME} — ${ERR} (não marca como feito; nova tentativa à hora seguinte)"
  exit 1
fi

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
