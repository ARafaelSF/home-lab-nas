#!/bin/sh
set -eu

STATE_FILE="/tmp/duplicati-stopped-containers.txt"
LOG_FILE="/scripts/hooks.log"

# Home Assistant (DUPLICATI__* definidas pelo Duplicati no run-script-after)
if [ -n "${DUPLICATI__PARSED_RESULT:-}" ] && [ -x /scripts/duplicati_to_ha.sh ]; then
  /scripts/duplicati_to_ha.sh || true
fi

echo "[$(date '+%F %T')] POST: iniciando subida" >> "$LOG_FILE"

if [ -f "$STATE_FILE" ]; then
  tac "$STATE_FILE" | while IFS= read -r c; do
    [ -n "$c" ] || continue
    if [ "$c" = "uptime-kuma" ]; then
      echo "[$(date '+%F %T')] POST: uptime-kuma será iniciado por último" >> "$LOG_FILE"
      continue
    fi
    if docker start "$c" >/dev/null 2>&1; then
      echo "[$(date '+%F %T')] POST: iniciado $c" >> "$LOG_FILE"
    else
      echo "[$(date '+%F %T')] POST: falha ao iniciar $c" >> "$LOG_FILE"
    fi
  done
  rm -f "$STATE_FILE"
fi

# Immich: garantir stack completo (PRE pode ter parado sem POST anterior)
for c in immich_postgres immich_redis immich_machine_learning immich_server; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$c"; then
    if docker start "$c" >/dev/null 2>&1; then
      echo "[$(date '+%F %T')] POST: garantido $c" >> "$LOG_FILE"
    fi
  fi
done

if docker ps -a --format '{{.Names}}' | grep -qx "uptime-kuma" \
  && ! docker ps --format '{{.Names}}' | grep -qx "uptime-kuma"; then
  echo "[$(date '+%F %T')] POST: uptime-kuma agendado para subir em 90s" >> "$LOG_FILE"
  (
    sleep 90
    if docker start uptime-kuma >/dev/null 2>&1; then
      echo "[$(date '+%F %T')] POST: iniciado uptime-kuma" >> "$LOG_FILE"
    else
      echo "[$(date '+%F %T')] POST: falha ao iniciar uptime-kuma" >> "$LOG_FILE"
    fi
  ) >/dev/null 2>&1 &
fi

echo "[$(date '+%F %T')] POST: concluído" >> "$LOG_FILE"
