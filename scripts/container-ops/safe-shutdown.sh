#!/usr/bin/env bash
# Desligamento seguro do homelab: VM HA → VM Docker → host Proxmox.
# Agenda a sequência no Proxmox (nohup) para sobreviver ao shutdown da VM Docker.
set -euo pipefail

LOG_DIR="${CONTAINER_OPS_LOG_DIR:-/opt/container-ops/logs}"
LOG_FILE="${LOG_DIR}/safe-shutdown.log"
SSH_HOST="${PROXMOX_SSH_HOST:-proxmox}"
VM_HA="${PROXMOX_VM_HA:-101}"
VM_DOCKER="${PROXMOX_VM_DOCKER:-100}"
HA_WAIT_SEC="${SHUTDOWN_HA_WAIT_SEC:-180}"
DOCKER_WAIT_SEC="${SHUTDOWN_DOCKER_WAIT_SEC:-240}"
DRY_RUN=0
REMOTE_PATH="/usr/local/sbin/homelab-safe-shutdown.sh"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }

usage() {
  cat <<'EOF'
Uso: safe-shutdown.sh [--dry-run]

  --dry-run   Só verifica SSH/VMs; não desliga nada.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Argumento desconhecido: $arg" >&2; usage; exit 2 ;;
  esac
done

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$SSH_HOST" 'true'; then
  log "ERRO: sem SSH para ${SSH_HOST}"
  exit 1
fi

status_json="$(ssh "$SSH_HOST" "qm status ${VM_HA}; qm status ${VM_DOCKER}; hostname -s")"
log "Estado actual:"$'\n'"${status_json}"

# Script que corre no Proxmox (instalado/actualizado a cada pedido).
REMOTE_BODY=$(cat <<EOF
#!/bin/bash
set -eu
LOG=/var/log/homelab-safe-shutdown.log
VM_HA=${VM_HA}
VM_DOCKER=${VM_DOCKER}
HA_WAIT_SEC=${HA_WAIT_SEC}
DOCKER_WAIT_SEC=${DOCKER_WAIT_SEC}

log() { printf '[%s] %s\n' "\$(date '+%Y-%m-%d %H:%M:%S')" "\$*" | tee -a "\$LOG"; }

wait_stopped() {
  local vmid="\$1" timeout="\$2" i
  for i in \$(seq 1 "\$timeout"); do
    if qm status "\$vmid" 2>/dev/null | grep -q 'status: stopped'; then
      log "VM \$vmid parada"
      return 0
    fi
    sleep 1
  done
  log "AVISO: VM \$vmid ainda não parou após \${timeout}s — a forçar stop"
  qm stop "\$vmid" || true
  sleep 3
}

log "=== Início desligamento seguro homelab ==="
log "1/3 Shutdown gracioso VM \$VM_HA (homeassistant)"
qm shutdown "\$VM_HA" --timeout "\$HA_WAIT_SEC" || true
wait_stopped "\$VM_HA" "\$HA_WAIT_SEC"

log "2/3 Shutdown gracioso VM \$VM_DOCKER (docker)"
qm shutdown "\$VM_DOCKER" --timeout "\$DOCKER_WAIT_SEC" || true
wait_stopped "\$VM_DOCKER" "\$DOCKER_WAIT_SEC"

log "3/3 Shutdown host Proxmox"
sync || true
shutdown -h now
EOF
)

b64="$(printf '%s' "$REMOTE_BODY" | base64 -w0)"
ssh "$SSH_HOST" "echo '${b64}' | base64 -d > '${REMOTE_PATH}' && chmod 700 '${REMOTE_PATH}'"
log "Script remoto instalado em ${SSH_HOST}:${REMOTE_PATH}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY-RUN ok — script instalado, nenhum shutdown enviado."
  exit 0
fi

log "A agendar sequência no Proxmox (nohup)…"
ssh "$SSH_HOST" "nohup '${REMOTE_PATH}' >>/var/log/homelab-safe-shutdown.log 2>&1 & echo STARTED:\$!"
log "Sequência aceite. HA → Docker → Proxmox. Este host vai desligar em breve."
exit 0
