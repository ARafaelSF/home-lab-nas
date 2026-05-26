#!/bin/sh
set -eu

STATE_FILE="/tmp/duplicati-stopped-containers.txt"
LOG_FILE="/scripts/hooks.log"
MANIFEST_DIR="/source/homelab/backups/manifests"

STOP_ORDER="
immich_server
immich_machine_learning
immich_postgres
mealie
vaultwarden
uptime-kuma
portainer
adguardhome
filebrowser
"

: > "$STATE_FILE"
echo "[$(date '+%F %T')] PRE: iniciando parada controlada" >> "$LOG_FILE"

for c in $STOP_ORDER; do
  [ -z "$c" ] && continue
  if docker ps --format '{{.Names}}' | grep -qx "$c"; then
    docker stop -t 30 "$c" >/dev/null
    echo "$c" >> "$STATE_FILE"
    echo "[$(date '+%F %T')] PRE: parado $c" >> "$LOG_FILE"
  else
    echo "[$(date '+%F %T')] PRE: $c já estava parado/ausente" >> "$LOG_FILE"
  fi
done

# Dar tempo ao SO libertar locks em SQLite (portainer.db, filebrowser.db, etc.)
sleep 3

mkdir -p "$MANIFEST_DIR"
STAMP=$(date '+%Y%m%d-%H%M%S')
MANIFEST="$MANIFEST_DIR/runtime-${STAMP}.txt"
{
  echo "# Homelab runtime snapshot — $(date -Iseconds)"
  echo "## hostname"
  hostname
  echo "## docker ps -a"
  docker ps -a --no-trunc
  echo "## docker volume ls"
  docker volume ls
  echo "## docker network ls"
  docker network ls
} > "$MANIFEST" 2>>"$LOG_FILE"
echo "[$(date '+%F %T')] PRE: manifesto $MANIFEST" >> "$LOG_FILE"

ls -1t "$MANIFEST_DIR"/runtime-*.txt 2>/dev/null | tail -n +15 | while IFS= read -r old; do
  rm -f "$old"
done

echo "[$(date '+%F %T')] PRE: concluído" >> "$LOG_FILE"
