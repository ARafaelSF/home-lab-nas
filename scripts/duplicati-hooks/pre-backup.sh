#!/bin/sh
set -eu

STATE_FILE="/tmp/duplicati-stopped-containers.txt"
# /config é volume persistente; /scripts pode ser montagem read-only do repo
if [ -d /config ] && [ -w /config ]; then
  LOG_FILE="/config/duplicati-hooks.log"
else
  LOG_FILE="/scripts/hooks.log"
fi
MANIFEST_DIR="/source/homelab/backups/manifests"

# Se um backup anterior travou depois do PRE, repõe os containers antes de parar de novo
if [ -f "$STATE_FILE" ]; then
  echo "[$(date '+%F %T')] PRE: estado anterior detectado — a executar POST de recuperação" >> "$LOG_FILE"
  /scripts/post-backup.sh
fi

# Uptime Kuma / Hermes param cedo para não emitir falsos alertas na janela de backup.
# Prometheus/Grafana/InfluxDB: evita FileLocked (grafana.db, influxd.bolt) e backup mais consistente.
# AdGuard fica no ar para manter DNS/rede.
STOP_ORDER="
uptime-kuma
hermes-agent
immich_server
immich_machine_learning
immich_postgres
mealie
vaultwarden
portainer
filebrowser
prometheus
grafana
influxdb
"

: > "$STATE_FILE"
echo "[$(date '+%F %T')] PRE: iniciando parada controlada" >> "$LOG_FILE"

for c in $STOP_ORDER; do
  [ -z "$c" ] && continue
  if docker ps --format '{{.Names}}' | grep -qx "$c"; then
    # Hermes: SIGKILL evita o aviso Telegram "Gateway shutting down" no shutdown
    # gracioso (SIGTERM). A config gateway_restart_notification só entra em vigor
    # após restart do gateway — parada brusca no backup é segura (sem sessões activas).
    if [ "$c" = "hermes-agent" ]; then
      docker kill "$c" >/dev/null 2>&1 || true
      echo "[$(date '+%F %T')] PRE: parado $c (kill, sem aviso Telegram)" >> "$LOG_FILE"
    else
      docker stop -t 30 "$c" >/dev/null
      echo "[$(date '+%F %T')] PRE: parado $c" >> "$LOG_FILE"
    fi
    echo "$c" >> "$STATE_FILE"
  else
    echo "[$(date '+%F %T')] PRE: $c já estava parado/ausente" >> "$LOG_FILE"
  fi
done

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
