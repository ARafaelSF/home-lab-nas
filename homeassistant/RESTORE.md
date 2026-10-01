# Home Assistant — restauração e arquivos auxiliares

A configuração oficial do Home Assistant é mantida no repositório separado `home-assistant-casa`. `/root/homelab` não é mais o espelho da configuração principal do HA.

## Restaurar no HA (`/config`)

1. Obter a configuração oficial no repositório `home-assistant-casa` e seguir as instruções de restauração de lá para `/config`.
2. Restaurar as credenciais a partir do backup seguro correspondente (`secrets.yaml` não é mantido aqui).
3. Garantir pastas: `themes/`, `packages/`.
4. Em Developer Tools → YAML → Check configuration → Reiniciar.

## Porque isto existe

Arquivos auxiliares do HA que tenham dependência real do homelab podem continuar neste repositório; a restauração da configuração principal deve usar `home-assistant-casa`.
