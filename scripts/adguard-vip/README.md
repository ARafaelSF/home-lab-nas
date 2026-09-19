# AdGuard VIP (keepalived)

IP virtual partilhado pelos dois AdGuard. O DNAT UniFi aponta sempre para este IP.

| | |
|--|--|
| VIP | `192.168.3.23` |
| Principal | `192.168.3.21` (MASTER, prioridade 150) |
| Backup | `192.168.3.22` Pi (BACKUP, prioridade 100) |
| Failover | ~2–4 s se o AdGuard local deixar de responder em `:53` |

## Onde corre

**Nos dois hosts**, não só no Pi:
- Com o principal saudável → VIP no `.21`
- Se o principal cair ou o AdGuard Docker parar → VIP passa ao Pi `.22`

## Instalar

```bash
# No NAS (.21) — como root
/root/homelab/scripts/adguard-vip/install-primary.sh

# No Pi — a partir do NAS (usa sudo no Pi)
/root/homelab/scripts/adguard-vip/install-backup.sh
```

Depois: DNAT UniFi → `192.168.3.23` (feito pelo install ou manualmente).
