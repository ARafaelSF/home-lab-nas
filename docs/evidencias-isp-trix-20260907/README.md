# Evidências ISP (Trix) — qualidade de internet

**Gerado:** 2026-09-07 11:47 -0300  
**Fonte:** Prometheus homelab (`192.168.3.21:9090`) + blackbox ICMP/HTTP  
**Dashboard:** http://192.168.3.21:3005/d/internet-quality/qualidade-internet  
**Retenção Prometheus:** 90 dias  

## Método

- Probes ICMP a cada ~1 min para:
  - `192.168.3.1` (gateway LAN / UCG)
  - `1.1.1.1` e `8.8.8.8` (Internet)
- Quando a LAN responde e a Internet falha, a falha é **a montante do router** (lado ISP/WAN), não da rede interna.

## Disponibilidade ICMP (7 dias)

| Destino | Disponibilidade |
|---------|-----------------|
| Gateway LAN (192.168.3.1) | **99.834%** |
| Cloudflare 1.1.1.1 | **98.328%** |
| Google 8.8.8.8 | **97.786%** |

## Maiores falhas Internet (≥3 min) — 7 dias

| Início (local) | Fim | Destino | Duração |
|----------------|-----|---------|---------|
| 2026-09-05 11:53:09 -0300 | 2026-09-05 12:04:09 -0300 | 1.1.1.1 | 12.0 min |
| 2026-09-02 20:01:09 -0300 | 2026-09-02 20:11:09 -0300 | 1.1.1.1 | 11.0 min |
| 2026-09-05 15:43:09 -0300 | 2026-09-05 15:53:09 -0300 | 8.8.8.8 | 11.0 min |
| 2026-09-06 18:21:09 -0300 | 2026-09-06 18:31:09 -0300 | 8.8.8.8 | 11.0 min |
| 2026-09-02 20:29:09 -0300 | 2026-09-02 20:37:09 -0300 | 1.1.1.1 | 9.0 min |
| 2026-09-05 15:43:09 -0300 | 2026-09-05 15:51:09 -0300 | 1.1.1.1 | 9.0 min |
| 2026-09-05 16:08:09 -0300 | 2026-09-05 16:16:09 -0300 | 8.8.8.8 | 9.0 min |
| 2026-09-06 17:29:09 -0300 | 2026-09-06 17:37:09 -0300 | 8.8.8.8 | 9.0 min |
| 2026-09-06 17:45:09 -0300 | 2026-09-06 17:53:09 -0300 | 8.8.8.8 | 9.0 min |
| 2026-09-05 16:08:09 -0300 | 2026-09-05 16:15:09 -0300 | 1.1.1.1 | 8.0 min |
| 2026-09-02 20:30:09 -0300 | 2026-09-02 20:36:09 -0300 | 8.8.8.8 | 7.0 min |
| 2026-09-02 20:00:09 -0300 | 2026-09-02 20:05:09 -0300 | 8.8.8.8 | 6.0 min |
| 2026-09-03 17:54:09 -0300 | 2026-09-03 17:59:09 -0300 | 8.8.8.8 | 6.0 min |
| 2026-09-05 08:39:09 -0300 | 2026-09-05 08:44:09 -0300 | 8.8.8.8 | 6.0 min |
| 2026-08-31 14:56:09 -0300 | 2026-08-31 15:00:09 -0300 | 8.8.8.8 | 5.0 min |

## Ficheiros

- `resumo_disponibilidade_7d.csv` — disponibilidade por destino
- `falhas_icmp_7d.csv` — todas as janelas com `probe_success=0`
- `falhas_http_7d.csv` — falhas HTTP externos (Google/Cloudflare)
- `speedtest_amostras_7d.csv` — amostras Ookla (~6 h)
- `graficos/` — PNGs dos incidentes e visão 7 dias

## Como mostrar à Trix

1. Abrir `graficos/incidente_20260905_manha.png` e `incidente_20260905_tarde.png`
2. Destacar que a linha verde (gateway) fica a 100% enquanto 1.1.1.1/8.8.8.8 caem
3. Anexar os CSVs se pedirem dados brutos
