# Homelab — pendências

Só o que **ainda falta**. Quando concluir, apague o item.

**Servidor:** VM Docker `192.168.3.21`  
**Atualizado:** 2026-07-10

---

## Immich: Redis → Valkey (opcional / quando atualizar a sério)

Hoje o Immich usa `redis:6.2`. Nas releases novas o projeto oficial passou a recomendar **Valkey** no lugar do Redis.

**Vantagem:** alinhar com o compose oficial (menos surpresas em updates futuros), suporte/manutenção alinhados ao Immich. **Não melhora fotos nem velocidade** no dia a dia.

**Precisa agora?** Não. O teu stack está estável. Só faz sentido no próximo upgrade grande do Immich (server + ML + DB + redis/valkey juntos).

- [ ] Quando fores atualizar o Immich “a sério”, seguir o compose da [release oficial](https://github.com/immich-app/immich/releases) (Valkey incluso)
- [ ] Teste login/upload OK

---

## Arquivos úteis

| Arquivo | Uso |
|---------|-----|
| `/root/homelab/README.md` | Índice |
| `docs/SERVIDOR-HOMELAB.md` | Guia completo |
| `docs/DUPLICATI-BACKUP.md` | Backup |
| `/opt/container-ops/GUIA.md` | Atualizar containers |
