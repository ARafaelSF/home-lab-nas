#!/usr/bin/env bash
# Watchdog homelab — corre via Hermes cron (--no-agent --deliver telegram).
# Lê métricas do Glances e estado dos containers Docker.
# Só imprime quando há algo a reportar (stdout vazio = silêncio).

set -euo pipefail

GLANCES_URL="${GLANCES_URL:-http://192.168.3.21:61208}"
DISK_WARN="${DISK_WARN:-85}"
MEM_WARN="${MEM_WARN:-90}"
CPU_WARN="${CPU_WARN:-95}"

alerts=()

# --- Disco (/) ---
disk_used="$(curl -sf "${GLANCES_URL}/api/4/fs" | python3 -c "
import json,sys
data=json.load(sys.stdin)
for m in data:
    if m.get('mnt_point')=='/':
        print(int(m.get('percent',0)))
        break
" 2>/dev/null || echo "")"
if [[ -n "$disk_used" && "$disk_used" -ge "$DISK_WARN" ]]; then
  alerts+=("Disco / em ${disk_used}% (limite ${DISK_WARN}%)")
fi

# --- RAM ---
mem_used="$(curl -sf "${GLANCES_URL}/api/4/mem" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(int(d.get('percent',0)))
" 2>/dev/null || echo "")"
if [[ -n "$mem_used" && "$mem_used" -ge "$MEM_WARN" ]]; then
  alerts+=("RAM em ${mem_used}% (limite ${MEM_WARN}%)")
fi

# --- CPU (média rápida) ---
cpu_used="$(curl -sf "${GLANCES_URL}/api/4/cpu" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(int(d.get('total',0)))
" 2>/dev/null || echo "")"
if [[ -n "$cpu_used" && "$cpu_used" -ge "$CPU_WARN" ]]; then
  alerts+=("CPU em ${cpu_used}% (limite ${CPU_WARN}%)")
fi

# --- Containers unhealthy / restarting ---
if [[ -S /var/run/docker.sock ]]; then
  bad="$(docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null | grep -iE 'unhealthy|restarting|exited' | grep -v 'Exited (0)' || true)"
  if [[ -n "$bad" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && alerts+=("Container: ${line}")
    done <<<"$bad"
  fi
fi

if [[ ${#alerts[@]} -eq 0 ]]; then
  exit 0
fi

echo "⚠️ Homelab — alertas ($(date '+%d/%m %H:%M'))"
for a in "${alerts[@]}"; do
  echo "• $a"
done
