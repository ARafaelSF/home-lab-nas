# Duplicati — backup completo do homelab

Visão geral dos **dois jobs** (local + OneDrive), retenção e FAQ: **`docs/DUPLICATI-ONEDRIVE.md`** (secção «Estratégia completa»).

## Job `docker-local`

| Fonte no container | Conteúdo no host |
|--------------------|------------------|
| `/source/docker_data/` | Todos os volumes Docker nomeados |
| `/source/media/` | Biblioteca Jellyfin (`/media`) |
| `/source/homelab/` | Repo local (`/root/homelab`) — composes, scripts, docs |
| `/source/host/docker/` | `daemon.json`, firewall, configs WUD |
| `/source/host/network/` | Scripts de rede (`route-lan68`, etc.) |

**Destino:** SSD `/mnt/ssd-backup` (disco `sdb`, separado do SO).

**Agendamento:** diário às 02:00.

**Retenção:** `1W:1D,4W:1W,12M:1M` — ver explicação em `DUPLICATI-ONEDRIVE.md` (não são cópias completas por dia).

**Volume de config (Portainer stack 25):** `25_duplicati_config` → `/config` no container.

### Avisos «file locked» (normais)

Com Docker a correr, alguns ficheiros ficam bloqueados. O Duplicati **ignora** o ficheiro e continua — não é falha do backup.

| Ficheiro | Motivo | Impacto se faltar no restore |
|----------|--------|------------------------------|
| `metadata.db` | Índice interno do Docker | Nenhum — o Docker recria |
| `sessions.db` / `stats.db` (AdGuard) | Estatísticas/sessões | Só perde histórico de queries |
| `diun.db` | Estado do DIUN | Notificações antigas |
| `portainer.db` / `filebrowser.db` | UI com SQLite aberto | Hooks param o container + `sleep 3`; se ainda falhar, reconfiguras pela UI (composes estão no `homelab/`) |

Filtros de exclusão no job: `metadata.db`, `*/sessions.db`, `*/stats.db`, `*/diun.db`.

## Hooks (antes / depois do backup)

Scripts em `/opt/duplicati-scripts/` (cópia versionada em `homelab/scripts/duplicati-hooks/`).

Cada job deve ter nas **opções avançadas** (texto livre):

```text
--run-script-before=/scripts/pre-backup.sh
--run-script-after=/scripts/post-backup.sh
```

O `post-backup.sh` chama automaticamente `duplicati_to_ha.sh`, que envia o resultado ao Home Assistant (`192.168.3.10`).

### Home Assistant — notificação de backup

| Item | Caminho / valor |
|------|-----------------|
| Script | `/opt/duplicati-scripts/duplicati_to_ha.sh` → `/scripts/` no container |
| Webhook HA | `http://192.168.3.10:8123/api/webhook/duplicati_backup_result` |
| Automações HA | `duplicati_backup_*_homelab` + `duplicati_registar_backup_homelab` — ver `homeassistant/duplicati-backup-automacoes-referencia.yaml` |
| Dashboard / sensores | `sensor.sistema_docker_backup_*_linha`, badge Home, subview `docker-backups` — ver `homeassistant/duplicati-backup-monitor-referencia.md` |
| Config opcional | `duplicati-ha.env` (copiar de `duplicati-ha.env.example`) |
| Log | `/scripts/duplicati_to_ha.log` no container |

**Modo padrão:** webhook local (sem Long-Lived Token), igual ao Uptime Kuma. Para usar também a API de eventos (`Ferramentas de desenvolvedor → Eventos`), defina `HA_NOTIFY_MODE=event` e `HA_TOKEN` no `duplicati-ha.env`.

**Teste rápido** (na VM Docker):

```bash
docker exec -e DUPLICATI__PARSED_RESULT=Success -e DUPLICATI__BACKUP_NAME=teste \
  duplicati /scripts/duplicati_to_ha.sh
docker exec duplicati tail -1 /scripts/duplicati_to_ha.log
```

Antes do backup, **param** (ordem):

1. Immich (server, ML, Postgres)
2. Mealie, Vaultwarden, Uptime Kuma
3. Portainer, AdGuard, FileBrowser

Depois do backup, **sobem na ordem inversa**.

Também gera manifesto em `homelab/backups/manifests/runtime-*.txt` (`docker ps`, volumes, redes).

## Segredos (Vaultwarden)

**Uma senha para tudo (desde reset 2026-05-25):**

| Uso | Onde |
|-----|------|
| Login na UI Duplicati | `DUPLICATI_WEBSERVICE_PASSWORD` em `compose/25/.env` |
| Passphrase dos backups (encriptação AES) | **A mesma senha** |

Guarde **uma entrada** no Vaultwarden (ex.: `Duplicati homelab`) com essa senha e nota: *login + passphrase dos backups*.

Opcional: `SETTINGS_ENCRYPTION_KEY` no mesmo `.env` (protege config local do Duplicati).

Lembrete no servidor: `/root/DUPLICATI-GUARDAR-NO-VAULTWARDEN.txt` (não commitar).

Os `.env` do Portainer entram no volume `portainer_data` e são copiados pelo backup.

## Backup na nuvem (OneDrive)

**Recomendação:** segundo job **`homelab-onedrive`** no **mesmo** Duplicati (sem container OneDrive/rclone à parte), **semanal**, fonte = cópia já no SSD:

```text
/backups/docker-volumes/proxmox-docker01
```

Guia completo (OAuth, horário, retenção): **`docs/DUPLICATI-ONEDRIVE.md`**.

| Job | Frequência | Destino |
|-----|------------|---------|
| `docker-local` | Diário 02:00 | SSD local |
| `homelab-onedrive` | Terça 04:00 | OneDrive `/Homelab-Backup` |

## Verificação

```bash
/root/homelab/scripts/duplicati-verificar-backup.sh
```

Restore trimestral: ver `PENDENCIAS.md` secção 4.
