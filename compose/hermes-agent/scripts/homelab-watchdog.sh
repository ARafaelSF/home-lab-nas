#!/usr/bin/env bash
# Watchdog homelab — corre via Hermes cron (--no-agent --deliver telegram).
# Lê métricas do Glances e estado dos containers Docker.
# Só imprime quando há algo a reportar (stdout vazio = silêncio).
# Mensagens em português, claras — detalhes técnicos só se o utilizador pedir.

set -euo pipefail

GLANCES_URL="${GLANCES_URL:-http://192.168.3.21:61208}"
DISK_WARN="${DISK_WARN:-85}"
MEM_WARN="${MEM_WARN:-90}"
CPU_WARN="${CPU_WARN:-95}"

# Containers que o Duplicati PRE para de propósito (ver /opt/duplicati-scripts/pre-backup.sh).
# Durante a janela de backup NÃO são alerta.
BACKUP_STOP_RE='^(uptime-kuma|hermes-agent|immich_server|immich_machine_learning|immich_postgres|mealie|vaultwarden|portainer|filebrowser|prometheus|grafana)$'

# Nomes amigáveis para serviços conhecidos
friendly_name() {
  case "$1" in
    immich_server) echo "Immich (fotos)" ;;
    immich_machine_learning) echo "Immich (IA)" ;;
    immich_postgres) echo "Immich (base de dados)" ;;
    uptime-kuma) echo "Uptime Kuma (monitorização)" ;;
    hermes-agent) echo "Hermes (Telegram)" ;;
    vaultwarden) echo "Vaultwarden (palavras-passe)" ;;
    filebrowser) echo "FileBrowser (ficheiros)" ;;
    nginx-proxy-manager|npm) echo "Nginx Proxy Manager" ;;
    adguard-home|adguardhome) echo "AdGuard (DNS)" ;;
    *) echo "$1" ;;
  esac
}

# Traduz estado Docker para frase curta em PT
friendly_status() {
  local status="$1"
  local lower
  lower="$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower" == *unhealthy* ]]; then
    echo "não está saudável"
  elif [[ "$lower" == *restarting* ]]; then
    echo "está a reiniciar em ciclo"
  elif [[ "$lower" == *exited\ \(143\)* ]]; then
    echo "parou (paragem normal / SIGTERM)"
  elif [[ "$lower" == *exited\ \(0\)* ]]; then
    echo "parou sem erro"
  elif [[ "$lower" == *exited* ]]; then
    echo "parou de forma inesperada"
  else
    echo "com problema (${status})"
  fi
}

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
  alerts+=("O disco do servidor está a encher: ${disk_used}% usado (aviso a partir de ${DISK_WARN}%)")
fi

# --- RAM ---
mem_used="$(curl -sf "${GLANCES_URL}/api/4/mem" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(int(d.get('percent',0)))
" 2>/dev/null || echo "")"
if [[ -n "$mem_used" && "$mem_used" -ge "$MEM_WARN" ]]; then
  alerts+=("A memória (RAM) está alta: ${mem_used}% (aviso a partir de ${MEM_WARN}%)")
fi

# --- CPU (média rápida) ---
cpu_used="$(curl -sf "${GLANCES_URL}/api/4/cpu" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(int(d.get('total',0)))
" 2>/dev/null || echo "")"
if [[ -n "$cpu_used" && "$cpu_used" -ge "$CPU_WARN" ]]; then
  alerts+=("O processador está muito ocupado: ${cpu_used}% (aviso a partir de ${CPU_WARN}%)")
fi

# --- Janela de backup Duplicati? (ficheiro de estado criado pelo PRE) ---
backup_window=0
if [[ -S /var/run/docker.sock ]] \
  && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx duplicati \
  && docker exec duplicati test -f /tmp/duplicati-stopped-containers.txt 2>/dev/null; then
  backup_window=1
fi

# --- Containers unhealthy / restarting ---
if [[ -S /var/run/docker.sock ]]; then
  bad="$(docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null | grep -iE 'unhealthy|restarting|exited' | grep -v 'Exited (0)' || true)"
  if [[ -n "$bad" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      name="${line%%$'\t'*}"
      status="${line#*$'\t'}"
      if [[ "$backup_window" -eq 1 && "$name" =~ $BACKUP_STOP_RE ]]; then
        continue
      fi
      label="$(friendly_name "$name")"
      state="$(friendly_status "$status")"
      alerts+=("O serviço ${label} ${state}")
    done <<<"$bad"
  fi
fi

if [[ ${#alerts[@]} -eq 0 ]]; then
  exit 0
fi

echo "⚠️ Homelab — atenção ($(date '+%d/%m %H:%M'))"
for a in "${alerts[@]}"; do
  echo "• $a"
done
echo ""
echo "Se quiseres detalhes técnicos ou que eu investigue, é só dizer."
