# Portainer

O Portainer guarda os stacks ativos em:

```
/var/lib/docker/volumes/portainer_data/_data/compose/<id>/docker-compose.yml
```

Os IDs numéricos (`4`, `5`, `8`, …) são internos do Portainer. Este repositório usa **nomes legíveis** em `homelab/compose/<serviço>/`.

Mapeamento ID → serviço: `config/portainer/stacks-map.json`

## Erro «Could not get the contents of docker-compose.yml»

Os ficheiros no volume `portainer_data` foram apagados ou nunca sincronizados. Restaurar a partir do Git:

```bash
sudo /root/homelab/scripts/sync-portainer-compose.sh
docker restart portainer
```

Recupera também `.env` em falta (stacks 4, 8, 25, 26) a partir dos containers em execução ou `stack.env.bak` (Immich).

## Fluxo de trabalho

1. Editar `homelab/compose/<serviço>/docker-compose.yml` (fonte versionada)
2. `sync-portainer-compose.sh` **ou** colar na UI do Portainer
3. **Update the stack** no Portainer (ou `deploy-stack.sh` para stacks só CLI)

Stacks só CLI (ex.: `glances`, `homepage`, `portainer`): ver README em `compose/<serviço>/`.

O volume `portainer_data` não está versionado — faça backup da UI se necessário.
