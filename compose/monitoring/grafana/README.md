# Grafana Homelab

Instância: Docker `grafana` em **http://192.168.3.21:3005**  
Stack: `/root/homelab/compose/monitoring`  
Dashboards provisionados (ficheiro): `compose/monitoring/grafana/dashboards/`

## Pastas

| Pasta | Pasta no disco | Para quê |
|-------|----------------|----------|
| **Homelab** | `dashboards/homelab/` | Servidor NAS / Docker / internet |
| **Casa** | `dashboards/casa/` | Dados do Home Assistant via Influx |

Home (página inicial): **Início — Homelab & Casa** (`uid: homelab-inicio`).

## Dashboards

| Título | UID | Fonte | O que mostra |
|--------|-----|-------|--------------|
| Início — Homelab & Casa | `homelab-inicio` | Prometheus (stats) | Mapa + contadores rápidos |
| Servidor — Node Exporter | `rYdddlPWk` | Prometheus / node-exporter | CPU, RAM, disco, rede do **host** |
| Docker — Contentores (cAdvisor) | `pMEd7m0Mz` | Prometheus / cAdvisor | Recursos **por contentor** |
| Internet — Qualidade e Velocidade | `internet-quality` | Prometheus / ping + blackbox + speedtest | Latência, perda, DNS, HTTP, Mbps |
| Energia da Casa | `energia-da-casa` | InfluxQL `home_energy` | Rede, solar, fases, aparelhos |
| Dispositivos offline | `dispositivos-offline` | Influx Flux `device_availability` | Tempo offline (regra do HA) |
| Geladeira Midea — Sonoff vs Z2M | `geladeira-midea-comparativo` | InfluxQL `energy-raw-30d` | Comparar dois medidores da geladeira |

## Datasources

| Nome | UID | Tipo |
|------|-----|------|
| Prometheus | `PBFA97CFB590B2093` | Prometheus (`http://prometheus:9090`) |
| HomeAssistant | `PBB7EDB19FB19A0A4` | Influx Flux → bucket `home_energy` |
| Energia - Detalhado 30d | `energy-raw-30d` | InfluxQL retention `raw_30d` |
| Energia - Histórico horário | `energy-hourly-inf` | InfluxQL horário |

## Manutenção

1. Editar JSON em `compose/monitoring/grafana/dashboards/...`
2. Recarregar provisionamento:
   ```bash
   curl -u "$GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD" \
     -X POST http://192.168.3.21:3005/api/admin/provisioning/dashboards/reload
   ```
   Ou reiniciar: `docker restart grafana` (o intervalo de ficheiro é 300 s).
3. Atualizar o contentor Grafana: pelo HA (Docker) ou  
   `/root/homelab/scripts/container-ops/ops.sh update grafana latest`

## Problemas habituais (já corrigidos em 2026-09-27)

- **cAdvisor** usava `${DS_PROMETHEUS}` (import Grafana.com) → painéis vazios. Agora aponta ao Prometheus provisionado.
- **Node Exporter** tinha variável de datasource sem valor por omissão → gráficos vazios até escolher Prometheus/Job/Instance.
- Cada dashboard tem um painel **Sobre este dashboard** no topo.
