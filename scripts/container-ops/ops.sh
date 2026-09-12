#!/usr/bin/env bash
# container-ops — backup, update, rollback e prune de stacks Docker Compose
set -euo pipefail

# Código = este diretório (git). Dados/segredos = /opt/container-ops (fora do git).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_ROOT="${CONTAINER_OPS_DATA:-/opt/container-ops}"
APPS_CONF="${CONTAINER_OPS_APPS:-${SCRIPT_DIR}/apps.conf}"
BACKUP_ROOT="${OPS_ROOT}/backups"
TIMESTAMP="$(date +%Y-%m-%d_%H%M%S)"

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  {
  log "ERRO: $*"
  if [[ "${CONTAINER_OPS_LENIENT:-0}" -eq 1 ]]; then
    return 1
  fi
  exit 1
}

require_cmds() {
  local missing=0
  for cmd in docker tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log "Comando em falta: $cmd"
      missing=1
    fi
  done
  if ! docker compose version >/dev/null 2>&1; then
    log "Comando em falta: docker compose"
    missing=1
  fi
  if [[ "$missing" -ne 0 ]]; then
    die "Instale as dependências acima e tente novamente."
  fi
}

load_app() {
  local app="$1"
  [[ -f "$APPS_CONF" ]] || die "Ficheiro não encontrado: $APPS_CONF"
  local line
  line="$(grep -E "^[^#].*\|" "$APPS_CONF" | grep -E "^${app}\|" || true)"
  [[ -n "$line" ]] || die "App '${app}' não cadastrada em ${APPS_CONF}"
  IFS='|' read -r APP_NAME APP_STACK_DIR APP_SERVICE APP_TAG_KEY APP_VOLUMES_CSV APP_PROJECT APP_WUD_NAME <<<"$line"
  APP_PROJECT="${APP_PROJECT:-}"
  APP_WUD_NAME="${APP_WUD_NAME:-}"
  APP_BACKUP_DIR="${BACKUP_ROOT}/${APP_NAME}"
  APP_COMPOSE_FILE="${APP_STACK_DIR}/docker-compose.yml"
  APP_ENV_FILE="${APP_STACK_DIR}/.env"
}

volumes_array() {
  IFS=',' read -ra APP_VOLUMES <<<"$APP_VOLUMES_CSV"
  for i in "${!APP_VOLUMES[@]}"; do
    APP_VOLUMES[$i]="$(echo "${APP_VOLUMES[$i]}" | xargs)"
  done
}

verify_required_env() {
  case "$APP_NAME" in
    duplicati)
      if ! grep -qE '^SETTINGS_ENCRYPTION_KEY=.+' "$APP_ENV_FILE" 2>/dev/null; then
        die "SETTINGS_ENCRYPTION_KEY em falta em ${APP_ENV_FILE}. Copie de /var/lib/docker/volumes/portainer_data/_data/compose/25/.env antes de update."
      fi
      if ! grep -qE '^DUPLICATI_WEBSERVICE_PASSWORD=.+' "$APP_ENV_FILE" 2>/dev/null; then
        die "DUPLICATI_WEBSERVICE_PASSWORD em falta em ${APP_ENV_FILE}. Copie de .../compose/25/.env antes de update."
      fi
      ;;
  esac
}

verify_stack() {
  [[ -d "$APP_STACK_DIR" ]] || die "stack_dir inexistente: $APP_STACK_DIR"
  [[ -f "$APP_COMPOSE_FILE" ]] || die "compose inexistente: $APP_COMPOSE_FILE"
  if [[ ! -f "$APP_ENV_FILE" ]]; then
    log "AVISO: .env não existe; será criado em ${APP_ENV_FILE}"
    touch "$APP_ENV_FILE"
    chmod 600 "$APP_ENV_FILE"
  fi
  verify_required_env
  # Bind-mounts de ficheiro: Docker cria um directório se o ficheiro sumir — evita loop de restart.
  case "$APP_NAME" in
    dozzle)
      local users_yml="${APP_STACK_DIR}/users.yml"
      if [[ -d "$users_yml" ]]; then
        die "dozzle: ${users_yml} é um directório (ficheiro de auth em falta). Restaura users.yml antes de actualizar."
      fi
      [[ -f "$users_yml" ]] || die "dozzle: ficheiro em falta: ${users_yml}"
      ;;
    adguard)
      local conf_yaml="/var/lib/docker/volumes/adguard-home_adguard_conf/_data/AdGuardHome.yaml"
      if [[ ! -f "$conf_yaml" ]]; then
        die "adguard: ${conf_yaml} em falta — DNS ficaria em modo instalação. Restaura o YAML antes de actualizar."
      fi
      ;;
  esac
}

