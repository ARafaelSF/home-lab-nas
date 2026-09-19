# Estudo RF UniFi (2.4 GHz / min. rate)

Grava sinal e tx/rx dos clientes wireless. Serve para decidir se o min. rate 2.4 pode subir de 1 Mbps para 6 Mbps.

**Estado:** encerrado (2026-09-19). O loop a cada 10 min já não corre; amostras apagadas. Min. rate mantém-se a 1 Mbps.

Credenciais: `compose/unifi-mcp/.env` (não está no git).  
Amostras: `data/clients.jsonl` (gitignored).

Snapshot pontual:

```bash
python3 /root/homelab/scripts/unifi-rf-study/snapshot.py
```

Loop (só se reabrir o estudo):

```bash
nohup bash -c 'while true; do sleep 600; python3 /root/homelab/scripts/unifi-rf-study/snapshot.py; done' \
  >> /root/homelab/scripts/unifi-rf-study/data/collector.log 2>&1 &
```
