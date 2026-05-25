#!/bin/sh
set -eu

STATE_FILE="/tmp/duplicati-stopped-containers.txt"
LOG_FILE="/scripts/hooks.log"

echo "[$(date '+%F %T')] POST: iniciando subida" >> "$LOG_FILE"

if [ -f "$STATE_FILE" ]; then
  tac "$STATE_FILE" | while IFS= read -r c; do
    [ -n "$c" ] || continue
    if docker start "$c" >/dev/null 2>&1; then
      echo "[$(date '+%F %T')] POST: iniciado $c" >> "$LOG_FILE"
    else
      echo "[$(date '+%F %T')] POST: falha ao iniciar $c" >> "$LOG_FILE"
    fi
  done
  rm -f "$STATE_FILE"
fi

echo "[$(date '+%F %T')] POST: concluído" >> "$LOG_FILE"
