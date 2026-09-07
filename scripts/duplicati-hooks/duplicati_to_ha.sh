#!/usr/bin/env bash
# Notifica o Home Assistant quando um job Duplicati termina.
# Variáveis do Duplicati: DUPLICATI__PARSED_RESULT, DUPLICATI__BACKUP_NAME, DUPLICATI__RESULTFILE, …
# Config opcional: /scripts/duplicati-ha.env (ver duplicati-ha.env.example)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/duplicati-ha.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

HA_URL="${HA_URL:-http://192.168.3.10:8123}"
# webhook (padrão, sem token) | event (API /api/events) | both
HA_NOTIFY_MODE="${HA_NOTIFY_MODE:-webhook}"
# Preferir /config (volume persistente); /scripts pode ser montagem só de leitura
if [[ -d /config && -w /config ]]; then
  LOG_FILE="${LOG_FILE:-/config/duplicati_to_ha.log}"
else
  LOG_FILE="${LOG_FILE:-/scripts/duplicati_to_ha.log}"
fi

RESULT="${DUPLICATI__PARSED_RESULT:-}"
REMOTE_URL="${DUPLICATI__REMOTEURL:-}"
JOB_NAME="${DUPLICATI__backup_name:-${DUPLICATI__BACKUP_NAME:-}}"
OPERATION="${DUPLICATI__OPERATIONNAME:-${DUPLICATI__OPERATION_NAME:-backup}}"
RESULT_RAW="${DUPLICATI__RESULT:-}"
RESULT_FILE="${DUPLICATI__RESULTFILE:-${DUPLICATI__RESULT_FILE:-}}"

if [[ -z "$JOB_NAME" || "$JOB_NAME" == "Duplicati" ]]; then
  JOB_NAME="Duplicati backup"
fi
TIME_NOW="$(date -Iseconds 2>/dev/null || date --iso-8601=seconds)"

STATUS="unknown"
case "$RESULT" in
  Success) STATUS="success" ;;
  Warning) STATUS="warning" ;;
  Error|Fatal) STATUS="error" ;;
esac

# Extrai detalhe útil do ResultFile JSON / texto DUPLICATI__RESULT
DETAIL="$(
  RESULT_FILE="$RESULT_FILE" RESULT_RAW="$RESULT_RAW" RESULT="$RESULT" python3 - <<'PY'
import json, os, re

def clip(s, n=450):
    s = re.sub(r"\s+", " ", (s or "")).strip()
    return s if len(s) <= n else s[: n - 1] + "…"

rf = os.environ.get("RESULT_FILE") or ""
raw = os.environ.get("RESULT_RAW") or ""
parsed = os.environ.get("RESULT") or ""
parts = []

data = None
if rf and os.path.isfile(rf):
    try:
        with open(rf, "r", encoding="utf-8", errors="replace") as f:
            data = json.load(f)
    except Exception:
        try:
            with open(rf, "r", encoding="utf-8", errors="replace") as f:
                txt = f.read()
            if txt.strip():
                parts.append(clip(txt, 300))
        except Exception:
            pass

if isinstance(data, dict):
    for key in ("MainOperation", "ParsedResult", "Interrupted"):
        if key in data and data[key] not in (None, ""):
            parts.append(f"{key}={data[key]}")
    # Contagens úteis
    for key in (
        "ExaminedFiles", "AddedFiles", "ModifiedFiles", "DeletedFiles",
        "AddedFolders", "DeletedFolders", "KnownFileSize", "BackendSize",
    ):
        if key in data and data[key] not in (None, "", 0):
            parts.append(f"{key}={data[key]}")
    # Mensagens / avisos / erros
    for key in ("Messages", "Warnings", "Errors", "Message", "Error", "Exception"):
        val = data.get(key)
        if not val:
            continue
        if isinstance(val, list):
            # Preferir erros/avisos; limitar a 3 linhas
            items = [str(x) for x in val if x]
            if not items:
                continue
            label = key.rstrip("s").lower()
            parts.append(f"{key}: " + " | ".join(clip(x, 160) for x in items[:3]))
            if len(items) > 3:
                parts.append(f"(+{len(items)-3} {label}s)")
        else:
            parts.append(f"{key}: {clip(str(val), 220)}")

if not parts and raw:
    # Texto livre do Duplicati (por vezes multi-linha)
    lines = [ln.strip() for ln in raw.splitlines() if ln.strip()]
    # Priorizar linhas com erro/aviso
    interesting = [ln for ln in lines if re.search(r"error|warning|fail|exception|denied|locked|cancel", ln, re.I)]
    use = interesting[:3] if interesting else lines[:2]
    parts.extend(clip(x, 200) for x in use)

msg = clip("; ".join(parts), 500) if parts else ""
print(msg)
PY
)"

if [[ -n "$DETAIL" ]]; then
  MESSAGE="Resultado: ${RESULT:-desconhecido}. ${DETAIL}"
else
  MESSAGE="Resultado Duplicati: ${RESULT:-desconhecido}"
fi
# Telegram / app: manter legível
MESSAGE="${MESSAGE:0:700}"

JOB_KEY="unknown"
case "${JOB_NAME,,}" in
  *docker-local*|*ssd*) JOB_KEY="ssd" ;;
  *onedrive*|*homelab-onedrive*) JOB_KEY="onedrive" ;;
esac

if [[ "$JOB_KEY" == "unknown" && -n "$REMOTE_URL" ]]; then
  case "${REMOTE_URL,,}" in
    *onedrive*) JOB_KEY="onedrive" ;;
    *docker-volumes*|file://*) JOB_KEY="ssd" ;;
  esac
fi

if [[ "$JOB_NAME" == "Duplicati backup" ]]; then
  case "$JOB_KEY" in
    ssd) JOB_NAME="docker-local" ;;
    onedrive) JOB_NAME="homelab-onedrive" ;;
  esac
fi

JSON_DATA="$(
  python3 -c '
import json, sys
print(json.dumps({
    "job_name": sys.argv[1],
    "job_key": sys.argv[2],
    "status": sys.argv[3],
    "message": sys.argv[4],
    "time": sys.argv[5],
    "result": sys.argv[6],
    "operation": sys.argv[7],
}, ensure_ascii=False))
' "$JOB_NAME" "$JOB_KEY" "$STATUS" "$MESSAGE" "$TIME_NOW" "${RESULT:-}" "${OPERATION:-}"
)"

log_line() {
  echo "[$(date '+%F %T')] $*" >>"$LOG_FILE" 2>/dev/null || true
}

ha_webhook() {
  curl -sS -m 20 -X POST \
    -H "Content-Type: application/json" \
    -d "$JSON_DATA" \
    "${HA_URL}/api/webhook/duplicati_backup_result" >/dev/null 2>&1 || true
}

ha_event() {
  [[ -z "${HA_TOKEN:-}" ]] && return 0
  curl -sS -m 20 -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$JSON_DATA" \
    "${HA_URL}/api/events/duplicati_backup_result" >/dev/null 2>&1 || true
}

case "$HA_NOTIFY_MODE" in
  event) ha_event ;;
  both)
    ha_webhook
    ha_event
    ;;
  *)
    ha_webhook
    if [[ -n "${HA_TOKEN:-}" ]]; then
      ha_event
    fi
    ;;
esac

log_line "job=${JOB_NAME} key=${JOB_KEY} status=${STATUS} result=${RESULT:-<vazio>} op=${OPERATION:-?} detail=${DETAIL:-<vazio>} remote=${REMOTE_URL:-<vazio>} mode=${HA_NOTIFY_MODE}"

exit 0
