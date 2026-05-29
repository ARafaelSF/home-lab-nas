#!/usr/bin/env bash
# container-ops — backup, update, rollback e prune de stacks Docker Compose
set -euo pipefail

OPS_ROOT="/opt/container-ops"
APPS_CONF="${OPS_ROOT}/apps.conf"
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
  IFS='|' read -r APP_NAME APP_STACK_DIR APP_SERVICE APP_TAG_KEY APP_VOLUMES_CSV APP_PROJECT <<<"$line"
  APP_PROJECT="${APP_PROJECT:-}"
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

verify_stack() {
  [[ -d "$APP_STACK_DIR" ]] || die "stack_dir inexistente: $APP_STACK_DIR"
  [[ -f "$APP_COMPOSE_FILE" ]] || die "compose inexistente: $APP_COMPOSE_FILE"
  if [[ ! -f "$APP_ENV_FILE" ]]; then
    log "AVISO: .env não existe; será criado em ${APP_ENV_FILE}"
    touch "$APP_ENV_FILE"
    chmod 600 "$APP_ENV_FILE"
  fi
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

cmd_update() {
  local app="${1:?app}"
  local new_tag="${2:?nova_tag}"
  load_app "$app"
  verify_stack
  log "=== update: ${APP_NAME} → tag ${new_tag} ==="
  log "Backup automático antes do update..."
  cmd_backup "$app"
  set_env_tag "$new_tag"
  log "Pull ${APP_SERVICE}..."
  if ! compose pull "$APP_SERVICE"; then
    die "pull falhou — backups preservados em ${APP_BACKUP_DIR}"
  fi
  log "Up -d ${APP_SERVICE}..."
  if ! compose up -d "$APP_SERVICE"; then
    die "up falhou — backups preservados em ${APP_BACKUP_DIR}"
  fi
  sleep 3
  if ! validate_service; then
    die "validação falhou — backups preservados em ${APP_BACKUP_DIR}"
  fi
  log "Update concluído com sucesso."
  prune_backups 1
}

cmd_rollback() {
  local app="${1:?app}"
  local old_tag="${2:?tag_antiga}"
  load_app "$app"
  verify_stack
  log "=== rollback: ${APP_NAME} → tag ${old_tag} ==="
  set_env_tag "$old_tag"
  compose pull "$APP_SERVICE"
  compose up -d "$APP_SERVICE"
  sleep 3
  validate_service
  log "Rollback concluído."
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
    IFS='|' read -r name dir svc key vols proj <<<"$line"
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
  echo "  /opt/container-ops/ops.sh backup <app>        # ex.: mealie, jellyfin, immich"
  echo "  /opt/container-ops/ops.sh update <app> <tag>  # ex.: update jellyfin latest"
  echo "  /opt/container-ops/ops.sh backup-all          # backup de todas as apps"
  echo "  cat /opt/container-ops/GUIA.md                # guia em português"
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
  update <app> <nova_tag>   Backup + update tag + validação + prune (keep=1)
  rollback <app> <tag>      Reverte tag e recria container
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
    prune)      cmd_prune "$@" ;;
    -h|--help|help|"") usage ;;
    *) die "Comando desconhecido: ${cmd}. Use: list|backup|update|rollback|prune" ;;
  esac
}

main "$@"
