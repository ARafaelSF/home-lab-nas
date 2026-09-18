# Proxmox reserva — rotina semanal

Script: `rotina-semanal.sh`

## O que faz

1. Espera a reserva (`192.168.3.30`) — ping + PBS `:8007` + SSH
2. No principal: backup snapshot das VMs **101** (HA) e **100** (Docker) → storage `pbs-reserva`
3. Na reserva: restaura com `qmrestore --force` (VMs **não** arrancam)
4. Força `onboot=0` e confirma estado `stopped`
5. Escreve relatório em `/var/log/homelab/pbs-rotina-semanal-status.json`
6. (Opcional) `--shutdown-reserva` desliga o host `.30`

O SSD Duplicati (`scsi2`) continua fora da cópia (`backup=0` no principal).

## Uso

```bash
# Validar conectividade / estado (rápido)
 /root/homelab/scripts/proxmox-reserva/rotina-semanal.sh --check

# Rotina completa (pode demorar; 1.ª restore foi ~horas)
 /root/homelab/scripts/proxmox-reserva/rotina-semanal.sh --shutdown-reserva
```

Agendamento e tomada Tasmota: ver passo 6 em `docs/PROXMOX-RESERVA-PASSO-A-PASSO.md`.

## Home Assistant (passo 6)

- Disparo: `shell_command.proxmox_reserva_rotina` → `http://192.168.3.21:8787/proxmox-reserva`
- Webhook: `proxmox_reserva_backup_result`
- Helpers: `input_datetime.sistema_proxmox_reserva_ultimo`, `input_select.sistema_proxmox_reserva_estado`
- Sensor: `sensor.sistema_proxmox_reserva_linha` (entra no badge de backups)
