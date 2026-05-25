#!/bin/bash
# Sobe um stack a partir deste repositório (mesmos nomes de projeto que no Portainer).
# Uso: ./deploy-stack.sh jellyfin
# Requer .env preenchido na pasta do serviço (ver .env.example).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STACK="${1:-}"

if [[ -z "$STACK" ]]; then
  echo "Uso: $0 <nome-do-serviço>"
  echo "Ex.: adguard-home cloudflare-tunnel duplicati immich jellyfin npm uptime-kuma wud"
  ls -1 "$REPO_ROOT/compose"
  exit 1
fi

DIR="$REPO_ROOT/compose/$STACK"
COMPOSE_FILE="$DIR/docker-compose.yml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "ERRO: não existe $COMPOSE_FILE"
  exit 1
fi

# Nome do projeto Docker = nome da pasta (igual Portainer: jellyfin, immich, …)
PROJECT="$STACK"
# Exceções alinhadas ao host atual
case "$STACK" in
  nginx-proxy-manager) PROJECT="npm" ;;
  adguard-home) PROJECT="adguard-home" ;;
  cloudflare-tunnel) PROJECT="cloudflare-tunnel" ;;
esac

cd "$DIR"
if [[ -f .env.example && ! -f .env ]]; then
  echo "AVISO: crie $DIR/.env a partir de .env.example antes de subir."
fi
if [[ "$STACK" == "immich" && -f .env.example && ! -f .env ]]; then
  echo "AVISO: copie .env.example para .env e preencha senhas."
fi

echo "=== docker compose -p $PROJECT up -d ==="
docker compose -p "$PROJECT" -f docker-compose.yml up -d
echo "OK: $STACK"
