# Continuar noutro computador (2026-09-08 noite)

Repo: `git@github.com-home-lab-nas:ARafaelSF/home-lab-nas.git`  
Branch: `main`

Abrir esta pasta no Cursor (não `/root`). O config do Home Assistant **não está neste git** — vive em `/mnt/ha-config` na VM Docker (`192.168.3.21`).

## Já aplicado em produção (não reinstalar)

| O quê | Onde |
|--------|------|
| View **Servidor** (Sonoff HomeLab, sem Estação de Trabalho, Mini backup Tasmota visível) | HA `dashboard-casa`, gravada via API |
| Sensor `sensor.sistema_temperatura_cpu_minipc` | MQTT discovery + YAML em `/mnt/ha-config/packages/mqtt/minipc_proxmox.yaml` |
| Exportador de temperatura | Proxmox `192.168.3.20:9108` — `minipc-temp-exporter.service` |
| Publicação MQTT a cada 30 s | VM Docker — `minipc-temp-publisher.timer` (`/opt/container-ops/minipc-temp.env`, **não está no git**) |
| Listener de updates Docker pelo HA | `:8787` — `container-ops-ha-update.service` |
| Firefly + Influx no `ops.sh` | `scripts/container-ops/apps.conf` |
| Grafana pastas Homelab / Casa | `compose/monitoring/grafana/dashboards/` |
| Pacote ISP Trix | `docs/evidencias-isp-trix-20260907/` |
| UniFi RF: 2.4 **11 / 6**, 6 GHz **37/160** e **101/160**, Aeron off | UCG — ver `docs/UNIFI-RF.md` |
| Zigbee canal **11** (SLZB escritório) | Z2M — **não mudar** |
| AdGuard backup Pi `192.168.3.22` + HA a espelhar protecção | VLAN Servidor; automação no HA |
| Estudo min. rate 2.4 (snapshots 10 min) | `scripts/unifi-rf-study/` neste PC; dados **fora do git** |

## Segredos (não estão no git)

- Compose: cada `compose/*/.env`
- MQTT temp: `/opt/container-ops/minipc-temp.env`
- Token do listener Docker: `/opt/container-ops/ha-update.env`
- Token HA: variável `HA_TOKEN` / ficheiro fora do repo

## Como retomar no outro PC

1. `git pull` em `home-lab-nas` (`main`).
2. Abrir o Cursor **nessa pasta**.
3. SSH à VM `192.168.3.21` (e HA `192.168.3.10`) — a dash e os serviços já estão lá.
4. Pendências: `PENDENCIAS.md`.
5. **Rede Wi-Fi:** canais já aplicados. Por agora **não mexer mais em RF**. Falta só o cabo da suíte (físico) e, daqui a uns dias, decidir o min. rate com as amostras — `docs/UNIFI-RF.md`.
6. O collector do estudo corre **neste host** (`/root/homelab/scripts/unifi-rf-study/data/`). Noutro PC só vês o script; as amostras não vão no git.

## Se precisares de reaplicar só a dash Servidor

```bash
export HA_TOKEN='…'
python3 scripts/apply-dash-servidor-20260907.py
```

Isto grava a view via WebSocket. Editar `.storage` no disco **não** actualiza a dash ao vivo.
