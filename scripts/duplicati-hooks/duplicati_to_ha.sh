#!/usr/bin/env bash
# Notifica o Home Assistant quando um job Duplicati termina.
# Variáveis do Duplicati: DUPLICATI__PARSED_RESULT, DUPLICATI__BACKUP_NAME
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
LOG_FILE="${LOG_FILE:-/scripts/duplicati_to_ha.log}"

RESULT="${DUPLICATI__PARSED_RESULT:-}"
JOB_NAME="${DUPLICATI__BACKUP_NAME:-Duplicati backup}"
TIME_NOW="$(date -Iseconds 2>/dev/null || date --iso-8601=seconds)"

STATUS="unknown"
case "$RESULT" in
  Success) STATUS="success" ;;
  Warning) STATUS="warning" ;;
  Error)   STATUS="error" ;;
esac

MESSAGE="Resultado Duplicati: ${RESULT:-desconhecido}"

JOB_KEY="unknown"
case "${JOB_NAME,,}" in
  *docker-local*|*ssd*) JOB_KEY="ssd" ;;
  *onedrive*|*homelab-onedrive*) JOB_KEY="onedrive" ;;
esac

JSON_DATA="$(
  python3 -c '
import json, sys
print(json.dumps({
    "job_name": sys.argv[1],
    "job_key": sys.argv[2],
    "status": sys.argv[3],
    "message": sys.argv[4],
    "time": sys.argv[5],
}))
' "$JOB_NAME" "$JOB_KEY" "$STATUS" "$MESSAGE" "$TIME_NOW"
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

log_line "job=${JOB_NAME} status=${STATUS} result=${RESULT:-<vazio>} mode=${HA_NOTIFY_MODE}"

exit 0
