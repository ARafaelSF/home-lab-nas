# Glances + ponte Home Assistant

| Serviço | Porta / função |
|---------|----------------|
| `glances` | `http://192.168.3.21:61208` (Homepage widget, LAN) |
| `glances-ha-bridge` | MQTT → sensores `escritorio_homelab_nas_*` no HA |

## Deploy (homelab)

```bash
cp .env.example .env   # WUD_MQTT_PASSWORD = mesma do stack WUD (26)
./homelab/scripts/deploy-stack.sh glances
```

## Gerir no Portainer

Containers criados com `deploy-stack.sh` aparecem como **fora do Portainer**. Para editar na UI:

1. `docker compose -p glances -f /root/homelab/compose/glances/docker-compose.yml down`
2. Portainer → **Stacks** → **Add stack** → nome `glances`
3. **Web editor** → colar `docker-compose.yml` desta pasta
4. **Environment variables** → colar o `.env` (só `WUD_MQTT_PASSWORD`)
5. **Deploy the stack**
6. Anotar o ID numérico (URL ou pasta em `portainer_data/compose/<id>/`) e, se quiser, adicionar ao `config/portainer/stacks-map.json`

Depois de stacks restaurados: `homelab/scripts/sync-portainer-compose.sh`
