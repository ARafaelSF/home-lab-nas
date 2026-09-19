#!/bin/bash
# Rotina semanal: backup inteligente (PBS) no principal → restaurar VMs paradas na reserva.
# Corre na VM Docker (ou qualquer host com SSH a proxmox / proxmox-reserva).
#
# Uso:
#   ./rotina-semanal.sh              # backup + restore + relatório
#   ./rotina-semanal.sh --check      # só valida conectividade e estado
#   ./rotina-semanal.sh --shutdown-reserva   # no fim, desliga o host .30
#   ./rotina-semanal.sh --shutdown-only      # só desliga o host .30 (sem backup)
#   ./rotina-semanal.sh --backup-only
#   ./rotina-semanal.sh --restore-only
#
set -euo pipefail

PRIMARY_SSH="${PRIMARY_SSH:-proxmox}"
RESERVA_SSH="${RESERVA_SSH:-proxmox-reserva}"
RESERVA_IP="${RESERVA_IP:-192.168.3.30}"
VMIDS=(101 100) # HA primeiro (menor), depois Docker
PBS_STORAGE_PRIMARY="${PBS_STORAGE_PRIMARY:-pbs-reserva}"
PBS_STORAGE_RESERVA="${PBS_STORAGE_RESERVA:-pbs-local}"
KEEP_LAST="${KEEP_LAST:-3}"
LOG_DIR_REMOTE="/var/log/homelab"
STATUS_LOCAL_DIR="${STATUS_LOCAL_DIR:-/var/log/homelab}"
NOTES_TEMPLATE='semanal-{{guestname}}-{{vmid}}'
HA_WEBHOOK_URL="${HA_WEBHOOK_URL:-http://192.168.3.10:8123/api/webhook/duplicati_backup_result}"
NOTIFY_HA="${NOTIFY_HA:-1}"
# Também notifica o webhook dedicado (Telegram / tomada) se distinto
HA_WEBHOOK_RESERVA_URL="${HA_WEBHOOK_RESERVA_URL:-http://192.168.3.10:8123/api/webhook/proxmox_reserva_backup_result}"

DO_CHECK=0
DO_BACKUP=1
DO_RESTORE=1
DO_SHUTDOWN=0
SHUTDOWN_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --check) DO_CHECK=1; DO_BACKUP=0; DO_RESTORE=0 ;;
    --backup-only) DO_RESTORE=0 ;;
    --restore-only) DO_BACKUP=0 ;;
    --shutdown-reserva) DO_SHUTDOWN=1 ;;
    --shutdown-only) SHUTDOWN_ONLY=1; DO_BACKUP=0; DO_RESTORE=0; DO_CHECK=0; DO_SHUTDOWN=1; NOTIFY_HA=0 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "opção desconhecida: $arg" >&2
      exit 2
      ;;
  esac
done

ts() { date -Is; }
log() { printf '%s %s\n' "$(ts)" "$*"; }

mkdir -p "$STATUS_LOCAL_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
STATUS_JSON="${STATUS_LOCAL_DIR}/pbs-rotina-semanal-status.json"
LOG_LOCAL="${STATUS_LOCAL_DIR}/pbs-rotina-semanal-${STAMP}.log"
ln -sfn "$LOG_LOCAL" "${STATUS_LOCAL_DIR}/pbs-rotina-semanal-latest.log"

exec > >(tee -a "$LOG_LOCAL") 2>&1

STARTED_AT="$(ts)"
ERROR_MSG=""
BACKUP_100=""
BACKUP_101=""
RESULT_OK=0

