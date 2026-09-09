#!/bin/bash
set -euo pipefail

ENV_FILE="${MINIPC_TEMP_ENV:-/opt/container-ops/minipc-temp.env}"
# shellcheck disable=SC1090
source "$ENV_FILE"

TEMP_URL="${TEMP_URL:-http://192.168.3.20:9108/temp}"
MQTT_HOST="${MQTT_HOST:-192.168.3.10}"
MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-homelab/minipc/cpu_temp}"

payload="$(curl -fsS --max-time 4 "$TEMP_URL")"
temp="$(python3 -c 'import json,sys; v=json.load(sys.stdin).get("cpu_c");
print("" if v is None else v)' <<<"$payload")"

if [[ -z "$temp" ]]; then
  echo "temperatura vazia: $payload" >&2
  exit 1
fi

disc_topic="${MQTT_DISCOVERY_TOPIC:-homeassistant/sensor/sistema_temperatura_cpu_minipc/config}"
disc_payload='{"name":"Temperatura CPU MiniPC","unique_id":"sistema_temperatura_cpu_minipc","object_id":"sistema_temperatura_cpu_minipc","default_entity_id":"sensor.sistema_temperatura_cpu_minipc","state_topic":"'"$MQTT_TOPIC"'","unit_of_measurement":"°C","device_class":"temperature","state_class":"measurement","expire_after":180,"icon":"mdi:thermometer","device":{"identifiers":["minipc_proxmox_host"],"name":"MiniPC Proxmox","manufacturer":"Homelab","model":"Host Proxmox"}}'

mosquitto_pub \
  -h "$MQTT_HOST" \
  -p "$MQTT_PORT" \
  -u "$MQTT_USER" \
  -P "$MQTT_PASSWORD" \
  -t "$disc_topic" \
  -m "$disc_payload" \
  -r

mosquitto_pub \
  -h "$MQTT_HOST" \
  -p "$MQTT_PORT" \
  -u "$MQTT_USER" \
  -P "$MQTT_PASSWORD" \
  -t "$MQTT_TOPIC" \
  -m "$temp"