compose() {
  local -a cmd=(docker compose -f "$APP_COMPOSE_FILE" --env-file "$APP_ENV_FILE")
  [[ -n "$APP_PROJECT" ]] && cmd+=(-p "$APP_PROJECT")
  "${cmd[@]}" "$@"
}

set_env_tag() {
  local tag="$1"
  local key="${APP_TAG_KEY}"
  local file="$APP_ENV_FILE"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${tag}|" "$file"
  else
    echo "${key}=${tag}" >>"$file"
  fi
  chmod 600 "$file"
  log "ENV: ${key}=${tag} em ${file}"
}

get_env_tag() {
  grep -E "^${APP_TAG_KEY}=" "$APP_ENV_FILE" 2>/dev/null | cut -d= -f2- || echo ""
}

backup_one_volume() {
  local vol="$1"
  docker volume inspect "$vol" >/dev/null 2>&1 || die "Volume Docker não encontrado: $vol"
  mkdir -p "$APP_BACKUP_DIR"
  local outfile="${APP_BACKUP_DIR}/${APP_NAME}_${vol}_${TIMESTAMP}.tgz"
  log "Backup volume '${vol}' → ${outfile}"
  docker run --rm \
    -v "${vol}:/volume:ro" \
    -v "${APP_BACKUP_DIR}:/backup" \
    alpine:3.20 \
    tar -czf "/backup/$(basename "$outfile")" -C /volume .
  log "OK: $(du -h "$outfile" | awk '{print $1}') $(basename "$outfile")"
}

cmd_backup() {
  local app="${1:?app}"
  load_app "$app"
  verify_stack
  volumes_array
  log "=== backup: ${APP_NAME} ==="
  local backed=0
  for vol in "${APP_VOLUMES[@]}"; do
    [[ -n "$vol" ]] || continue
    backup_one_volume "$vol"
    backed=1
  done
  if [[ "$backed" -eq 0 ]]; then
    log "AVISO: nenhum volume configurado — backup de dados ignorado."
  else
    log "Backups em: ${APP_BACKUP_DIR}"
  fi
}

