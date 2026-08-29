#!/usr/bin/env bash
# Verifica updates WUD um container de cada vez (fila horária).
# Evita 429 no ghcr.io quando vários containers são consultados em batch.
# Após MAX_FAILS falhas no mesmo dia, marca como tentado e avança na fila.
set -euo pipefail

STATE_DIR="${WUD_STAGGER_STATE_DIR:-/var/lib/wud-stagger}"
STATE_FILE="${STATE_DIR}/last-check.json"
FAIL_FILE="${STATE_DIR}/fail-count.json"
MAX_FAILS="${WUD_STAGGER_MAX_FAILS:-3}"
LOG_TAG="wud-stagger"

log() { logger -t "$LOG_TAG" "$*"; echo "[$(date '+%F %T')] $*"; }

mkdir -p "$STATE_DIR"
export TODAY="$(date '+%F')"
export STATE_FILE
export FAIL_FILE
export MAX_FAILS

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
fail_path = os.environ['FAIL_FILE']
max_fails = int(os.environ.get('MAX_FAILS', '3'))
try:
    with open(state_path) as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    state = {}
try:
    with open(fail_path) as f:
        fails = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    fails = {}

rows = []
for c in json.load(sys.stdin):
    if c.get('watch') is False:
        continue
    cid = c['id']
    name = c['name']
    registry = (c.get('image') or {}).get('registry') or {}
    reg_name = registry.get('name', '')
    last = state.get(cid, '')
    fail_entry = fails.get(cid, {})
    if fail_entry.get('date') != today:
        fail_count = 0
    else:
        fail_count = int(fail_entry.get('count', 0))
    has_err = 1 if c.get('error') else 0
    done_today = last == today
    skipped = done_today or fail_count >= max_fails
    # Prioridade: não feito hoje; menos falhas hoje; sem erro stale; ghcr; mais antigo; nome
    rows.append((
        skipped,
        fail_count,
        has_err,
        reg_name != 'ghcr.public',
        last,
        name,
        cid,
    ))

if not rows:
    sys.exit(0)

rows.sort()
skipped, fail_count, _has_err, _ghcr, _last, name, cid = rows[0]
if skipped:
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
export CID
RESP="$(docker exec wud curl -sf -X POST "http://127.0.0.1:3000/api/containers/${CID}/watch" 2>/dev/null || true)"
if [[ -z "$RESP" ]]; then
  log "FALHA: ${NAME} — sem resposta da API"
  exit 1
fi

RESULT="$(python3 -c "
import json, datetime, os, pathlib, sys

today = os.environ['TODAY']
cid = os.environ['CID']
state_path = pathlib.Path(os.environ['STATE_FILE'])
fail_path = pathlib.Path(os.environ['FAIL_FILE'])
max_fails = int(os.environ.get('MAX_FAILS', '3'))

try:
    d = json.loads(sys.argv[1])
except Exception:
    print('FAIL|parse|skip')
    sys.exit(0)

err = d.get('error') if isinstance(d, dict) else None
msg = ''
if isinstance(err, dict):
    msg = err.get('message') or str(err)
elif err:
    msg = str(err)

if not msg:
    try:
        s = json.loads(state_path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        s = {}
    s[cid] = datetime.date.today().isoformat()
    state_path.write_text(json.dumps(s, indent=2, sort_keys=True) + '\n')
    try:
        fails = json.loads(fail_path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        fails = {}
    if cid in fails:
        del fails[cid]
        fail_path.write_text(json.dumps(fails, indent=2, sort_keys=True) + '\n')
    print('OK')
    sys.exit(0)

try:
    fails = json.loads(fail_path.read_text())
except (FileNotFoundError, json.JSONDecodeError):
    fails = {}

entry = fails.get(cid, {})
if entry.get('date') != today:
    count = 1
else:
    count = int(entry.get('count', 0)) + 1
fails[cid] = {'date': today, 'count': count}
fail_path.write_text(json.dumps(fails, indent=2, sort_keys=True) + '\n')

action = f'retry_{count}'
if count >= max_fails:
    try:
        s = json.loads(state_path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        s = {}
    s[cid] = today
    state_path.write_text(json.dumps(s, indent=2, sort_keys=True) + '\n')
    action = f'skip_after_{count}'
print('FAIL|' + msg.replace('|', '/') + '|' + action)
" "$RESP")"

if [[ "$RESULT" == "OK" ]]; then
  log "OK: ${NAME}"
  exit 0
fi

IFS='|' read -r _ ERR ACTION <<<"$RESULT"

if [[ "$ACTION" == skip_after_* ]]; then
  log "FALHA: ${NAME} — ${ERR} (${ACTION}; avança fila até amanhã)"
  exit 0
fi

log "FALHA: ${NAME} — ${ERR} (${ACTION}; nova tentativa à hora seguinte)"
exit 1
