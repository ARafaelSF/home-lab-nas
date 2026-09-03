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

O `homelab-watchdog.sh` **não alerta** containers parados de propósito pelo Duplicati (PRE/POST em `/opt/duplicati-scripts/`) enquanto existir `/tmp/duplicati-stopped-containers.txt` no container `duplicati`. O SOUL também documenta esta janela (~02:00) para o LLM não tratar como incidente.

Mensagens do watchdog em **português claro**. Em `config.yaml`: `cron.wrap_response: false` (remove o cabeçalho/rodapé em inglês “Cronjob Response…”).

### Notificação “Gateway shutting down” (Telegram)

O Hermes envia essa mensagem ao receber `SIGTERM` (ex.: `docker stop` no PRE do Duplicati). Para **interrupções previstas**, desactivar no `config.yaml` do volume:

```yaml
gateway:
  platforms:
    telegram:
      gateway_restart_notification: false
```

Script idempotente (já aplicado no servidor):

```bash
chmod +x /root/homelab/scripts/hermes-apply-homelab-config.sh
/root/homelab/scripts/hermes-apply-homelab-config.sh
```

Ou manualmente: `docker exec hermes-agent hermes config set gateway.platforms.telegram.gateway_restart_notification false` **e reiniciar o container** (`docker compose ... restart hermes`).

**Importante:** a flag só entra em vigor no processo gateway **depois de um restart**. Se alterares o YAML com o Hermes a correr, o backup dessa noite ainda pode enviar o aviso uma vez. O `pre-backup.sh` também usa `docker kill` no Hermes (em vez de `stop`) para não disparar o shutdown gracioso com Telegram.

**Nota:** com isto desligado, também não recebes aviso se reiniciares o Hermes manualmente com uma conversa activa — aceitável para o bot de monitorização do homelab.

### 6. Cron — resumo diário (com LLM)

```bash
docker exec hermes-agent hermes cron create "0 8 * * *" \
  --name homelab-resumo-manha \
  --deliver telegram \
  "Resumo curto do homelab: Glances, docker ps, só anomalias. Máx 10 linhas."
```