prune_backups() {
  local keep="${1:-1}"
  [[ "$keep" =~ ^[0-9]+$ ]] || die "keep deve ser número inteiro >= 1"
  volumes_array
  log "=== prune: ${APP_NAME} (manter ${keep} por volume) ==="
  [[ -d "$APP_BACKUP_DIR" ]] || { log "Sem pasta de backups."; return 0; }

  for vol in "${APP_VOLUMES[@]}"; do
    [[ -n "$vol" ]] || continue
    local pattern="${APP_BACKUP_DIR}/${APP_NAME}_${vol}_"*.tgz
    local -a files=()
    shopt -s nullglob
    files=($pattern)
    shopt -u nullglob
    local count="${#files[@]}"
    if [[ "$count" -le 1 ]]; then
      log "Volume ${vol}: ${count} backup(s) — nada a remover"
      continue
    fi
    if [[ "$count" -le "$keep" ]]; then
      log "Volume ${vol}: ${count} backup(s) <= keep=${keep} — nada a remover"
      continue
    fi
    local -a sorted=()
    mapfile -t sorted < <(ls -1t "${files[@]}")
    local i
    for ((i = keep; i < ${#sorted[@]}; i++)); do
      log "Remover: $(basename "${sorted[$i]}")"
      rm -f "${sorted[$i]}"
    done
    log "Volume ${vol}: mantidos ${keep}, removidos $((count - keep))"
  done
}

validate_service() {
  local cid
  cid="$(compose ps -q "$APP_SERVICE" 2>/dev/null || true)"
  [[ -n "$cid" ]] || die "Container do serviço '${APP_SERVICE}' não está em execução"
  local state image
  state="$(docker inspect -f '{{.State.Status}}' "$cid")"
  image="$(docker inspect -f '{{.Config.Image}}' "$cid")"
  [[ "$state" == "running" ]] || die "Serviço '${APP_SERVICE}' em estado: ${state}"
  log "Validação OK: ${APP_SERVICE} running"
  log "Imagem em uso: ${image}"
}

# Rótulo legível para Telegram/HA: "08/09 14:39 (a70b7bf7)"
# Usa Created do container + RepoDigest (comparável entre FROM e TO).
version_label_from_cid() {
  local cid="${1:-}"
  if [[ -z "$cid" ]]; then
    echo "?"
    return 0
  fi
  CID="$cid" python3 - <<'PY'
import json, os, subprocess, datetime

cid = os.environ["CID"]
try:
    created_s, image_id = subprocess.check_output(
        ["docker", "inspect", cid, "--format", "{{.Created}} {{.Image}}"],
        text=True,
    ).strip().split(" ", 1)
    created = datetime.datetime.fromisoformat(created_s.replace("Z", "+00:00"))
    stamp = created.astimezone().strftime("%d/%m %H:%M")
    digest = ""
    digests = json.loads(
        subprocess.check_output(
            ["docker", "image", "inspect", image_id, "--format", "{{json .RepoDigests}}"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        or "[]"
    )
    for row in digests:
        if "@sha256:" in row:
            digest = row.split("@sha256:", 1)[1][:8]
            break
    if not digest:
        digest = image_id[7:15] if image_id.startswith("sha256:") else image_id[:8]
    print(f"{stamp} ({digest})")
except Exception:
    print("?")
PY
}

report_version() {
  local kind="$1" # FROM | TO
  local cid label
  cid="$(compose ps -q "$APP_SERVICE" 2>/dev/null || true)"
  label="$(version_label_from_cid "$cid")"
  log "VERSION_${kind}=${APP_NAME}|${label}"
}

resolve_wud_name() {
  if [[ -n "${APP_WUD_NAME:-}" ]]; then
    echo "$APP_WUD_NAME"
    return
  fi
  case "$APP_NAME" in
    npm) echo "nginx-proxy-manager" ;;
    cloudflare) echo "cloudflared" ;;
    immich) echo "immich_server" ;;
    immich-ml) echo "immich_machine_learning" ;;
    adguard) echo "adguardhome" ;;
    uptime-kuma) echo "uptime-kuma" ;;
    *) echo "${APP_SERVICE//-/_}" ;;
  esac
}

wud_get_container_id() {
  local wud_name="$1"
  docker exec wud curl -sf http://127.0.0.1:3000/api/containers 2>/dev/null \
    | WUD_NAME="$wud_name" python3 -c "
import json, os, sys
name = os.environ['WUD_NAME']
for c in json.load(sys.stdin):
    if c['name'] == name:
        print(c['id'])
        break
" || true
}

wud_refresh_ha() {
  local scope="${1:-app}"

  if [[ "${CONTAINER_OPS_SKIP_WUD:-0}" -eq 1 ]]; then
    log "WUD refresh ignorado (CONTAINER_OPS_SKIP_WUD=1)"
    return 0
  fi

  if ! docker inspect wud >/dev/null 2>&1; then
    log "AVISO: container 'wud' não encontrado — sensores HA não actualizados"
    return 0
  fi

  if [[ "$scope" == "all" ]]; then
    log "WUD: scan completo (actualizar todos os sensores HA)..."
    if docker exec wud curl -sf -X POST http://127.0.0.1:3000/api/containers/watch >/dev/null; then
      log "WUD: sensores HA actualizados."
    else
      log "AVISO: scan WUD falhou"
      return 1
    fi
    return 0
  fi

  local wud_name cid
  wud_name="$(resolve_wud_name)"
  cid="$(wud_get_container_id "$wud_name")"

  if [[ -z "$cid" ]]; then
    log "AVISO: '${wud_name}' não encontrado no WUD — scan completo..."
    wud_refresh_ha all
    return 0
  fi

  log "WUD: actualizar sensor HA (${wud_name})..."
  if docker exec wud curl -sf -X POST "http://127.0.0.1:3000/api/containers/${cid}/watch" >/dev/null; then
    log "WUD: sensor HA actualizado."
  else
    log "AVISO: refresh individual falhou — tentando scan completo..."
    wud_refresh_ha all
  fi
}

