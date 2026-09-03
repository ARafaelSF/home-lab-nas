#!/bin/bash
# Pós-deploy: bucket home_energy + tokens HA/Grafana (InfluxDB 2.x)
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "$COMPOSE_DIR/.env"

ORG="${INFLUXDB_ORG:-homelab}"
HA_BUCKET="${INFLUXDB_HA_BUCKET:-home_energy}"
ADMIN_TOKEN="${INFLUXDB_ADMIN_TOKEN}"

influx() {
  docker exec -e INFLUX_TOKEN="$ADMIN_TOKEN" influxdb influx "$@"
}

echo "==> Aguardar InfluxDB..."
for i in $(seq 1 30); do
  if docker exec influxdb influx ping >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "==> Bucket ${HA_BUCKET}..."
if ! influx bucket list --org "$ORG" --name "$HA_BUCKET" 2>/dev/null | grep -q "$HA_BUCKET"; then
  influx bucket create --org "$ORG" --name "$HA_BUCKET" --retention 0
fi

echo "==> Token HA (write)..."
if ! influx auth list --org "$ORG" 2>/dev/null | grep -q 'ha-writer'; then
  HA_TOKEN=$(influx auth create \
    --org "$ORG" \
    --description 'ha-writer' \
    --write-bucket "$(influx bucket list --org "$ORG" --name "$HA_BUCKET" --hide-headers | awk '{print $1}')" \
    --hide-headers | awk '{print $3}')
  echo "INFLUXDB_HA_WRITE_TOKEN=${HA_TOKEN}" >> "$COMPOSE_DIR/.env.tokens.new"
fi

echo "==> Token Grafana (read)..."
if ! influx auth list --org "$ORG" 2>/dev/null | grep -q 'grafana-reader'; then
  GRAFANA_TOKEN=$(influx auth create \
    --org "$ORG" \
    --description 'grafana-reader' \
    --read-bucket "$(influx bucket list --org "$ORG" --name "$HA_BUCKET" --hide-headers | awk '{print $1}')" \
    --hide-headers | awk '{print $3}')
  echo "INFLUXDB_GRAFANA_READ_TOKEN=${GRAFANA_TOKEN}" >> "$COMPOSE_DIR/.env.tokens.new"
fi

echo "OK: verifique .env.tokens.new se tokens novos foram criados."
