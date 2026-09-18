# Mini PC de reserva — plano e sequência

Documento de referência. Execução **passo a passo** (um de cada vez).

## Em poucas palavras

- **Principal** `192.168.3.20` — trabalha todos os dias (HA + Docker)
- **Reserva** `192.168.3.30` — desligado na tomada; uma vez por semana recebe cópia inteligente
- **Tomada:** `switch.escritorio_servidor_minipc_tasmota`
- **SSD 1 TB:** só no principal; no desastre moves à mão (não copia pela rede)
- **Emergência:** `docs/PROXMOX-RESERVA-EMERGENCIA.md`

## Hardware (confirmado)

| | Principal | Reserva |
|--|--|--|
| Disco sistema | ~2 TB NVMe | ~2 TB NVMe |
| SSD backup | ~1 TB | não tem |
| RAM | 16 GB | 16 GB (compatível; slot extra vazio) |
| CPU | Intel N150 | Intel N100 |
| Proxmox | **9.2.20** (kernel 7.0.14-17) — atualizado 2026-09-18 | já **9.2.2** |

## Sequência

### Passo 1 — Atualizar o Proxmox principal ✅
Concluído 2026-09-18: `.20` de 9.1.19 → **9.2.20**, reboot, VMs Docker+HA a correr.

### Passo 2 — Não copiar o SSD na cópia semanal ✅
Concluído 2026-09-18: disco `scsi2` da VM Docker (SSD Duplicati) com `backup=0`. O dia a dia do principal não muda.

### Passo 3 — Serviço de backup na reserva ✅
Concluído 2026-09-18:
- PBS 4.2 instalado no `.30` (UI `:8007`)
- Datastore `homelab` em `/mnt/datastore` (~1,2 TB)
- Utilizador/token `backup@pbs!pve-primary`
- No principal: storage **`pbs-reserva`** ligado e ativo

### Passo 4 — Primeira cópia ✅
Concluído **2026-09-18**:
- Backup PBS (`vzdump` → `pbs-reserva`; SSD excluído): Docker ~1h20, HA ~5 min
- Restauração na reserva: VMs **100** (docker) e **101** (homeassistant) **paradas**, `onboot=0`
- Arquivos PBS: `vm/100/2026-09-18T14:08:47Z`, `vm/101/2026-09-18T15:28:18Z`
- Logs: principal `/var/log/homelab/pbs-primeira-copia-latest.log` · reserva `/var/log/homelab/pbs-primeira-restore-latest.log`

Podes desligar o mini PC de reserva e a tomada Tasmota (cold standby).

### Passo 5 — Script da rotina semanal ✅
Concluído **2026-09-18**:
- Script: `scripts/proxmox-reserva/rotina-semanal.sh`
- Fluxo: espera `.30` → `vzdump` 101+100 → `pbs-reserva` → `qmrestore --force` na reserva → `onboot=0` + VMs paradas → status JSON
- Opções: `--check`, `--backup-only`, `--restore-only`, `--shutdown-reserva`
- Logs: `/var/log/homelab/pbs-rotina-semanal-latest.log` (+ backup/restore no principal e na reserva)
- SSH: hosts `proxmox` (`.20`) e `proxmox-reserva` (`.30`) com chave `proxmox_homelab`
- Prune PBS: mantém as últimas **3** versões por VM (`KEEP_LAST`)

Ainda **não** está agendado no cron do host — o agendamento é o passo 6 (HA).

### Passo 6 — Automação no Home Assistant ✅
Concluído **2026-09-18**:
- Após OneDrive OK (webhook) ou fallback terça 07:00: liga `switch.escritorio_servidor_minipc_tasmota` → espera 5 min → `POST :8787/proxmox-reserva`
- Script publica MQTT (`homelab/proxmox_reserva/estado` + `ultimo`) e webhooks; desliga o host `.30`
- Painel / badge: `sensor.sistema_proxmox_reserva_linha` + contagem em `sensor.sistema_docker_backup_problemas` (alerta > 9 dias ou erro)
- Telegram: falha (MQTT sync / watchdog 12h) e verificação diária 09:00 se `problemas > 0`
- Tomada desligada no fim (MQTT sync + webhook de registo)

### Passo 7 — Guia de emergência ✅
Concluído **2026-09-18**:
- Documento: `docs/PROXMOX-RESERVA-EMERGENCIA.md`
- Desligar principal → mover SSD 1 TB → ligar reserva (`.30`) → storage `Backup-1TB` + `scsi2` na VM 100 → subir **101 (HA)** depois **100 (Docker)** → checklist de IPs/serviços
- Script de renumerar IPs do hypervisor = fase 2 (não bloqueia o failover manual)

## Lembretes

- Primeira cópia = pesada; depois = só o que mudou
- Nunca as mesmas VMs a correr nos dois PCs ao mesmo tempo
- RAM: ambos 16 GB — compatível, mas apertado (8+6 GB nas VMs)

## Fora desta fase

- Copiar o SSD pela rede
- Failover automático
- Script de mudar IPs sozinho
