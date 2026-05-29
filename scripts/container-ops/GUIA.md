# Como usar o container-ops (guia simples)

Ferramenta no servidor: **`/opt/container-ops/ops.sh`**

Serve para **atualizar um container** com segurança: faz backup dos volumes, muda a versão (tag), sobe de novo e, se der certo, apaga backups antigos.

---

## Ideia em 3 frases

1. Cada app (Mealie, Jellyfin, etc.) está numa lista: `apps.conf`.
2. Tu dizes: **“atualiza o mealie para a versão X”**.
3. O script faz backup → pull → restart → testa → limpa backups velhos.

**Não mexas** em stacks que não estão na lista (ex.: Glances, Portainer).

---

## Comandos que vais usar

| O que queres | Comando |
|--------------|---------|
| Ver tudo cadastrado | `/opt/container-ops/ops.sh list` |
| Só backup de um app | `/opt/container-ops/ops.sh backup mealie` |
| Backup de **todos** | `/opt/container-ops/ops.sh backup-all` |
| **Atualizar** versão | `/opt/container-ops/ops.sh update mealie latest` |
| Voltar versão antiga | `/opt/container-ops/ops.sh rollback mealie v2.7.0` |
| Apagar backups velhos (ficar com 3) | `/opt/container-ops/ops.sh prune mealie 3` |

Substitui `mealie` pelo nome da app (coluna da esquerda no `list`).

---

## Nomes das apps (os teus stacks)

| Nome no comando | Serviço | Exemplo de tag |
|---------------|---------|----------------|
| `mealie` | Receitas | `latest` ou `v2.8.0` |
| `jellyfin` | Jellyfin | `latest` |
| `vaultwarden` | Cofre | `latest` |
| `uptime-kuma` | Monitorização | `2` |
| `filebrowser` | Ficheiros | `latest` |
| `homepage` | Dashboard | `latest` |
| `npm` | Proxy HTTPS | `latest` |
| `adguard` | DNS | `latest` |
| `duplicati` | Backups | `latest` |
| `immich` | Fotos (servidor) | `release` |
| `immich-ml` | Fotos (ML) | `release` (usar a **mesma** tag que `immich`) |
| `cloudflare` | Túnel | `latest` |
| `wud` | Updates Docker | `8.2.2` |

**Immich:** depois de `update immich release`, corre também:

```bash
/opt/container-ops/ops.sh update immich-ml release
```

(ou a tag concreta que quiseres)

---

## Exemplo completo: atualizar o Mealie

```bash
# 1) Ver se está na lista
/opt/container-ops/ops.sh list

# 2) Atualizar (já inclui backup automático)
/opt/container-ops/ops.sh update mealie latest

# 3) Se algo correr mal, voltar atrás
/opt/container-ops/ops.sh rollback mealie v2.7.0
```

---

## Onde ficam os backups

```text
/opt/container-ops/backups/mealie/
/opt/container-ops/backups/jellyfin/
...
```

Ficheiros: `mealie_mealie_mealie_data_2026-05-29_120000.tgz`

Depois de um **update com sucesso**, fica só **1 backup recente** por volume (os mais antigos são apagados).

---

## Cuidados

| App | Nota |
|-----|------|
| **adguard** | DNS da rede — atualiza em horário calmo |
| **npm** | Proxy de todos os sites — backup inclui certificados |
| **duplicati** | É o próprio backup do servidor |
| **immich** | Dois comandos: `immich` + `immich-ml` |

---

## Onde está o código de cada stack

Tudo aponta para o teu Git:

`/root/homelab/compose/<nome>/docker-compose.yml`

O Portainer edita a mesma coisa se sincronizares com `homelab/scripts/sync-portainer-compose.sh`.

---

## Adicionar outro stack no futuro

1. No `docker-compose.yml`, imagem com variável:  
   `image: org/app:${MINHA_TAG:-latest}`
2. Linha em `/opt/container-ops/apps.conf` (copia uma existente e adapta).
3. Confirma volumes: `docker volume ls | grep nome`

---

## Ajuda rápida

```bash
/opt/container-ops/ops.sh help
```
