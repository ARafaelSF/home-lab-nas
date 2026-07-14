# container-ops

Rotina padronizada para **backup**, **update**, **rollback** e **limpeza** de backups de stacks Docker Compose.

## Estrutura

```text
/opt/container-ops/          # cópia activa no servidor (opcional: symlink para o repo)
homelab/scripts/container-ops/
├── apps.conf          # cadastro de apps
├── ops.sh             # script principal
├── README.md
└── GUIA.md
```

No servidor, pode manter em `/opt/container-ops/` ou ligar ao repo:

```bash
sudo ln -sfn /root/homelab/scripts/container-ops /opt/container-ops
```

## Cadastrar um app

Edite `apps.conf` (uma linha por app):

```text
app|stack_dir|service|tag_env_key|volumes_csv
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
/opt/container-ops/ops.sh list
/opt/container-ops/ops.sh backup mealie
/opt/container-ops/ops.sh update hermes latest
/opt/container-ops/ops.sh update all
/opt/container-ops/ops.sh rollback mealie latest
/opt/container-ops/ops.sh prune mealie 3
```

### `update <app> <tag>`

Exemplo do dia a dia:

```bash
/opt/container-ops/ops.sh update hermes latest
```

1. Backup automático de todos os volumes listados  
2. Atualiza `tag_env_key` no `.env` (cria a chave se não existir)  
3. `docker compose pull` + `up -d` só no serviço indicado  
4. Valida container em `running` e regista a imagem  
5. Se falhar em qualquer passo, **não apaga** backups  
6. Se OK, `prune` com **keep=1** (um backup recente por volume)  
7. Refresh do sensor WUD → Home Assistant  

### `update all`

Actualiza **todas** as apps em `apps.conf` com a tag habitual:

- maioria → `latest`
- `immich` / `immich-ml` → `release`
- `uptime-kuma` → `2`

Continua se uma falhar; no fim um único refresh WUD→HA.
### `prune`

Remove backups antigos **por volume** (não mistura volumes).  
Nunca remove se só existir **1** ficheiro. Padrão: `keep=1`.

## Exemplo Mealie (homelab)

```bash
# Só backup
/opt/container-ops/ops.sh backup mealie

# Update (faz backup antes)
/opt/container-ops/ops.sh update mealie v2.8.0

# Voltar atrás
/opt/container-ops/ops.sh rollback mealie latest

# Manter 3 backups por volume
/opt/container-ops/ops.sh prune mealie 3
```

Volume cadastrado: `mealie_mealie_data`  
Stack: `/root/homelab/compose/mealie`

## Dependências

- `docker` + plugin `compose`
- Imagem `alpine:3.20` (pull automático no primeiro backup)

## Segurança

- `set -euo pipefail` em todos os passos críticos  
- Backups em modo leitura (`:ro` no volume)  
- `.env` com permissão `600` após alteração de tag