write_status() {
  local ok="$1"
  python3 - "$STATUS_JSON" "$ok" "$STARTED_AT" "$(ts)" "$ERROR_MSG" "$BACKUP_100" "$BACKUP_101" <<'PY'
import json, sys
path, ok, started, finished, err, b100, b101 = sys.argv[1:8]
data = {
    "ok": ok == "1",
    "started_at": started,
    "finished_at": finished,
    "error": err or None,
    "backup": {"100": b100 or None, "101": b101 or None},
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(f"status escrito: {path}")
PY
}

notify_ha() {
  local ok="$1"
  local status message
  if [[ "$NOTIFY_HA" != "1" ]]; then
    return 0
  fi
  if [[ "$ok" == "1" ]]; then
    status="success"
    message="Backup PBS + restore na reserva OK. 100=${BACKUP_100:-?} 101=${BACKUP_101:-?}"
  else
    status="error"
    message="${ERROR_MSG:-falha na rotina semanal Proxmox reserva}"
  fi
  local time_now
  time_now="$(date '+%Y-%m-%d %H:%M:%S')"

  # MQTT (fiável para o painel / badge)
  if command -v mosquitto_pub >/dev/null 2>&1; then
    local mqtt_host mqtt_port mqtt_user mqtt_pass
    mqtt_host="${MQTT_HOST:-192.168.3.10}"
    mqtt_port="${MQTT_PORT:-1883}"
    mqtt_user="${MQTT_USER:-}"
    mqtt_pass="${MQTT_PASSWORD:-}"
    if [[ -f /opt/container-ops/minipc-temp.env ]]; then
      # shellcheck disable=SC1091
      source /opt/container-ops/minipc-temp.env
      mqtt_host="${MQTT_HOST:-$mqtt_host}"
      mqtt_port="${MQTT_PORT:-$mqtt_port}"
      mqtt_user="${MQTT_USER:-$mqtt_user}"
      mqtt_pass="${MQTT_PASSWORD:-$mqtt_pass}"
    fi
    local auth=()
    [[ -n "$mqtt_user" ]] && auth+=(-u "$mqtt_user" -P "$mqtt_pass")
    mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" "${auth[@]}" -t homelab/proxmox_reserva/estado -m "$status" -r || true
    mosquitto_pub -h "$mqtt_host" -p "$mqtt_port" "${auth[@]}" -t homelab/proxmox_reserva/ultimo -m "$time_now" -r || true
    log "MQTT estado=$status ultimo=$time_now"
  fi

  python3 - "$HA_WEBHOOK_URL" "$HA_WEBHOOK_RESERVA_URL" "$status" "$message" "$time_now" <<'PY' || log "AVISO: webhook HA falhou"
import json, sys, urllib.request
url_dup, url_res, status, message, time_now = sys.argv[1:6]
payload = {
    "job_name": "Proxmox Reserva",
    "job_key": "proxmox_reserva",
    "status": status,
    "message": message[:1500],
    "time": time_now,
    "ok": status == "success",
}
body = json.dumps(payload).encode()
for url in (url_dup, url_res):
    if not url:
        continue
    try:
        req = urllib.request.Request(
            url, data=body, headers={"Content-Type": "application/json"}, method="POST"
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(f"webhook HA {url} HTTP {resp.status}")
    except Exception as exc:
        print(f"webhook HA {url} falhou: {exc}")
PY
}

die() {
  ERROR_MSG="$*"
  log "ERRO: $ERROR_MSG"
  write_status 0
  notify_ha 0
  exit 1
}

ssh_p() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$PRIMARY_SSH" "$@"; }
ssh_r() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$RESERVA_SSH" "$@"; }

wait_reserva_up() {
  local i
  log "à espera da reserva ${RESERVA_IP}…"
  for i in $(seq 1 60); do
    if ping -c1 -W2 "$RESERVA_IP" >/dev/null 2>&1 \
      && curl -sk --connect-timeout 3 -o /dev/null -w '' "https://${RESERVA_IP}:8007/" \
      && ssh_r 'hostname' >/dev/null 2>&1; then
      log "reserva online ($(ssh_r hostname))"
      return 0
    fi
    sleep 10
  done
  die "reserva não ficou online a tempo (ping/PBS/SSH)"
}

check_only() {
  log "=== check ==="
  ssh_p 'hostname; qm list; pvesm status | grep -E "pbs-reserva|Name"'
  echo "---"
  ssh_r 'hostname; qm list; pvesm status | grep -E "pbs-local|Name"; for v in 100 101; do echo -n "VM$v onboot="; qm config $v | awk -F": " "/^onboot/{print \$2}" ; done'
  log "check OK"
}

run_backup() {
  log "=== backup → ${PBS_STORAGE_PRIMARY} ==="
  ssh_p "bash -s" <<EOS
set -euo pipefail
mkdir -p ${LOG_DIR_REMOTE}
LOG=${LOG_DIR_REMOTE}/pbs-rotina-backup-${STAMP}.log
ln -sfn "\$LOG" ${LOG_DIR_REMOTE}/pbs-rotina-backup-latest.log
echo "=== backup start \$(date -Is) ===" | tee -a "\$LOG"
vzdump ${VMIDS[*]} \\
  --storage ${PBS_STORAGE_PRIMARY} \\
  --mode snapshot \\
  --mailto '' \\
  --notes-template '${NOTES_TEMPLATE}' \\
  2>&1 | tee -a "\$LOG"
echo "=== backup end \$(date -Is) ===" | tee -a "\$LOG"
# Prune (mantém as últimas N versões por VM)
if pvesm prune-backups ${PBS_STORAGE_PRIMARY} --keep-last ${KEEP_LAST} --dry-run 2>/dev/null | head -5; then
  pvesm prune-backups ${PBS_STORAGE_PRIMARY} --keep-last ${KEEP_LAST} 2>&1 | tee -a "\$LOG" || true
fi
pvesm list ${PBS_STORAGE_PRIMARY}
EOS

  # Captura volids mais recentes
  local list
  list="$(ssh_p "pvesm list ${PBS_STORAGE_PRIMARY}")"
  BACKUP_101="$(printf '%s\n' "$list" | awk '$1 ~ /\/vm\/101\// {print $1}' | sort | tail -1)"
  BACKUP_100="$(printf '%s\n' "$list" | awk '$1 ~ /\/vm\/100\// {print $1}' | sort | tail -1)"
  [[ -n "$BACKUP_101" && -n "$BACKUP_100" ]] || die "não encontrei backups 100/101 após vzdump"
  log "backup 101: $BACKUP_101"
  log "backup 100: $BACKUP_100"
}

# Converte volid do principal (pbs-reserva:backup/vm/…) → volid na reserva (pbs-local:backup/vm/…)
volid_on_reserva() {
  local primary_volid="$1"
  local path="${primary_volid#*:}" # backup/vm/…
  echo "${PBS_STORAGE_RESERVA}:${path}"
}

run_restore() {
  log "=== restore na reserva (VMs ficam paradas) ==="
  local v101 v100
  if [[ -z "$BACKUP_101" || -z "$BACKUP_100" ]]; then
    local list
    list="$(ssh_p "pvesm list ${PBS_STORAGE_PRIMARY}")"
    BACKUP_101="$(printf '%s\n' "$list" | awk '$1 ~ /\/vm\/101\// {print $1}' | sort | tail -1)"
    BACKUP_100="$(printf '%s\n' "$list" | awk '$1 ~ /\/vm\/100\// {print $1}' | sort | tail -1)"
  fi
  [[ -n "$BACKUP_101" && -n "$BACKUP_100" ]] || die "sem volids de backup para restaurar"
  v101="$(volid_on_reserva "$BACKUP_101")"
  v100="$(volid_on_reserva "$BACKUP_100")"

  ssh_r "bash -s" <<EOS
set -euo pipefail
mkdir -p ${LOG_DIR_REMOTE}
LOG=${LOG_DIR_REMOTE}/pbs-rotina-restore-${STAMP}.log
ln -sfn "\$LOG" ${LOG_DIR_REMOTE}/pbs-rotina-restore-latest.log
echo "=== restore start \$(date -Is) ===" | tee -a "\$LOG"

for vmid in 101 100; do
  if qm status "\$vmid" >/dev/null 2>&1; then
    state=\$(qm status "\$vmid" | awk '{print \$2}')
    if [[ "\$state" != "stopped" ]]; then
      echo "a parar VM \$vmid (\$state)" | tee -a "\$LOG"
      qm stop "\$vmid" --timeout 120 || qm stop "\$vmid" --skiplock || true
    fi
  fi
done

echo "=== restore 101 from ${v101} ===" | tee -a "\$LOG"
qmrestore "${v101}" 101 --storage local-lvm --force 1 --start 0 2>&1 | tee -a "\$LOG"
echo "=== restore 100 from ${v100} ===" | tee -a "\$LOG"
qmrestore "${v100}" 100 --storage local-lvm --force 1 --start 0 2>&1 | tee -a "\$LOG"

for vmid in 100 101; do
  qm set "\$vmid" --onboot 0
  state=\$(qm status "\$vmid" | awk '{print \$2}')
  echo "VM \$vmid state=\$state onboot=\$(qm config \$vmid | awk -F': ' '/^onboot/{print \$2}')" | tee -a "\$LOG"
  [[ "\$state" == "stopped" ]] || { echo "VM \$vmid não está stopped" >&2; exit 1; }
done

echo "=== restore end \$(date -Is) ===" | tee -a "\$LOG"
qm list | tee -a "\$LOG"
EOS
  log "restore OK — VMs 100/101 paradas, onboot=0"
}

shutdown_reserva() {
  log "a desligar a reserva (shutdown -h now)…"
  ssh_r 'shutdown -h now' || true
  local i
  for i in $(seq 1 36); do
    if ! ping -c1 -W2 "$RESERVA_IP" >/dev/null 2>&1; then
      log "reserva offline (pode cortar a tomada)"
      return 0
    fi
    sleep 5
  done
  log "AVISO: reserva ainda responde ao ping após shutdown"
}

# --- main ---
log "rotina semanal início"

if [[ "$SHUTDOWN_ONLY" -eq 1 ]]; then
  if ! ping -c1 -W2 "$RESERVA_IP" >/dev/null 2>&1; then
    log "reserva já offline — nada a desligar"
    exit 0
  fi
  shutdown_reserva
  exit 0
fi

wait_reserva_up

if [[ "$DO_CHECK" -eq 1 ]]; then
  check_only
  RESULT_OK=1
  write_status 1
  # check não notifica o HA (só validação)
  exit 0
fi

ssh_p "pvesm status | grep -q '${PBS_STORAGE_PRIMARY}.*active'" \
  || die "storage ${PBS_STORAGE_PRIMARY} inativo no principal"

[[ "$DO_BACKUP" -eq 1 ]] && run_backup
[[ "$DO_RESTORE" -eq 1 ]] && run_restore

RESULT_OK=1
write_status 1
notify_ha 1
log "rotina semanal OK"

[[ "$DO_SHUTDOWN" -eq 1 ]] && shutdown_reserva
exit 0
