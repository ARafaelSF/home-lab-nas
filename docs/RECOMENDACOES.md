# Revisão Docker — recomendações (2026-05-25)

## Estado atual (OK)

- **16 containers** healthy ou running
- **Roteamento LAN 68.x** corrigido (`route-lan68` + `daemon.json` pools `172.40.x`)
- **Firewall** `DOCKER-USER` ativo (portas admin só LAN confiável)
- **WUD + Uptime Kuma v2** operacionais
- **Imagens** LinuxServer em `ghcr.io` (não `lscr.io`)

## Recomendado fazer em breve

### 1. Segredos fora do compose

- [x] **cloudflared**, **duplicati**, **wud** — senhas em `.env` (chmod 600), composes só com `${VAR}`.
- Immich continua em `stack.env` (fora do Git) — ver `docs/SECRETS.md`.
- Repositório `homelab/` seguro para `git push` (apenas `*.env.example`).

### 2. Volumes Docker órfãos (~dados antigos)

Existem volumes antigos dos IDs numéricos do Portainer (`5_adguard_*`, `8_immich_*`, etc.) **sem container ligado**. Os ativos são `adguard-home_*`, `immich_*`, etc.

**Antes de apagar:** confirmar que Immich/AdGuard abrem normalmente.

```bash
docker volume ls -f dangling=true
# Se tudo OK no painel:
docker volume prune -f
```

Libera espaço em disco; **não remove** volumes em uso.

### 3. Rede órfã `13_default`

Removida na revisão (restante de deploy falho). Se voltar a aparecer: `docker network prune -f`.

### 4. Immich — após backup

Ver `PENDENCIAS.md` secção 5: migrar Redis → Valkey com compose da release oficial.

### 5. Mealie `ALLOW_SIGNUP`

Compose no repo já está `false`. Confirmar no Portainer que o container em execução reflete isso.

### 6. Filebrowser

Monta `/` no container — manter senha forte; não expor sem NPM/Cloudflare + 2FA onde possível.

### 7. Portainer como fonte de verdade

Os ficheiros **em execução** estão em:

`/var/lib/docker/volumes/portainer_data/_data/compose/<id>/`

Este git em `homelab/compose/<nome>/` é a documentação e backup lógico. Após editar aqui, sincronizar no Portainer ou usar `scripts/deploy-stack.sh`.

### 8. Git

```bash
cd /root/homelab
git init
git add .
git commit -m "Homelab Docker: composes, firewall, docs"
# git remote add origin <seu-repo>
```

**Nunca** commitar `.env`, `stack.env` ou backups `.tar.gz` com dados reais.

## Opcional (prioridade baixa)

- Limites `mem_limit` em Immich ML e Jellyfin se RAM apertar (VM 8 GB)
- `fail2ban` no SSH se a porta 22 for exposta fora da LAN
- Token GitHub em `/etc/docker/wud-lscr.env` só se voltar a usar `lscr.io`
- Teste restore Duplicati trimestral (`scripts/duplicati-verificar-backup.sh`)
- Vaultwarden 2FA na conta

## Mapa de portas (host)

| Serviço | Porta(s) |
|---------|----------|
| SSH | 22 |
| AdGuard DNS | 53 |
| NPM HTTP/HTTPS | 80, 443 |
| NPM Admin | 81 |
| AdGuard UI | 3000, 8080 |
| Homepage | 3001 |
| Uptime Kuma | 3002 |
| Vaultwarden | 3003 |
| Immich | 2283 |
| Jellyfin | 8096 |
| Filebrowser | 8085 |
| Mealie | 9925 |
| Duplicati | 8200 |
| Portainer | 8000, 9443 |

Admin (9443, 8200, …) bloqueadas para WAN via `homelab-firewall.sh`.
