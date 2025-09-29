# 🐳 GitHub Container Registry (GHCR) - Guia Completo

Este guia descreve como usar as imagens Docker publicadas no GitHub Container Registry para deploy em produção do EasyAppointments com integração WPPConnect.

## 📦 **Imagens Disponíveis**

### **Imagem Principal**
- **Nome:** `ghcr.io/[GH_OWNER]/easyappointments`
- **Tags:** `latest`, `v1.0.0.0`, `main`, `whatsapp-integration`
- **Contém:** EasyAppointments + WPPConnect Integration + PHP-FPM
- **Uso:** Aplicação principal e worker WhatsApp

## 🔧 **Configuração Inicial**

### **1. Configuração (Imagens Públicas)**

**✅ Não é necessário configurar tokens ou autenticação!**

As imagens estão **públicas** no GHCR e podem ser usadas diretamente:

```bash
# As imagens são públicas - não precisa de autenticação
docker pull ghcr.io/alexzerabr/easyappointments:latest

# O deploy-production.sh gera automaticamente todas as credenciais necessárias
./deploy/deploy-production.sh --start
```

### **2. Token do GitHub**

#### **Opção A: Personal Access Token (Recomendado)**
1. Acesse: https://github.com/settings/tokens
2. Clique em "Generate new token (classic)"
3. Selecione os escopos:
   - ✅ `read:packages` (para pull)
   - ✅ `write:packages` (para push, se necessário)
4. Copie o token e adicione no `.env.production`

#### **Opção B: GitHub Actions (CI/CD)**
```yaml
# No workflow, use o GITHUB_TOKEN automático
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### **3. Login Manual**

```bash
# Login com Personal Access Token
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin

# Ou via variável de ambiente
export GHCR_TOKEN="your_token_here"
export GH_OWNER="your_username"
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin
```

## 🚀 **Deploy em Produção**

### **Deploy Automatizado (Recomendado)**

```bash
# 1. Configure as variáveis de ambiente
cp env.production-example .env.production
nano .env.production  # Ajuste GH_OWNER e GHCR_TOKEN

# 2. Execute o deploy
./deploy/deploy-production.sh --start
```

### **Deploy Manual**

```bash
# 1. Login no GHCR
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin

# 2. Pull da imagem
docker pull ghcr.io/$GH_OWNER/easyappointments:latest

# 3. Subir os serviços
docker compose -f docker-compose.prod.yml --env-file .env.production up -d
```

## 📋 **Comandos Úteis**

### **Pull de Imagens**
```bash
# Última versão
docker pull ghcr.io/$GH_OWNER/easyappointments:latest

# Versão específica
docker pull ghcr.io/$GH_OWNER/easyappointments:v1.0.0.0

# Verificar imagem local
docker image ls | grep easyappointments
```

### **Validação do Deploy**
```bash
# Status dos containers
docker compose -f docker-compose.prod.yml ps

# Logs da aplicação
docker compose -f docker-compose.prod.yml logs php-fpm

# Logs do worker WhatsApp
docker compose -f docker-compose.prod.yml logs whatsapp-worker

# Health check
curl -s http://localhost/index.php/installation
```

### **Informações da Imagem**
```bash
# Verificar labels e metadata
docker image inspect ghcr.io/$GH_OWNER/easyappointments:latest

# Data de criação e versão
docker image inspect ghcr.io/$GH_OWNER/easyappointments:latest \
  --format '{{.Created}} {{.Config.Labels}}'
```

## 🔄 **Atualizações e Rollback**

### **Atualização**
```bash
# 1. Pull da nova versão
docker pull ghcr.io/$GH_OWNER/easyappointments:latest

# 2. Recrear containers
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --force-recreate

# 3. Verificar saúde
docker compose -f docker-compose.prod.yml ps
```

### **Rollback para Versão Específica**
```bash
# 1. Editar docker-compose.prod.yml temporariamente
sed -i 's/:latest/:v1.0.0.0/g' docker-compose.prod.yml

# 2. Pull da versão anterior
docker pull ghcr.io/$GH_OWNER/easyappointments:v1.0.0.0

