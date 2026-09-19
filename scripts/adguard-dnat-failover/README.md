# AdGuard DNAT failover (legado)

Este serviço **foi desactivado** em 2026-09-19.

Motivo: o DNAT UniFi só aceita **um** IP de destino. Em vez de polling + troca (espera ~60 s), o alvo DNAT passou a ser **fixo** no Pi `192.168.3.22`. Ver `docs/ADGUARD-DNS-REMOTO.md`.

O desenho ideal continua a ser um **VIP** (`192.168.3.23` + keepalived em `.21` e `.22`); falta `sudo` no Pi para instalar o keepalived.