cmd_refresh_ha() {
  if [[ $# -eq 0 ]]; then
    require_cmds
    wud_refresh_ha all
    return
  fi
  load_app "$1"
  wud_refresh_ha app
}

# Tag de tracking habitual por app (usada em `update all`).
default_update_tag() {
  case "$1" in
    immich|immich-ml) echo "release" ;;
    uptime-kuma) echo "2" ;;
    influx) echo "2.7" ;;
    *) echo "latest" ;;
  esac
}

cmd_update() {
  local app="${1:?app}"

  if [[ "$app" == "all" || "$app" == "pending" ]]; then
    cmd_update_all
    return
  fi
  if [[ "$app" == "catalog" || "$app" == "everything" ]]; then
    cmd_update_catalog
    return
  fi

  local new_tag="${2:-}"
  if [[ -z "$new_tag" ]]; then
    new_tag="$(default_update_tag "$app")"
    log "Tag omitida — a usar a habitual: ${new_tag}"
  fi
  load_app "$app"
  verify_stack
  log "=== update: ${APP_NAME} → tag ${new_tag} ==="
  report_version FROM
  log "Backup automático antes do update..."
  cmd_backup "$app"
  set_env_tag "$new_tag"
  log "Pull ${APP_SERVICE}..."
  if ! compose pull "$APP_SERVICE"; then
    die "pull falhou — backups preservados em ${APP_BACKUP_DIR}" || return 1
  fi
  log "Up -d ${APP_SERVICE} (force-recreate para aplicar digest novo em tags latest)..."
  if ! compose up -d --force-recreate --no-deps "$APP_SERVICE"; then
    die "up falhou — backups preservados em ${APP_BACKUP_DIR}" || return 1
  fi
  sleep 3
  if ! validate_service; then
    die "validação falhou — backups preservados em ${APP_BACKUP_DIR}" || return 1
  fi
  report_version TO
  log "UPDATED_APPS=${APP_NAME}"
  log "Update concluído com sucesso."
  prune_backups 1
  wud_refresh_ha app
}

# Mapa WUD container name → app ops.sh (coluna 7 de apps.conf ou resolve_wud_name).
wud_name_to_app() {
  local wud_name="$1" line name svc wud resolved
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    IFS='|' read -r name _ svc _ _ _ wud <<<"$line"
    wud="${wud:-}"
    if [[ -n "$wud" && "$wud" == "$wud_name" ]]; then
      echo "$name"
      return 0
    fi
    # fallback: mesmo algoritmo de resolve_wud_name
    case "$name" in
      npm) resolved="nginx-proxy-manager" ;;
      cloudflare) resolved="cloudflared" ;;
      immich) resolved="immich_server" ;;
      immich-ml) resolved="immich_machine_learning" ;;
      adguard) resolved="adguardhome" ;;
      uptime-kuma) resolved="uptime-kuma" ;;
      *) resolved="${svc//-/_}" ;;
    esac
    # WUD usa hífen ou underscore conforme o container_name
    if [[ "$resolved" == "$wud_name" || "${svc}" == "$wud_name" || "${svc//_/-}" == "$wud_name" || "${svc//-/_}" == "$wud_name" ]]; then
      echo "$name"
      return 0
    fi
  done <"$APPS_CONF"
  return 1
}

