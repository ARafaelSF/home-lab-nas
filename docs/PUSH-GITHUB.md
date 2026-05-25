# Publicar no GitHub

Repositório: https://github.com/ARafaelSF/home-lab-nas

## 1. Adicionar Deploy Key (uma vez)

1. Abra **Settings → Deploy keys → Add deploy key**
2. Title: `docker-vm-192.168.3.21`
3. Cole a chave pública:

```bash
cat /root/.ssh/home_lab_nas_deploy.pub
```

4. Marque **Allow write access** → Add key

## 2. Push

```bash
cd /root/homelab
git push -u origin main
```

O commit inicial já foi criado localmente (`30c0cfd` ou posterior).

## Alternativa: HTTPS + token

```bash
gh auth login
cd /root/homelab
git remote set-url origin https://github.com/ARafaelSF/home-lab-nas.git
git push -u origin main
```
