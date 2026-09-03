# InfluxDB no homelab — dados Home Assistant

**Atualizado:** 2026-08-30

## Resumo

| Item | Valor |
|------|--------|
| URL LAN | `http://192.168.3.21:8086` |
| UI | `http://192.168.3.21:8086` (login admin) |
| Organization | `homelab` |
| Bucket HA | `home_energy` |
| Bucket reservado | `monitoring` |
| Stack | `compose/monitoring/docker-compose.yml` |
| Credenciais | `compose/monitoring/.env` |

## Integração Home Assistant

- **Configurações → Dispositivos e serviços → InfluxDB**
- Título: `home_energy (http://192.168.3.21:8086)`
- Filtros de sensores: `packages/influxdb_energia/influxdb_energia.yaml` (inalterado)

## Grafana homelab (`192.168.3.21:3005`)

Datasource **HomeAssistant** provisionado automaticamente (Flux, bucket `home_energy`).

Teste: Explore → datasource HomeAssistant → query:

```flux
from(bucket: "home_energy")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "sensor__energy")
  |> limit(n: 20)
```

## Grafana no Home Assistant (add-on)

Configuração **manual** na UI do Grafana (add-on):

1. Abrir Grafana no HA (Ingress)
2. **Connections → Data sources → Add data source → InfluxDB**
3. Preencher:

| Campo | Valor |
|-------|--------|
| Query Language | Flux |
| URL | `http://192.168.3.21:8086` |
| Organization | `homelab` |
| Token | token `grafana-reader` (ver `.env` → `INFLUXDB_GRAFANA_READ_TOKEN`) |
| Default bucket | `home_energy` |

4. **Save & test**

Se dashboards antigos usavam InfluxQL/1.x, pode ser necessário ajustar queries para Flux ou mudar Query Language para **InfluxQL** com DBRP (bucket `home_energy`).

## Migração histórica

- Script: `scripts/migrate-influx-ha-to-homelab.py`
- Backup portable tentado em `backups/influx-migration/`
- **319 549 pontos** importados do add-on InfluxDB 1.x (database `home_energy`)

## Pós-validação

- [x] Add-on **InfluxDB** EOL removido do HA (2026-08-30)
- Grafana HA e homelab a usar `192.168.3.21:8086`
- Dashboard **Energia da Casa** disponível nos dois Grafana

## Tokens (onde estão)

Todos em `/root/homelab/compose/monitoring/.env`:

- `INFLUXDB_ADMIN_PASSWORD` / `INFLUXDB_ADMIN_TOKEN` — admin UI
- `INFLUXDB_HA_WRITE_TOKEN` — integração HA
- `INFLUXDB_GRAFANA_READ_TOKEN` — Grafana (HA e homelab)

## Setup inicial (novo deploy)

```bash
cd /root/homelab/compose/monitoring
docker compose up -d influxdb
./scripts/influxdb-setup.sh
docker compose up -d grafana
```
