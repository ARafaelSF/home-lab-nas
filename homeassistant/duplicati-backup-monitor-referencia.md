# Duplicati — monitorização na dashboard Docker (Home Assistant)

Implementado via MCP em **2026-05-29**.

## Sensores (leitura na UI)

| Entidade | Exemplo de estado | Uso |
|----------|-------------------|-----|
| `sensor.sistema_docker_backup_ssd_linha` | `há 10h — OK` | Resumo job **docker-local** (SSD) |
| `sensor.sistema_docker_backup_onedrive_linha` | `há 7 dias — Erro` | Resumo job **homelab-onedrive** |
| `sensor.sistema_docker_backup_problemas` | `0`, `1`, `2`… | Contagem de problemas (badge Home) |
| `binary_sensor.sistema_docker_backup_atencao` | `on` / `off` | Alerta agregado |

## Helpers (gravados pelo webhook)

| Entidade | Conteúdo |
|----------|----------|
| `input_datetime.sistema_docker_backup_ssd_ultimo` | Data/hora do último backup SSD |
| `input_select.sistema_docker_backup_ssd_estado` | `success` / `warning` / `error` / `unknown` / `none` |
| `input_datetime.sistema_docker_backup_onedrive_ultimo` | Último backup OneDrive |
| `input_select.sistema_docker_backup_onedrive_estado` | Estado OneDrive |

## Regras de alerta

| Job | Prazo esperado | Alerta «Atrasado» se |
|-----|----------------|----------------------|
| **docker-local** (SSD) | Diário (~02:00) | Sem registo ou último backup há **> 36 h** (e não for erro) |
| **homelab-onedrive** | Semanal (terça ~04:00) | Sem registo ou último backup há **> 9 dias** (e não for erro) |

Pontuação em `sensor.sistema_docker_backup_problemas`:

- **+2** — último resultado `error`
- **+1** — `warning`, sem registo, ou atrasado

## Dashboard

| Onde | O quê |
|------|--------|
| **Home** (badges) | Badge **Backup** (ícone vermelho) quando `problemas > 0` → abre `/dashboard-casa/docker-backups` |
| **Docker** (`docker-atualizacoes`) | Cartão markdown **Backups** no topo (resumo SSD + OneDrive) |
| **Backups Docker** (`docker-backups`) | Subview com resumo, entidades e tiles de estado/data |

## Automação

- `automation.duplicati_registar_backup_homelab` — grava helpers em cada webhook
- Notificações: `automation.duplicati_backup_*_homelab` (OK / warning / error)

## Script na VM Docker

`/opt/duplicati-scripts/duplicati_to_ha.sh` envia JSON com `job_name`, `job_key` (`ssd` / `onedrive`), `status`, `message`, `time`.
