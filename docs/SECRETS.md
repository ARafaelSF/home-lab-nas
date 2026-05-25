# Segredos — onde ficam (nunca no Git)

## Ficheiros `.env` no servidor (Portainer)

| Stack | Pasta (live) | Variáveis |
|--------|----------------|-----------|
| Cloudflare Tunnel | `/var/lib/docker/volumes/portainer_data/_data/compose/4/.env` | `TUNNEL_TOKEN` |
| Duplicati | `.../compose/25/.env` | `SETTINGS_ENCRYPTION_KEY`, `DUPLICATI_WEBSERVICE_PASSWORD` |
| WUD | `.../compose/26/.env` | `WUD_MQTT_PASSWORD` |

Permissões: `chmod 600` em cada `.env`.

## Immich

| Ficheiro | Caminho |
|----------|---------|
| `.env` (live) | `.../compose/8/.env` |
| Modelo no Git | `homelab/compose/immich/.env.example` |

## Outros

| Ficheiro | Uso |
|----------|-----|
| `/etc/docker/wud-lscr.env` | Token GitHub LSCR (opcional) |
| NPM / Vaultwarden | credenciais na UI, não no compose |

## Novo clone do Git

```bash
cp homelab/compose/cloudflare-tunnel/.env.example \
   /var/lib/docker/volumes/portainer_data/_data/compose/4/.env
# editar .env com valores reais
chmod 600 .../4/.env
```

Repetir para `25/` (duplicati) e `26/` (wud).

## Git

`.gitignore` ignora `.env`, `stack.env` e `**/secrets/`.  
Só commitar `*.env.example` e `docker-compose.yml` com `${VARIAVEL}`.
