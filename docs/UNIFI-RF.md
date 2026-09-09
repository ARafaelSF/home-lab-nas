# UniFi RF × Zigbee — Hangar

**Aplicado:** 2026-09-08 · **Decisão pendente:** min. rate 2.4 (alguns dias de amostras)

Zigbee canal 11 (2405 MHz) e Wi-Fi 11 (2462 MHz) **não se sobrepõem**. A sobreposição real seria Zigbee 11 com **Wi-Fi 1** — esse canal fica evitado.

## Já aplicado (não reinstalar / não desfazer)

| Rádio | Escritório (U7 Pro) | Suíte (U7 Pro) |
|--------|---------------------|----------------|
| 2.4 GHz | canal **11** · 20 MHz · ~16 dBm | canal **6** · 20 MHz · ~16 dBm |
| 5 GHz | auto (estava 64 DFS · 80 MHz) | auto (estava 100 DFS · 80 MHz) |
| 6 GHz | canal **37** · **160 MHz** | canal **101** · **160 MHz** |
| Zigbee (SLZB escritório) | canal **11** — **não mudar** (re-emparelha a mesh) | |

SSIDs:

- **Aeron** — desligada. Os 3 clientes saltaram para Hangar / Hangar Multimídia.
- **Hangar Visitantes** — só **5 GHz** (já estava; telemóvel de visita).
- **Hangar Multimídia** — **mantém 2.4**. Câmeras e a maior parte dos Echo Dots dependem dele.
- **Hangar_IoT** — só 2.4 (intencional).
- **Hangar** — 2.4 + 5 + 6.

## O que NÃO fazer agora

1. **Não subir o min. rate 2.4** (hoje 1 Mbps). É da SSID inteira; não dá para excluir um Sonoff.
2. **Não mudar o canal Zigbee.**
3. **Não desligar o 2.4 do Hangar Multimídia.**
4. Uplink a 100 Mbps é **físico** (hoje no **escritório**, não na suíte) — ver `PENDENCIAS.md` §1.

## Echos no 5 GHz fraco

Cozinha (−77) e oficina (−81) **já estão no 5 GHz**. O UniFi não os empurra para o 2.4 (o *band steering* faz o contrário). Se a voz falhar: na app Alexa, esquecer o Wi-Fi e voltar a ligar ao Hangar Multimídia.

## Estudo min. rate (a correr neste PC)

Snapshots a cada 10 min → `scripts/unifi-rf-study/data/clients.jsonl` (fora do git).

```bash
python3 /root/homelab/scripts/unifi-rf-study/snapshot.py
```

Depois de **alguns dias**: ver quem vive abaixo de 6 Mbps vs. quem só cochila a 1–2 Mbps. Só então decidir se sobe o min. rate.

Candidatos (2026-09-08): alarme Tuya e luz da brinquedoteca (alto); tomada sala TV, portões, oficina, luz cozinha, AC Cecília (médio).
