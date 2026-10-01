#!/bin/sh
set -eu

TS_NET="100.64.0.0/10"
LAN_IF="eth0"
NFT_CHAIN="DOCKER-USER"

for lan in 192.168.2.0/24 192.168.3.0/24 192.168.68.0/24; do
    # Docker's nftables FORWARD policy is DROP; DOCKER-USER is evaluated first.
    iptables -w 10 -C "$NFT_CHAIN" -i tailscale0 -o "$LAN_IF" -s "$TS_NET" -d "$lan" -j ACCEPT 2>/dev/null || \
        iptables -w 10 -I "$NFT_CHAIN" 1 -i tailscale0 -o "$LAN_IF" -s "$TS_NET" -d "$lan" -j ACCEPT

    # Permit replies back to the originating Tailscale client.
    iptables -w 10 -C "$NFT_CHAIN" -i "$LAN_IF" -o tailscale0 -s "$lan" -d "$TS_NET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
        iptables -w 10 -I "$NFT_CHAIN" 1 -i "$LAN_IF" -o tailscale0 -s "$lan" -d "$TS_NET" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Tailscale's subnet-router SNAT is kept explicit in the legacy NAT table.
    iptables-legacy -w 10 -t nat -C POSTROUTING -s "$TS_NET" -d "$lan" -o "$LAN_IF" -j MASQUERADE 2>/dev/null || \
        iptables-legacy -w 10 -t nat -I POSTROUTING 1 -s "$TS_NET" -d "$lan" -o "$LAN_IF" -j MASQUERADE
done
