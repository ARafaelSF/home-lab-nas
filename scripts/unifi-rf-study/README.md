# Estudo RF UniFi (2.4 GHz / min. rate)

Grava sinal e tx/rx dos clientes wireless. Serve para decidir se o min. rate 2.4 pode subir de 1 Mbps para 6 Mbps.

Credenciais: `compose/unifi-mcp/.env` (não está no git).  
Amostras: `data/clients.jsonl` (gitignored).

```bash
python3 /root/homelab/scripts/unifi-rf-study/snapshot.py
```

Neste PC está um loop a cada 10 min (~48 h a partir de 2026-09-08 21:38). Para continuar mais dias:

```bash
nohup bash -c 'while true; do sleep 600; python3 /root/homelab/scripts/unifi-rf-study/snapshot.py; done' \
  >> /root/homelab/scripts/unifi-rf-study/data/collector.log 2>&1 &
```
