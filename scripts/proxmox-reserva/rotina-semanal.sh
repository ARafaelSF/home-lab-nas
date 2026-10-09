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

# Evita "unexpected EOF" se alguém editar este ficheiro enquanto a rotina corre:
# o bash relê o .sh do disco; executar a partir de uma cópia fixa em /tmp.
if [[ "${PBS_ROTINA_SELF_COPY:-}" != "1" ]]; then
  _real_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _copy="$(mktemp /tmp/rotina-semanal.XXXXXX.sh)"
  cp -a -- "$0" "$_copy"
  chmod 700 "$_copy"
  # parse-progress.py e afins ficam no repo; a cópia em /tmp só é o bash.
  export PBS_ROTINA_SELF_COPY=1
  export PBS_ROTINA_SCRIPT_DIR="$_real_dir"
  exec bash "$_copy" "$@"
fi

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
HA_SHUTDOWN_RESERVA_URL="${HA_SHUTDOWN_RESERVA_URL:-}"
SHUTDOWN_REQUEST_ID="${SHUTDOWN_REQUEST_ID:-}"
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
    --shutdown-only) SHUTDOWN_ONLY=1; DO_BACKUP=0; DO_RESTORE=0; DO_CHECK=0; DO_SHUTDOWN=1 ;;
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

SCRIPT_DIR="${PBS_ROTINA_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PROGRESS_ACTIVE="${STATUS_LOCAL_DIR}/pbs-rotina-progress.active"
PROGRESS_PID=""

mqtt_auth_args() {
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
  MQTT_HOST="$mqtt_host"
  MQTT_PORT="$mqtt_port"
  MQTT_AUTH=()
  [[ -n "$mqtt_user" ]] && MQTT_AUTH+=(-u "$mqtt_user" -P "$mqtt_pass")
}

mqtt_pub() {
  local topic="$1" message="$2"
  command -v mosquitto_pub >/dev/null 2>&1 || return 0
  mqtt_auth_args
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" "${MQTT_AUTH[@]}" -t "$topic" -m "$message" || true
}

publish_progress_from_log() {
  local line phase phase_pct overall
  line="$(python3 "${SCRIPT_DIR}/parse-progress.py" "$LOG_LOCAL" 2>/dev/null || echo 'inicio|0|0')"
  IFS='|' read -r phase phase_pct overall <<<"$line"
  mqtt_pub homelab/proxmox_reserva/fase "$phase"
  mqtt_pub homelab/proxmox_reserva/progresso "$overall"
}

progress_loop() {
  while [[ -f "$PROGRESS_ACTIVE" ]]; do
    publish_progress_from_log
    sleep 45
  done
}

start_progress_loop() {
  : >"$PROGRESS_ACTIVE"
  publish_progress_from_log
  progress_loop &
  PROGRESS_PID=$!
}

stop_progress_loop() {
  rm -f "$PROGRESS_ACTIVE"
  if [[ -n "$PROGRESS_PID" ]]; then
    kill "$PROGRESS_PID" 2>/dev/null || true
    wait "$PROGRESS_PID" 2>/dev/null || true
    PROGRESS_PID=""
  fi
  publish_progress_from_log
}

mkdir -p "$STATUS_LOCAL_DIR"
LOCK_FILE="/run/lock/homelab-pbs-rotina-semanal.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "ERRO: já existe uma rotina semanal em execução (lock: $LOCK_FILE)" >&2
  exit 75
fi
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
  mqtt_pub homelab/proxmox_reserva/estado "$status"
  mqtt_pub homelab/proxmox_reserva/ultimo "$time_now"
  if [[ "$status" == "success" ]]; then
    mqtt_pub homelab/proxmox_reserva/progresso "100"
    mqtt_pub homelab/proxmox_reserva/fase "concluido"
  fi
  log "MQTT estado=$status ultimo=$time_now"

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
  stop_progress_loop
  mqtt_pub homelab/proxmox_reserva/fase "erro"
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

