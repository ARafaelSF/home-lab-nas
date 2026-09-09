# container-ops

Rotina padronizada para **backup**, **update**, **rollback** e **limpeza** de stacks Docker Compose.

## Onde corre

```text
/root/homelab/scripts/container-ops/   ← código (git) — fonte de verdade
/opt/container-ops/                    ← só dados: backups/, *.env, logs/
```

O systemd e o Home Assistant chamam o script **no git**.  
`/opt/container-ops/ops.sh` é só um wrapper (opcional).

**Nunca** faças `ln -sfn … /opt/container-ops` nem copies o código para `/opt` (já partiu segredos/backups no passado).

Depois de mudar units systemd / rotas / DNS no repo:

```bash
/root/homelab/scripts/install-host.sh
```

## Cadastrar um app

Edite `apps.conf` (uma linha por app):

```text
app|stack_dir|service|tag_env_key|volumes_csv|compose_project|wud_name(opcional)
```

| Campo | Descrição |
|-------|-----------|
| `app` | Nome curto usado nos comandos |
| `stack_dir` | Pasta com `docker-compose.yml` e `.env` |
| `service` | Nome do serviço no compose |
| `tag_env_key` | Variável no `.env` que define a tag da imagem |
| `volumes_csv` | Volumes Docker reais (`docker volume ls`), separados por vírgula |

No `docker-compose.yml`, a imagem deve usar a variável:

```yaml
image: ghcr.io/mealie-recipes/mealie:${MEALIE_TAG:-latest}
```

## Comandos

```bash
/root/homelab/scripts/container-ops/ops.sh list
/root/homelab/scripts/container-ops/ops.sh backup mealie
/root/homelab/scripts/container-ops/ops.sh update hermes latest
/root/homelab/scripts/container-ops/ops.sh update all
/root/homelab/scripts/container-ops/ops.sh rollback mealie latest
/root/homelab/scripts/container-ops/ops.sh prune mealie 3
```

### `update <app> <tag>`

1. Backup automático dos volumes listados  
2. Actualiza `tag_env_key` no `.env`  
3. `docker compose pull` + `up -d`  
4. Valida container `running`  
5. Se OK, `prune` com keep=1 + refresh WUD→HA  

### `update all`

Actualiza todas as apps (majority `latest`; Immich → `release`; Uptime Kuma → `2`). Continua se uma falhar; no fim um único refresh WUD→HA.

## Dependências

- `docker` + plugin `compose`
- Imagem `alpine:3.20` (pull automático no primeiro backup)

## Segurança

- `set -euo pipefail`  
- Backups em modo leitura (`:ro` no volume)  
- `.env` com permissão `600` após alteração de tag  
