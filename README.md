# 🚀 EasyAppointments + WPPConnect Integration

> **Sistema completo de agendamentos com integração WhatsApp via WPPConnect**

[![Docker Build](https://github.com/alexzerabr/easyappointments/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/alexzerabr/easyappointments/actions/workflows/build-and-push.yml)
[![Docker Pulls](https://img.shields.io/badge/docker-ghcr.io-blue)](https://ghcr.io/alexzerabr/easyappointments)
[![License](https://img.shields.io/badge/license-GPL--3.0-green)](LICENSE)

## 📋 **Índice**

- [Sobre o Projeto](#sobre-o-projeto)
- [Início Rápido](#início-rápido)
- [Fluxo de Desenvolvimento](#fluxo-de-desenvolvimento)
- [Processo de Atualização](#processo-de-atualização)
- [Deploy em Produção](#deploy-em-produção)
- [Contribuindo](#contribuindo)

---

## 🎯 **Sobre o Projeto**

Este é um **fork avançado** do EasyAppointments com integração completa do **WPPConnect** para envio de mensagens WhatsApp. O projeto inclui:

- ✅ **Sistema de agendamentos** completo e responsivo
- 📱 **Integração WhatsApp** via WPPConnect
- 🐳 **Containerização completa** com Docker
- 🚀 **Deploy automatizado** com um comando
- 🔐 **Segurança avançada** com credenciais auto-geradas
- 🌍 **Multi-arquitetura** (AMD64 + ARM64)

---

## ⚡ **Início Rápido**

### **Pré-requisitos**
- 🐳 **Docker** (20.10+)
- 🔧 **Docker Compose** (v2.0+)
- 🌐 **Git**

### **Deploy em 30 segundos**
```bash
# 1. Clone o repositório
git clone https://github.com/alexzerabr/easyappointments.git
cd easyappointments

# 2. Execute o deploy (gera tudo automaticamente!)
./deploy/deploy-production.sh --start

# 3. Acesse a aplicação
open http://localhost/index.php/installation
```

**🎉 Pronto!** O sistema estará rodando com:
- ✅ Credenciais geradas automaticamente
- ✅ Banco de dados configurado
- ✅ WhatsApp integration pronta
- ✅ Todos os containers funcionando

---

## 🔄 **Fluxo de Desenvolvimento**

### **1. Setup do Ambiente**

```bash
# Clone e entre no diretório
git clone https://github.com/alexzerabr/easyappointments.git
cd easyappointments

# Inicie o ambiente de desenvolvimento
docker compose up -d

# Acesse a aplicação
open http://localhost
```

### **2. Workflow de Desenvolvimento**

```bash
# 1. Criar branch para feature
git checkout -b feature/nova-funcionalidade

# 2. Desenvolver e testar localmente
docker compose up -d
# ... fazer alterações ...

# 3. Commit e push
git add .
git commit -m "feat: adiciona nova funcionalidade WhatsApp"
git push origin feature/nova-funcionalidade

# 4. GitHub Actions irá automaticamente:
# - ✅ Fazer build das imagens
# - ✅ Executar testes de segurança
# - ✅ Publicar no GHCR
```

---

## 🔄 **Processo de Atualização (Como Atualizar Imagens)**

### **Cenário 1: Alteração de Código (Automático)**

```bash
# 1. Faça suas alterações
vim application/controllers/Appointments.php

# 2. Commit e push
git add .
git commit -m "feat: melhoria na integração WhatsApp"
git push origin whatsapp-integration

# 3. 🤖 GitHub Actions executa automaticamente:
#    ⏳ Build multi-arquitetura (~5-10 min)
#    📦 Push para ghcr.io/alexzerabr/easyappointments:latest
#    🛡️ Scan de vulnerabilidades
#    ✅ Imagem disponível para deploy

# 4. Deploy da nova versão
./deploy/deploy-production.sh --start
# ✅ Puxa automaticamente a imagem mais recente
```

### **Cenário 2: Release com Versão**

```bash
# 1. Criar tag de versão
git tag v1.1.0
git push origin v1.1.0

# 2. 🤖 GitHub Actions cria automaticamente:
#    📦 ghcr.io/alexzerabr/easyappointments:v1.1.0
#    📦 ghcr.io/alexzerabr/easyappointments:latest (atualizada)
```

### **Cenário 3: Build Manual (Emergência)**

```bash
# Para casos de emergência
export GH_OWNER="alexzerabr"
export GHCR_TOKEN="ghp_xxxxxxxxxxxx"
./scripts/manual-build-push.sh
```

---

## 🎯 **Fluxo Completo de Trabalho**

**🔄 Desenvolvimento → Produção em 6 Passos:**

```bash
# PASSO 1: Setup inicial (uma vez)
git clone https://github.com/alexzerabr/easyappointments.git
cd easyappointments

# PASSO 2: Desenvolvimento local
docker compose up -d
# ... desenvolver features ...

# PASSO 3: Commit e push
git add .
git commit -m "feat: integração WhatsApp melhorada"
git push origin whatsapp-integration
# ⏳ Aguardar GitHub Actions (5-10 min)

# PASSO 4: Deploy em produção
./deploy/deploy-production.sh --start
# 🤖 Script automaticamente:
# - Puxa imagem mais recente
# - Gera credenciais seguras
# - Configura ambiente
# - Inicia todos os serviços

# PASSO 5: Verificação
curl -I http://localhost/index.php/installation
# ✅ HTTP/1.1 200 OK
```

---

## 🚀 **Deploy em Produção**

### **Deploy Automatizado**

```bash
# Um comando faz tudo!
./deploy/deploy-production.sh --start

# O script automaticamente:
# ✅ Gera credenciais seguras
# ✅ Cria arquivo .env.production
# ✅ Puxa imagem do GHCR
# ✅ Configura config.php
# ✅ Inicia containers
```

### **Comandos Úteis**

```bash
# Status dos containers
docker compose -f docker-compose.prod.yml ps

# Logs da aplicação
docker compose -f docker-compose.prod.yml logs php-fpm

# Parar ambiente
./deploy/deploy-production.sh --stop

# Backup dos dados
./deploy/deploy-production.sh --backup
```

---

## 🤝 **Contribuindo**

1. **Fork** o projeto
2. **Crie** uma branch: `git checkout -b feature/nova-feature`
3. **Commit**: `git commit -m "feat: adiciona nova feature"`
4. **Push**: `git push origin feature/nova-feature`
5. **Abra** um Pull Request

---

## 📚 **Documentação**

- 📖 **[GHCR Guide](README-GHCR.md)** - Guia do GitHub Container Registry
- 🏗️ **[Build Commands](build-commands.md)** - Comandos de build
- 🚀 **[Production README](PRODUCTION-README.md)** - Guia de produção

---

## 📄 **Licença**

GPL-3.0 License - veja [LICENSE](LICENSE) para detalhes.

---

<div align="center">

**🚀 Feito com ❤️ por [alexzerabr](https://github.com/alexzerabr)**

</div>