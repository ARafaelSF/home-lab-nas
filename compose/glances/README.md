# Glances + ponte Home Assistant

| Serviço | Porta / função |
|---------|----------------|
| `glances` | `http://192.168.3.21:61208` (Homepage widget, LAN) |
| `glances-ha-bridge` | MQTT → sensores `escritorio_homelab_nas_*` no HA |

## Atualizar (preferido)

Pelo Home Assistant (Docker → Glances) ou no host:

```bash
/root/homelab/scripts/container-ops/ops.sh update glances latest-full
```

Só recria o contentor `glances` (imagem `nicolargo/glances:${GLANCES_TAG:-latest-full}`). A ponte `glances-ha-bridge` fica de fora (`wud.watch=false`).

## Deploy inicial

```bash
cp .env.example .env   # WUD_MQTT_PASSWORD = mesma do stack WUD
docker compose -f /root/homelab/compose/glances/docker-compose.yml -p glances up -d
```

## Portainer (opcional)

Cópia de referência no volume: `portainer_data/compose/31/`. O stack live corre a partir do Git (`/root/homelab/compose/glances`). Após editar o compose no Git, sincronizar se quiser manter a cópia alinhada:

```bash
cp /root/homelab/compose/glances/docker-compose.yml \
   /var/lib/docker/volumes/portainer_data/_data/compose/31/
cp -r /root/homelab/compose/glances/bridge \
   /var/lib/docker/volumes/portainer_data/_data/compose/31/
```
