# Como usar o container-ops (guia simples)

Ferramenta no servidor: **`/opt/container-ops/ops.sh`**

Serve para **atualizar um container** com segurança: faz backup dos volumes (quando faz sentido), muda a versão (tag), sobe de novo e, se der certo, limpa backups antigos e atualiza os sensores do WUD no Home Assistant.

> O **Duplicati** já faz o backup completo do homelab (volumes Docker, etc.). Os backups do `ops.sh` são um “antes de atualizar” rápido — não substituem o Duplicati. Por isso o Immich **não** faz backup do volume de fotos no update (é enorme e o Duplicati já cobre).

---

## Ideia em 3 frases

1. Cada app (Mealie, Jellyfin, Hermes, etc.) está na lista `apps.conf`.
2. Você diz: **“atualiza o mealie para a versão X”**.
3. O script faz backup (se houver volume) → pull → restart → testa → limpa backups velhos → refresh no HA.

**Não mexa** em stacks que não estão na lista (ex.: Glances, Portainer).

---

## Comandos que você vai usar

| O que você quer | Comando |
|-----------------|---------|
| Ver tudo cadastrado | `/opt/container-ops/ops.sh list` |
| Só backup de um app | `/opt/container-ops/ops.sh backup mealie` |
| Backup de **todos** | `/opt/container-ops/ops.sh backup-all` |
| **Atualizar** versão | `/opt/container-ops/ops.sh update mealie latest` |
| **Atualizar sensores HA** (só WUD) | `/opt/container-ops/ops.sh refresh-ha` ou `refresh-ha mealie` |
| Voltar versão antiga | `/opt/container-ops/ops.sh rollback mealie v2.7.0` |
| Apagar backups velhos (ficar com 3) | `/opt/container-ops/ops.sh prune mealie 3` |

Troque `mealie` pelo nome da app (coluna da esquerda no `list`).

---

## Nomes das apps (seus stacks)

| Nome no comando | Serviço | Exemplo de tag |
|-----------------|---------|----------------|
| `mealie` | Receitas | `latest` ou `v2.8.0` |
| `jellyfin` | Jellyfin | `latest` |
| `vaultwarden` | Cofre | `latest` |
| `uptime-kuma` | Monitoramento | `2` |
| `filebrowser` | Arquivos | `latest` |
| `homepage` | Dashboard | `latest` |
| `npm` | Proxy HTTPS | `latest` |
| `adguard` | DNS | `latest` |
| `duplicati` | Backups | `latest` |
| `immich` | Fotos (servidor) | `release` |
| `immich-ml` | Fotos (ML) | `release` (usar a **mesma** tag que `immich`) |
| `cloudflare` | Túnel | `latest` |
| `wud` | Updates Docker | `8.2.2` |
| `hermes` | Agente Telegram | `latest` |
| `dozzle` | Logs Docker | `latest` |
| `prometheus` | Métricas | `latest` |
| `grafana` | Dashboards | `latest` |

**Immich:** depois de `update immich release`, rode também:

```bash
/opt/container-ops/ops.sh update immich-ml release
```

(ou a tag concreta que quiser)

**Immich Postgres / Redis:** não entram no WUD (`wud.watch=false`) — tag fixa / sidecar; não atualize pelo WUD.

---

## Exemplo completo: atualizar o Mealie

```bash
# 1) Ver se está na lista
/opt/container-ops/ops.sh list

# 2) Atualizar (já inclui backup automático + refresh dos sensores HA)
/opt/container-ops/ops.sh update mealie latest

# 2b) Se já atualizou manualmente e o HA ainda mostra update pendente:
/opt/container-ops/ops.sh refresh-ha mealie
# ou todos de uma vez:
/opt/container-ops/ops.sh refresh-ha

# 3) Se algo der errado, voltar atrás
/opt/container-ops/ops.sh rollback mealie v2.7.0
```

---

## Onde ficam os backups

```text
/opt/container-ops/backups/mealie/
/opt/container-ops/backups/jellyfin/
/opt/container-ops/backups/prometheus/
...
```

Arquivos: `mealie_mealie_mealie_data_2026-05-29_120000.tgz`

Depois de um **update com sucesso**, fica só **1 backup recente** por volume (os mais antigos são apagados).

Apps **sem volume** (`hermes`, `cloudflare`, `wud`, `dozzle`): o update só troca a imagem — não gera pasta de backup.

---

## Cuidados

| App | Nota |
|-----|------|
| **adguard** | DNS da rede — atualize em horário calmo |
| **npm** | Proxy de todos os sites — backup inclui certificados |
| **duplicati** | É o próprio backup do servidor (e para serviços no PRE do job) |
| **immich** | Dois comandos: `immich` + `immich-ml`. Fotos ficam com o Duplicati |
| **hermes** | Durante o backup noturno o PRE para o Hermes de propósito |
| **prometheus / grafana** | Também param no PRE do Duplicati; update normal com `ops.sh` |
| **Docker Hub rate limit** | Se o pull falhar com `toomanyrequests`, espere e tente de novo |

---

## WUD e Home Assistant

- O WUD publica updates no HA (MQTT). Entidades no padrão: `update.sistema_docker_*`.
- Depois de um `update`, o `ops.sh` já chama o refresh do WUD.
- Se o HA ficar desatualizado: `/opt/container-ops/ops.sh refresh-ha`.
- Mapa de nomes: `/root/homelab/homeassistant/wud-ha-rename-map.json`
- Script de rename (precisa de token HA): `/root/homelab/scripts/wud-ha-rename-entities.sh`

---

## Onde está o código de cada stack

Tudo aponta para o Git:

`/root/homelab/compose/<nome>/docker-compose.yml`

O Portainer edita a mesma coisa se você sincronizar com `homelab/scripts/sync-portainer-compose.sh`.

Cópia deste guia no Git: `/root/homelab/scripts/container-ops/GUIA.md` (no servidor: `/opt/container-ops/GUIA.md`).

---

## Adicionar outro stack no futuro

1. No `docker-compose.yml`, imagem com variável:  
   `image: org/app:${MINHA_TAG:-latest}`
2. Labels WUD (nome curto, sem “Sistema - …”):  
   `wud.display.name=Meu App` e `wud.watch.digest=true`
3. Linha em `/opt/container-ops/apps.conf` (copie uma existente e adapte; o 7º campo é o nome no WUD, opcional).
4. Confirme volumes: `docker volume ls | grep nome`

---

## Ajuda rápida

```bash
/opt/container-ops/ops.sh help
```