assert_reserva_safe_for_restore() {
  log "preflight obrigatório antes do restore"
  if [[ ! -x "${SCRIPT_DIR}/prepare-reserva.sh" ]]; then
    die "preflight ausente ou sem permissão de execução: ${SCRIPT_DIR}/prepare-reserva.sh"
  fi
  PRIMARY_SSH="$PRIMARY_SSH" RESERVA_SSH="$RESERVA_SSH" ALLOW_REBUILD=1 \
    PBS_PRIMARY="$PBS_STORAGE_PRIMARY" PBS_RESERVA="$PBS_STORAGE_RESERVA" \
    "${SCRIPT_DIR}/prepare-reserva.sh" || die "preflight da reserva falhou; restore bloqueado"
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

precheck_vm() {
  local vmid="\$1" cfg
  if qm status "\$vmid" >/dev/null 2>&1; then
    cfg="\$(qm config "\$vmid" 2>/dev/null || true)"
    if grep -q '^lock:' <<<"\$cfg"; then
      echo "ERRO precheck VM \$vmid: lock existente (\$(grep '^lock:' <<<"\$cfg"))" | tee -a "\$LOG"
      return 75
    fi
  fi
  if pgrep -af "(qmrestore|pbs-restore|vma|qemu-img).*\b\$vmid\b" >/dev/null 2>&1; then
    echo "ERRO precheck VM \$vmid: processo de restauração já ativo" | tee -a "\$LOG"
    return 75
  fi
    if [[ "\$(qm status \"\$vmid\" | awk '{print \$2}')" != "stopped" ]]; then
    echo "ERRO precheck VM \$vmid: VM não está stopped" | tee -a "\$LOG"
    return 75
    fi
  fi
}

restore_vm() {
  local vmid="\$1" source="\$2" rc cfg state
  precheck_vm "\$vmid"
  echo "START restore vmid=\$vmid source=\$source" | tee -a "\$LOG"
  set +e
  qmrestore "\$source" "\$vmid" --storage local-lvm --start 0 2>&1 | tee -a "\$LOG"
  rc=\${PIPESTATUS[0]}
  set -e
  if [[ "\$rc" -ne 0 ]]; then
    echo "ERROR restore vmid=\$vmid exit_code=\$rc" | tee -a "\$LOG"
    return "\$rc"
  fi
  cfg=\$(qm config "\$vmid")
  state=\$(qm status "\$vmid" | awk '{print \$2}')
  if grep -q '^lock:' <<<"\$cfg" || [[ "\$state" != "stopped" ]] || ! grep -Eq '^(scsi|sata|virtio|ide|efidisk)[0-9]*:' <<<"\$cfg"; then
    echo "ERROR validate vmid=\$vmid state=\$state lock=\$(grep '^lock:' <<<"\$cfg" || true) disks=\$(grep -Ec '^(scsi|sata|virtio|ide|efidisk)[0-9]*:' <<<"\$cfg")" | tee -a "\$LOG"
    return 1
  fi
  if ! grep -Eq '^net[0-9]+:' <<<"\$cfg" || grep -E '^net[0-9]+:' <<<"\$cfg" | grep -v ',link_down=1' >/dev/null; then
    echo "ERROR validate vmid=\$vmid rede não está isolada com link_down=1 após qmrestore" | tee -a "\$LOG"
    return 1
  fi
  echo "VALIDATE vmid=\$vmid state=stopped lock=none disks=present" | tee -a "\$LOG"
  echo "END restore vmid=\$vmid exit_code=0" | tee -a "\$LOG"
}

restore_vm 101 "${v101}"
restore_vm 100 "${v100}"

for vmid in 100 101; do
  qm set "\$vmid" --onboot 0
  cfg=\$(qm config "\$vmid")
  if grep -q '^lock:' <<<"\$cfg"; then
    echo "VM \$vmid ainda possui lock após restore" | tee -a "\$LOG"
    exit 1
  fi
  grep -Eq '^(scsi|sata|virtio|ide|efidisk)[0-9]*:' <<<"\$cfg" || {
    echo "VM \$vmid sem disco configurado após restore" | tee -a "\$LOG"
    exit 1
  }
  state=\$(qm status "\$vmid" | awk '{print \$2}')
  echo "VM \$vmid state=\$state onboot=\$(qm config \$vmid | awk -F': ' '/^onboot/{print \$2}')" | tee -a "\$LOG"
  [[ "\$state" == "stopped" ]] || { echo "VM \$vmid não está stopped" >&2; exit 1; }
done

echo "=== restore end \$(date -Is) ===" | tee -a "\$LOG"
qm list | tee -a "\$LOG"
EOS
  log "restore OK — VMs 100/101 paradas, onboot=0"
}

