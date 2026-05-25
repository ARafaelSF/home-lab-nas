# Portainer

O Portainer guarda os stacks ativos em:

```
/var/lib/docker/volumes/portainer_data/_data/compose/<id>/docker-compose.yml
```

Os IDs numéricos (`4`, `5`, `8`, …) são internos do Portainer. Este repositório usa **nomes legíveis** em `homelab/compose/<serviço>/`.

Após editar aqui, atualize o stack no Portainer ou execute:

```bash
homelab/scripts/deploy-stack.sh <serviço>
```

O volume `portainer_data` não está versionado — faça backup da UI se necessário.
