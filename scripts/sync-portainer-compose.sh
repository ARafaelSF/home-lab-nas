#!/bin/bash
# Restaura docker-compose.yml (e .env em falta) no volume portainer_data.
# Corrige: "Unable to retrieve stack file: Could not get the contents of docker-compose.yml"
#
# Uso: sudo ./sync-portainer-compose.sh
# Depois: reiniciar Portainer ou refrescar a página Stacks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAP_FILE="$REPO_ROOT/config/portainer/stacks-map.json"
PORTAINER_COMPOSE="${PORTAINER_COMPOSE:-/var/lib/docker/volumes/portainer_data/_data/compose}"

if [[ ! -d "$PORTAINER_COMPOSE" ]]; then
  PORTAINER_COMPOSE="$(docker volume inspect portainer_data --format '{{.Mountpoint}}' 2>/dev/null)/compose"
fi

if [[ ! -d "$PORTAINER_COMPOSE" ]]; then
  echo "ERRO: volume portainer_data/compose não encontrado"
  exit 1
fi

write_env_from_container() {
  local stack_id="$1"
  local container="$2"
  local dest="$PORTAINER_COMPOSE/$stack_id/.env"
  [[ -f "$dest" ]] && return 0

  if ! docker inspect "$container" &>/dev/null; then
    return 0
  fi

  docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' \
    | grep -E '^(TUNNEL_TOKEN|SETTINGS_ENCRYPTION_KEY|DUPLICATI_WEBSERVICE_PASSWORD|DUPLICATI__WEBSERVICE_PASSWORD|WUD_MQTT_PASSWORD)=' \
    >"$dest" || true

  if [[ -s "$dest" ]]; then
    chmod 600 "$dest"
    echo "  .env recriado a partir de $container"
  else
    rm -f "$dest"
  fi
}

restore_immich_env() {
  local dest="$PORTAINER_COMPOSE/8/.env"
  [[ -f "$dest" ]] && return 0
  local bak="$PORTAINER_COMPOSE/8/stack.env.bak"
  if [[ -f "$bak" ]]; then
    cp "$bak" "$dest"
    chmod 600 "$dest"
    echo "  .env Immich a partir de stack.env.bak"
  fi
}

echo "=== Sync Portainer compose ← homelab ==="
echo "Destino: $PORTAINER_COMPOSE"
echo

while IFS= read -r stack_id; do
  service="$(python3 -c "import json; m=json.load(open('$MAP_FILE')); print(m['$stack_id'])")"
  src="$REPO_ROOT/compose/$service/docker-compose.yml"
  dest_dir="$PORTAINER_COMPOSE/$stack_id"
  dest_file="$dest_dir/docker-compose.yml"

  if [[ ! -f "$src" ]]; then
    echo "[$stack_id] $service — IGNORADO (sem $src)"
    continue
  fi

  mkdir -p "$dest_dir"
  cp "$src" "$dest_file"
  chmod 600 "$dest_file" 2>/dev/null || chmod 644 "$dest_file"
  echo "[$stack_id] $service — OK"

  case "$stack_id" in
    4) write_env_from_container 4 cloudflared ;;
    8) restore_immich_env ;;
    25) write_env_from_container 25 duplicati ;;
    26) write_env_from_container 26 wud ;;
  esac
done < <(python3 -c "
import json
m = json.load(open('$MAP_FILE'))
for k in sorted(m.keys(), key=int):
    print(k)
")

echo
echo "Concluído. Reinicie o Portainer se a UI não actualizar:"
echo "  docker restart portainer"