# Apps com updateAvailable=true no WUD (igual à lista pendente do HA).
list_pending_apps() {
  local raw names app
  if ! docker inspect wud >/dev/null 2>&1; then
    die "container 'wud' não encontrado — não consigo listar pendentes"
  fi
  raw="$(docker exec wud curl -sf http://127.0.0.1:3000/api/containers 2>/dev/null || true)"
  [[ -n "$raw" ]] || die "WUD API sem resposta"
  mapfile -t names < <(printf '%s' "$raw" | python3 -c "
import json, sys
for c in json.load(sys.stdin):
    if c.get('updateAvailable'):
        print(c.get('name') or '')
")
  local -a apps=()
  local seen="|"
  for wud_name in "${names[@]}"; do
    [[ -n "$wud_name" ]] || continue
    if ! app="$(wud_name_to_app "$wud_name")"; then
      log "AVISO: pendente WUD '${wud_name}' sem app no apps.conf — ignorado"
      continue
    fi
    if [[ "$seen" != *"|${app}|"* ]]; then
      apps+=("$app")
      seen+="${app}|"
    fi
  done
  if ((${#apps[@]})); then
    printf '%s\n' "${apps[@]}"
  fi
}

# Actualiza só apps com update pendente no WUD/HA (não o catálogo inteiro).
# Continua se uma falhar; no fim faz um único refresh WUD→HA.
cmd_update_all() {
  local name tag failed=0 ok=0
  local -a pending_apps=() updated_apps=() failed_apps=()
  log "=== update all = só pendentes WUD/HA ==="
  mapfile -t pending_apps < <(list_pending_apps)
  if ((${#pending_apps[@]} == 0)); then
    log "Nenhum container pendente no WUD — nada a actualizar."
    wud_refresh_ha all || true
    return 0
  fi
  log "Pendentes: ${pending_apps[*]}"
  log "Immich/ML → release | Uptime Kuma → 2 | Influx → 2.7 | restantes → latest"
  export CONTAINER_OPS_LENIENT=1
  export CONTAINER_OPS_SKIP_WUD=1
  for name in "${pending_apps[@]}"; do
    [[ -n "$name" ]] || continue
    tag="$(default_update_tag "$name")"
    log "---------- ${name} → ${tag} ----------"
    if cmd_update "$name" "$tag"; then
      log "OK: ${name}"
      ok=$((ok + 1))
      updated_apps+=("$name")
    else
      log "FALHOU: ${name} (seguindo para a seguinte)"
      failed=1
      failed_apps+=("$name")
    fi
  done
  unset CONTAINER_OPS_LENIENT
  unset CONTAINER_OPS_SKIP_WUD
  if ((${#updated_apps[@]})); then
    log "UPDATED_APPS=${updated_apps[*]}"
  fi
  if ((${#failed_apps[@]})); then
    log "FAILED_APPS=${failed_apps[*]}"
  fi
  log "=== update pendentes: ${ok}/${#pending_apps[@]} OK ==="
  wud_refresh_ha all || true
  [[ "$failed" -eq 0 ]] || die "Um ou mais updates falharam (ver logs acima)"
  log "update pendentes concluído."
}

# Actualiza TODAS as apps do apps.conf (ignora estado WUD). Uso manual de emergência.
cmd_update_catalog() {
  local line name tag failed=0 ok=0
  local -a updated_apps=() failed_apps=()
  log "=== update catalog (TODAS as apps cadastradas) ==="
  log "Immich/ML → release | Uptime Kuma → 2 | Influx → 2.7 | restantes → latest"
  export CONTAINER_OPS_LENIENT=1
  export CONTAINER_OPS_SKIP_WUD=1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    IFS='|' read -r name _ <<<"$line"
    tag="$(default_update_tag "$name")"
    log "---------- ${name} → ${tag} ----------"
    if cmd_update "$name" "$tag"; then
      log "OK: ${name}"
      ok=$((ok + 1))
      updated_apps+=("$name")
    else
      log "FALHOU: ${name} (seguindo para a seguinte)"
      failed=1
      failed_apps+=("$name")
    fi
  done <"$APPS_CONF"
  unset CONTAINER_OPS_LENIENT
  unset CONTAINER_OPS_SKIP_WUD
  if ((${#updated_apps[@]})); then
    log "UPDATED_APPS=${updated_apps[*]}"
  fi
  if ((${#failed_apps[@]})); then
    log "FAILED_APPS=${failed_apps[*]}"
  fi
  log "=== update catalog: ${ok} OK ==="
  wud_refresh_ha all || true
  [[ "$failed" -eq 0 ]] || die "Um ou mais updates falharam (ver logs acima)"
  log "update catalog concluído."
}

cmd_rollback() {
  local app="${1:?app}"
  local old_tag="${2:?tag_antiga}"
  load_app "$app"
  verify_stack
  log "=== rollback: ${APP_NAME} → tag ${old_tag} ==="
  set_env_tag "$old_tag"
  compose pull "$APP_SERVICE"
  compose up -d --force-recreate --no-deps "$APP_SERVICE"
  sleep 3
  validate_service
  log "Rollback concluído."
  wud_refresh_ha app
}

cmd_prune() {
  local app="${1:?app}"
  local keep="${2:-1}"
  load_app "$app"
  prune_backups "$keep"
}

cmd_list() {
  require_cmds
  log "=== Apps cadastradas (${APPS_CONF}) ==="
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    IFS='|' read -r name dir svc key vols proj wud <<<"$line"
    printf '  %-14s serviço=%-22s tag=%-18s projeto=%s\n' "$name" "$svc" "$key" "${proj:-auto}"
    printf '  %-14s %s\n' "" "volumes: ${vols:-(nenhum)}"
  done <"$APPS_CONF"

  echo
  log "=== Backups existentes ==="
  if [[ ! -d "$BACKUP_ROOT" ]] || [[ -z "$(ls -A "$BACKUP_ROOT" 2>/dev/null)" ]]; then
    echo "  (nenhum)"
  else
    for app_dir in "$BACKUP_ROOT"/*; do
      [[ -d "$app_dir" ]] || continue
      local count size
      count="$(find "$app_dir" -maxdepth 1 -name '*.tgz' 2>/dev/null | wc -l)"
      size="$(du -sh "$app_dir" 2>/dev/null | awk '{print $1}')"
      printf '  %-12s %s arquivo(s), %s total\n' "$(basename "$app_dir")" "$count" "$size"
    done
  fi

  echo
  echo
  log "=== Comandos úteis ==="
  echo "  /root/homelab/scripts/container-ops/ops.sh backup <app>          # ex.: mealie, jellyfin, immich"
  echo "  /root/homelab/scripts/container-ops/ops.sh update <app> <tag>    # ex.: update hermes latest"
  echo "  /root/homelab/scripts/container-ops/ops.sh update all            # só pendentes WUD/HA"
  echo "  /root/homelab/scripts/container-ops/ops.sh update catalog        # TODAS as apps (emergência)"
  echo "  /root/homelab/scripts/container-ops/ops.sh refresh-ha [app]      # actualizar sensores HA via WUD"
  echo "  /root/homelab/scripts/container-ops/ops.sh backup-all            # backup de todas as apps"
  echo "  cat /root/homelab/scripts/container-ops/GUIA.md  # guia em português"
}

cmd_backup_all() {
  local line name failed=0
  log "=== backup-all ==="
  export CONTAINER_OPS_LENIENT=1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    IFS='|' read -r name _ <<<"$line"
    log "--- ${name} ---"
    if cmd_backup "$name"; then
      log "OK: ${name}"
    else
      log "FALHOU: ${name}"
      failed=1
    fi
  done <"$APPS_CONF"
  unset CONTAINER_OPS_LENIENT
  [[ "$failed" -eq 0 ]] || die "Um ou mais backups falharam (ver logs acima)"
}

usage() {
  cat <<EOF
Uso: $(basename "$0") <comando> [args]

Comandos:
  list                      Lista apps e backups
  backup <app>              Backup dos volumes do app
  backup-all                Backup de todas as apps cadastradas
  update <app> [nova_tag]   Backup + update tag + validação + prune (keep=1) + refresh HA
                            Ex.: update hermes latest
                            Sem tag: usa a habitual (latest / Immich=release / Kuma=2)
  update all                Actualiza só pendentes WUD/HA (o botão do dashboard)
  update catalog            Actualiza TODAS as apps do apps.conf (emergência)
  rollback <app> <tag>      Reverte tag e recria container + refresh HA
  refresh-ha [app]          Força WUD a republicar sensores no Home Assistant
  prune <app> [keep]        Remove backups antigos (padrão keep=1)

Config: ${APPS_CONF}
Backups: ${BACKUP_ROOT}/<app>/
EOF
}

main() {
  require_cmds
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    list)    cmd_list ;;
    backup)     cmd_backup "$@" || die "Backup falhou para ${1:-?}" ;;
    backup-all) cmd_backup_all ;;
    update)     cmd_update "$@" ;;
    rollback)   cmd_rollback "$@" ;;
    refresh-ha) cmd_refresh_ha "$@" ;;
    prune)      cmd_prune "$@" ;;
    -h|--help|help|"") usage ;;
    *) die "Comando desconhecido: ${cmd}. Use: list|backup|update|rollback|refresh-ha|prune" ;;
  esac
}

main "$@"
