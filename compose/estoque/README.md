# Estoque

Instância própria do [Controle-de-Estoque](https://github.com/Aeron-Engenharia/Controle-de-Estoque). Não partilha base com o servidor da Aeron.

| | |
|--|--|
| Código | `/opt/controle-estoque` (clone read-only) |
| Compose | esta pasta |
| LAN | http://192.168.3.21:3011 |
| HTTPS | https://estoque.antonio.rafael.nom.br |
| Login inicial | `ADMIN_EMAIL` / `ADMIN_PASSWORD` no `.env` (chmod 600) |

Actualizar código:

```bash
/root/homelab/compose/estoque/rebuild.sh
```

O front usa `VITE_API_URL=/` (mesmo origin). O `nginx.conf` lista os prefixos da API
(`auth`, `users`, `items`, `locations`, `location-kinds`, `settings`, …). Se o backend ganhar um
prefixo novo e ele não estiver nessa lista, a UI recebe o `index.html` do SPA
(lista vazia / criar falha). O `rebuild.sh` faz smoke test disso.

Imagens locais (`homelab/estoque-*`); o WUD não as segue.
