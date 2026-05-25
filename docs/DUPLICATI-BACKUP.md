# Duplicati — backup completo do homelab

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

**Retenção:** `1W:1D,4W:1W,12M:1M`

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

## Próximo passo: nuvem

Crie um **segundo job** no Duplicati apontando para o mesmo conjunto de fontes (ou só `/mnt/ssd-backup/docker-volumes/`) com destino S3/B2/WebDAV — regra 3-2-1.

## Verificação

```bash
/root/homelab/scripts/duplicati-verificar-backup.sh
```

Restore trimestral: ver `PENDENCIAS.md` secção 4.