validate_shutdown_preflight() {
  ssh_r 'python3 - <<'"'"'PY'"'"'
import json, subprocess, sys
try:
    node = subprocess.check_output(["hostname"], text=True).strip()
    tasks = json.loads(subprocess.check_output(["pvesh", "get", f"/nodes/{node}/tasks", "--output-format", "json"], text=True))
    critical = {"qmrestore", "vzdump", "vma", "pbs-restore"}
    if any(t.get("type") in critical and t.get("status") not in {"OK", "ERROR", "STOPPED", "stopped"} for t in tasks):
        raise SystemExit("critical_task_active")
    vms = json.loads(subprocess.check_output(["qm", "list", "--output-format", "json"], text=True))
    states = {int(vm["vmid"]): vm.get("status") for vm in vms}
    if any(states.get(vmid) != "stopped" for vmid in (100, 101)):
        raise SystemExit("vm_not_stopped")
    if subprocess.run(["pgrep", "-af", "(qmrestore|vzdump|pbs-restore|vma)"], capture_output=True, text=True).stdout.strip():
        raise SystemExit("critical_process_active")
    # Shutdown-only may drain a stopped VM with a historical lock.
    # Backup/restore preflights retain their stricter lock policy elsewhere.
except Exception as exc:
    print(str(exc), file=sys.stderr)
    raise SystemExit(1)
PY'
}

shutdown_reserva() {
  local request_id="${SHUTDOWN_REQUEST_ID:-manual-$(date +%s)}"
  if ! validate_shutdown_preflight; then
    log "shutdown request_id=$request_id status=failed reason=preflight"
    notify_shutdown_event "$request_id" "failed" "Preflight bloqueou o shutdown."
    return 1
  fi
  log "shutdown request_id=$request_id status=shutdown_requested"
  if ! ssh_r 'shutdown -h now'; then
    notify_shutdown_event "$request_id" "failed" "O comando de shutdown gracioso não foi aceito pelo host."
    return 1
  fi
  notify_shutdown_event "$request_id" "shutdown_requested" "Shutdown gracioso aceito; encerramento ainda não confirmado."
  local i
  for i in $(seq 1 36); do
    if ! ping -c1 -W2 "$RESERVA_IP" >/dev/null 2>&1 \
      && ! ssh_r 'true' >/dev/null 2>&1 \
      && ! curl -sk --connect-timeout 2 -o /dev/null "https://${RESERVA_IP}:8006/"; then
      log "shutdown request_id=$request_id status=shutdown_unreachable_first"
      notify_shutdown_event "$request_id" "shutdown_unreachable_first" "O host ficou inacessível; aguardando 120 segundos para confirmar a indisponibilidade."
      sleep 120
      if ping -c1 -W2 "$RESERVA_IP" >/dev/null 2>&1 \
        || ssh_r 'true' >/dev/null 2>&1 \
        || curl -sk --connect-timeout 2 -o /dev/null "https://${RESERVA_IP}:8006/"; then
        log "shutdown request_id=$request_id status=unknown host voltou a responder"
        notify_shutdown_event "$request_id" "unknown" "O host voltou a responder durante a janela de confirmação; corte não autorizado."
        return 1
      fi
      log "shutdown request_id=$request_id status=shutdown_unreachable_stable"
      notify_shutdown_event "$request_id" "shutdown_unreachable_stable" "O host permaneceu inacessível após a janela adicional de 120 segundos; confirmação operacional de indisponibilidade."
      return 0
    fi
    sleep 5
  done
  log "shutdown request_id=$request_id status=unknown host_ainda_acessivel"
  notify_shutdown_event "$request_id" "unknown" "O host não ficou inacessível dentro da janela; não há confirmação de encerramento."
  return 1
}

notify_shutdown_event() {
  local request_id="$1" status="$2" message="$3" now
  now="$(date -Is)"
  log "shutdown_event request_id=$request_id observed_at=$now status=$status"
  [[ -z "$HA_SHUTDOWN_RESERVA_URL" ]] && return 0
  python3 - "$HA_SHUTDOWN_RESERVA_URL" "$request_id" "${STARTED_AT:-$now}" "$now" "$status" "$message" <<'PY' || log "AVISO: webhook shutdown reserva falhou"
import json, sys, urllib.request
url, request_id, started, observed, status, message = sys.argv[1:]
payload = {"source": "homelab-proxmox-reserva", "request_id": request_id, "started_at": started, "observed_at": observed, "status": status, "message": message[:1500]}
req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"}, method="POST")
with urllib.request.urlopen(req, timeout=20) as response:
    print(f"shutdown webhook HTTP {response.status}")
PY
}

trap 'stop_progress_loop' EXIT

# --- main ---
log "rotina semanal início"
start_progress_loop

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
if [[ "$DO_RESTORE" -eq 1 ]]; then
  assert_reserva_safe_for_restore
  run_restore
fi

RESULT_OK=1
stop_progress_loop
write_status 1
notify_ha 1
log "rotina semanal OK"

[[ "$DO_SHUTDOWN" -eq 1 ]] && shutdown_reserva
exit 0
