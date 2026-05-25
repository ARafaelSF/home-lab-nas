# Correção roteamento VM Docker ↔ LAN 192.168.68.x

## Problema

Redes Docker em `192.168.x.0/20` faziam o kernel enviar respostas para clientes `192.168.68.x` por bridges mortas → sem SSH/Portainer pela LAN.

## Correção aplicada

1. `/etc/network/if-up.d/route-lan68` — rota `192.168.68.0/24 via 192.168.3.1 dev eth0`
2. Remoção de redes Docker órfãs `192.168.*`
3. `/etc/docker/daemon.json` — `default-address-pools`: `172.40.0.0/16`

## Verificação

```bash
ip route get 192.168.68.181   # deve: dev eth0
ip -4 route | grep 192.168    # sem 192.168.64.0/20 em bridge docker
```

Ficheiros no repo: `etc/docker/daemon.json`, `etc/network/if-up.d/route-lan68`
