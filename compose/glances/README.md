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

## Portainer

Stack **glances** (ID **31**) — gerir em Portainer → Stacks → **glances** → Editor.

Ficheiros live: `portainer_data/compose/31/` (inclui `bridge/` para o build).

Sincronizar do Git para o Portainer após editar aqui:

```bash
cp /root/homelab/compose/glances/docker-compose.yml \
   /var/lib/docker/volumes/portainer_data/_data/compose/31/
cp -r /root/homelab/compose/glances/bridge \
   /var/lib/docker/volumes/portainer_data/_data/compose/31/
# Depois: Portainer → glances → Update the stack
```

Não usar `deploy-stack.sh glances` (conflita com o stack 31).