# 3. Recrear containers
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --force-recreate

# 4. Restaurar docker-compose.prod.yml
sed -i 's/:v1.0.0.0/:latest/g' docker-compose.prod.yml
```

## 🛠 **Troubleshooting**

### **Erro: "Failed to pull image"**
```bash
# Verificar login
docker login ghcr.io

# Verificar se a imagem existe
curl -H "Authorization: Bearer $GHCR_TOKEN" \
  https://ghcr.io/v2/$GH_OWNER/easyappointments/tags/list

# Verificar permissões
docker pull ghcr.io/$GH_OWNER/easyappointments:latest
```

### **Erro: "Authentication required"**
```bash
# Re-login
docker logout ghcr.io
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin

# Verificar token
curl -H "Authorization: Bearer $GHCR_TOKEN" https://ghcr.io/v2/
```

### **Container não inicia**
```bash
# Verificar logs
docker compose -f docker-compose.prod.yml logs php-fpm

# Verificar se a imagem foi baixada
docker image ls | grep easyappointments

# Verificar configuração
docker compose -f docker-compose.prod.yml config
```

## 📊 **Monitoramento**

### **Health Checks**
```bash
# Aplicação principal
curl -f http://localhost/index.php || echo "App down"

# Worker WhatsApp
docker compose -f docker-compose.prod.yml exec whatsapp-worker ps aux | grep php

# MySQL
docker compose -f docker-compose.prod.yml exec mysql mysqladmin ping
```

### **Logs Centralizados**
```bash
# Todos os serviços
docker compose -f docker-compose.prod.yml logs -f

# Apenas aplicação
docker compose -f docker-compose.prod.yml logs -f php-fpm whatsapp-worker

# Com timestamp
docker compose -f docker-compose.prod.yml logs -f -t
```

## 🔒 **Segurança**

### **Boas Práticas**
- ✅ Use tokens com escopo mínimo necessário (`read:packages`)
- ✅ Armazene tokens em variáveis de ambiente, nunca no código
- ✅ Rotacione tokens regularmente
- ✅ Use imagens com tags específicas em produção quando possível
- ✅ Monitore vulnerabilidades com ferramentas como Trivy

### **Limpeza de Credenciais**
```bash
# Remover login local
docker logout ghcr.io

# Limpar variáveis de ambiente
unset GHCR_TOKEN
unset GH_OWNER
```

## 📈 **Automação Avançada**

### **Script de Deploy com Rollback Automático**
```bash
#!/bin/bash
OLD_IMAGE=$(docker compose -f docker-compose.prod.yml images -q php-fpm)
./deploy/deploy-production.sh --start

# Health check
if ! curl -f http://localhost/index.php/installation; then
    echo "Deploy failed, rolling back..."
    docker tag $OLD_IMAGE ghcr.io/$GH_OWNER/easyappointments:rollback
    docker compose -f docker-compose.prod.yml up -d --force-recreate
fi
```

### **Monitoramento Contínuo**
```bash
# Cron job para verificar atualizações (diário)
0 2 * * * /path/to/check-updates.sh

# check-updates.sh
#!/bin/bash
CURRENT=$(docker image ls --format "{{.ID}}" ghcr.io/$GH_OWNER/easyappointments:latest)
docker pull ghcr.io/$GH_OWNER/easyappointments:latest
NEW=$(docker image ls --format "{{.ID}}" ghcr.io/$GH_OWNER/easyappointments:latest)

if [ "$CURRENT" != "$NEW" ]; then
    echo "New image available, consider updating production"
    # Opcional: notificação por email/slack
fi
```

---

## 🆘 **Suporte**

Para problemas específicos:
1. Verifique os logs: `docker compose logs`
2. Confirme as configurações: `docker compose config`
3. Teste conectividade: `curl -I http://localhost`
4. Verifique recursos: `docker system df`

**Links Úteis:**
- [GitHub Packages Documentation](https://docs.github.com/en/packages)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [EasyAppointments Documentation](https://easyappointments.org/docs.html)
