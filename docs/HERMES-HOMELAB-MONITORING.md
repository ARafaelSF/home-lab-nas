# Hermes Agent — monitorização do homelab

## O que já tens (sem instalar mais nada)

| Ferramenta | Função |
|------------|--------|
| **Uptime Kuma** | HTTP up/down dos serviços |
| **Glances** | CPU, RAM, disco, containers (API + HA) |
| **WUD + MQTT** | Updates Docker no Home Assistant |
| **Duplicati → HA** | Estado dos backups |
| **Tailscale** | Acesso remoto SSH/LAN |

Isto cobre **alertas básicos** e **consultas interativas** via Hermes.

## Preciso de Prometheus + Grafana + Loki?

| Stack | Necessário agora? | Quando faz sentido |
|-------|-------------------|-------------------|
| Node Exporter + cAdvisor | Não | Só se fores para Prometheus (Glances já cobre métricas ao vivo) |
| Grafana + Prometheus | Opcional (fase 2) | Histórico de semanas/meses, gráficos, alertas PromQL |
| Loki + Promtail | Opcional (fase 2) | Pesquisa centralizada de logs em escala |
| **Dozzle** | Opcional (simples) | Ver logs Docker no browser — leve |

**Recomendação actual:** Hermes + Telegram + Glances + Uptime Kuma + Dozzle + **Prometheus/Grafana** (histórico). Loki só se precisares de pesquisa centralizada de logs em escala.

---

## Fase 3 — Prometheus + Grafana

| Componente | Porta LAN | Função |
|------------|-----------|--------|
| **Grafana** | `:3005` | Dashboards (host + Docker) |
| **Prometheus** | `:9090` | Armazena métricas (**30 dias**) |
| **node-exporter** | interno | CPU, RAM, disco do host |
| **cAdvisor** | interno | Métricas por container |

Stack: `compose/monitoring/`

```bash
./scripts/deploy-stack.sh monitoring
```

### Credenciais Grafana

- User: `admin` (ou `GRAFANA_ADMIN_USER` no `.env`)
- Senha: `compose/monitoring/.env` → `GRAFANA_ADMIN_PASSWORD`

### Dashboards pré-carregados (pasta Homelab)

- **Node Exporter Full** — servidor (CPU, RAM, disco, rede)
- **cAdvisor Docker** — uso por container

### Relação com o resto

| Ferramenta | Quando usar |
|------------|-------------|
| **Glances** | Agora / MQTT → HA |
| **Grafana** | Tendências, picos, “o que aconteceu ontem à noite?” |
| **Uptime Kuma** | Serviço HTTP em baixo |
| **Dozzle** | Logs no momento do incidente |

Cloudflare/NPM para Grafana: configurar depois (como Dozzle).

---

## Fase 2 — Dozzle + Uptime Kuma → Telegram

| Componente | Função |
|------------|--------|
| **Dozzle** `:8888` | Ver e filtrar logs Docker no browser (investigação) |
| **Uptime Kuma → Telegram** | Alertas up/down **directos**, mesmo se o Hermes estiver em baixo |
| **Webhook HA** (existente) | Mantido em paralelo |

### Dozzle

- Stack: `compose/dozzle/`
- LAN: http://192.168.3.21:8888 (user `admin`, senha em `compose/dozzle/users.yml` ou regenerar com `.env.example`)
- Hermes: usa Dozzle para contexto visual; `docker logs` continua válido para um container específico

```bash
./scripts/deploy-stack.sh dozzle
```

### Uptime Kuma → Telegram (script)

Usa o **mesmo bot** do Hermes (`compose/hermes-agent/.env`):

```bash
chmod +x /root/homelab/scripts/uptime-kuma-telegram-setup.sh
/root/homelab/scripts/uptime-kuma-telegram-setup.sh
```

Na UI: Settings → Notifications → deve aparecer **Telegram Homelab** em todos os monitores (webhook HA mantido).

---

## Configuração — Telegram

### 1. Criar o bot

1. Telegram → [@BotFather](https://t.me/BotFather) → `/newbot`
2. Guarda o **token**
3. [@userinfobot](https://t.me/userinfobot) → obtém o teu **user ID**

### 2. Editar `.env`

```bash
nano /root/homelab/compose/hermes-agent/.env
```

```env
TELEGRAM_BOT_TOKEN=123456789:ABC...
TELEGRAM_ALLOWED_USERS=SEU_USER_ID
TELEGRAM_HOME_CHANNEL=SEU_USER_ID
```

### 3. Reiniciar Hermes

```bash
docker compose -p hermes-agent -f /root/homelab/compose/hermes-agent/docker-compose.yml up -d
```

Envia `/start` ao bot.

### 4. SOUL do homelab

```bash
cat /root/homelab/compose/hermes-agent/SOUL-homelab.md >> \
  $(docker volume inspect hermes-agent_hermes_data --format '{{.Mountpoint}}')/SOUL.md
docker compose -p hermes-agent -f /root/homelab/compose/hermes-agent/docker-compose.yml restart hermes
```

### 5. Cron — alertas automáticos

```bash
docker exec hermes-agent hermes cron create "every 5m" \
  --name homelab-watchdog \
  --script homelab-watchdog.sh \
  --no-agent \
  --deliver telegram
```

### 6. Cron — resumo diário (com LLM)

```bash
docker exec hermes-agent hermes cron create "0 8 * * *" \
  --name homelab-resumo-manha \
  --deliver telegram \
  "Resumo curto do homelab: Glances, docker ps, só anomalias. Máx 10 linhas."
```
