# Docker

Easy!Appointments oferece suporte completo ao Docker para ambientes de desenvolvimento e produção, com scripts automatizados de gerenciamento que simplificam todo o processo.

## 📋 Visão Geral

O projeto fornece **dois ambientes Docker distintos**:

- **Desenvolvimento** (`docker-compose.dev.yml`) - Para desenvolvimento local com hot-reload
- **Produção** (`docker-compose.yml`) - Para deploy em servidores com otimizações de performance

Ambos os ambientes são gerenciados por scripts dedicados que automatizam setup, configuração e manutenção.

---

## 🚀 Início Rápido

### Desenvolvimento Local

Para iniciar o ambiente de desenvolvimento:

```bash
# 1. Copie o arquivo de exemplo (primeira vez)
cp .env-dev.example .env-dev

# 2. Inicie o ambiente completo
./deploy/deploy-development.sh up

# 3. Acesse a aplicação
# http://localhost - Aplicação
# http://localhost:8025 - Mailpit (emails)
```

O script `deploy-development.sh` automaticamente:
- ✅ Valida pré-requisitos
- ✅ Configura banco de dados
- ✅ Instala dependências Composer
- ✅ Aguarda serviços ficarem saudáveis
- ✅ Exibe URLs e credenciais de acesso

**📖 Documentação completa**: [DEV-QUICKSTART.md](../DEV-QUICKSTART.md)

### Produção

Para deploy em produção:

```bash
# 1. No servidor, faça o primeiro setup
sudo ./deploy/deploy-production.sh up --initial

# 2. Para atualizações futuras
sudo ./deploy/deploy-production.sh update
```

O script `deploy-production.sh` gerencia:
- ✅ Backup automático antes de updates
- ✅ Pull de novas imagens do GHCR
- ✅ Health checks pós-deploy
- ✅ Migrations automáticas
- ✅ Smoke tests de validação

**📖 Documentação completa**: [PRODUCTION-README.md](../PRODUCTION-README.md)

---

## 🏗️ Arquitetura Docker

### Ambiente de Desenvolvimento

**Compose**: `docker-compose.dev.yml`  
**Env**: `.env-dev`

**Serviços disponíveis**:
- `mysql` - Banco de dados MySQL 8.0
- `php-fpm` - PHP 8.3 com Xdebug e hot-reload
- `nginx` - Servidor web com reload automático
- `mailpit` - Captura de e-mails (UI em http://localhost:8025)
- `logrotate` - Rotação automática de logs

**Volumes bind mount**: Código local é montado diretamente para hot-reload instantâneo.

### Ambiente de Produção

**Compose**: `docker-compose.yml` (gerado a partir de `docker-compose-example.yml`)  
**Env**: `.env-prod`

**Serviços disponíveis**:
- `mysql` - MySQL otimizado para produção
- `php-fpm` - PHP com OPcache e otimizações
- `nginx` - Nginx com cache e compressão
- `whatsapp-worker` - Worker para integração WhatsApp
- `logrotate` - Rotação de logs de produção

**Imagens pré-compiladas**: Assets e vendor incluídos na imagem Docker (sem build em produção).

---

## 🔧 Comandos Úteis

### Desenvolvimento

```bash
# Iniciar ambiente
./deploy/deploy-development.sh up

# Parar ambiente
./deploy/deploy-development.sh down

# Ver logs em tempo real
./deploy/deploy-development.sh logs -f

# Verificar saúde dos serviços
./deploy/deploy-development.sh health

# Reiniciar ambiente
./deploy/deploy-development.sh restart

# Limpar completamente (remove volumes)
./deploy/deploy-development.sh clean

# Rebuild completo das imagens
./deploy/deploy-development.sh rebuild

# Shell no container PHP
./deploy/deploy-development.sh shell
```

### Produção

```bash
# Setup inicial (primeira vez)
sudo ./deploy/deploy-production.sh up --initial

# Iniciar serviços
sudo ./deploy/deploy-production.sh up

# Parar serviços
sudo ./deploy/deploy-production.sh down

# Atualizar aplicação (com backup automático)
sudo ./deploy/deploy-production.sh update

# Criar backup manual
sudo ./deploy/deploy-production.sh backup

# Validar imagem antes do deploy
./deploy/deploy-production.sh smoke-test

# Ver logs
./deploy/deploy-production.sh logs -f

# Verificar saúde
./deploy/deploy-production.sh health
```

---

## 🌐 URLs e Portas

### Desenvolvimento (Padrão)

| Serviço | URL | Descrição |
|---------|-----|-----------|
| Aplicação | http://localhost | Interface principal |
| Mailpit | http://localhost:8025 | Captura de e-mails |
| MySQL | localhost:3306 | Banco de dados |

**Credenciais padrão** (definidas em `.env-dev`):
- **Database**: `easyappointments` 
- **User**: `easyappointments`
- **Password**: `secret`
- **Root Password**: `root`

### Produção (Configurável)

As portas são configuradas durante o setup inicial com `--initial`:
- Você será solicitado a definir a porta HTTP (padrão: 80)
- MySQL fica exposto apenas internamente na rede Docker
- Credenciais são geradas automaticamente

---

## 🐳 Build de Imagens

### Imagem de Produção

Para buildar a imagem multi-plataforma (AMD64 + ARM64):

```bash
# Build completo com push para GHCR
./build-multiplatform-local-dev.sh
```

Este script:
- ✅ Valida pré-requisitos do projeto
- ✅ Compila assets dentro da imagem
- ✅ Instala vendor otimizado
- ✅ Suporta AMD64 e ARM64
- ✅ Faz push automático para GitHub Container Registry
- ✅ Valida imagens geradas

**Registry**: `ghcr.io/alexzerabr/easyappointments`

---

## 🔍 Troubleshooting

### Desenvolvimento

**Problema**: Aplicação não carrega
```bash
# Verifique logs
./deploy/deploy-development.sh logs

# Verifique health
./deploy/deploy-development.sh health

# Reinicie limpo
./deploy/deploy-development.sh clean
./deploy/deploy-development.sh up
```

**Problema**: Permissões negadas
```bash
# Ajuste permissões dos volumes
sudo chown -R $USER:$USER storage/ docker/mysql-dev/
```

### Produção

**Problema**: Deploy falhou
```bash
# Verifique logs
./deploy/deploy-production.sh logs

# Teste a imagem primeiro
./deploy/deploy-production.sh smoke-test

# Restaure último backup
# (Localizado em /srv/easyappointments/backups/)
```

**Problema**: Banco não conecta
```bash
# Verifique status do MySQL
docker compose ps mysql

# Verifique credenciais no .env-prod (produção) ou .env-dev (desenvolvimento)
cat .env-prod | grep DATABASE
```

---

## 📦 Serviços Adicionais (Desenvolvimento)

### Baikal (CalDAV)

Para testar integração CalDAV:

```bash
# Acesse: http://localhost:8100
# Credenciais: admin / admin

# 1. Crie um usuário no Baikal
# 2. Configure CalDAV no Easy!Appointments
# 3. Use URL: http://baikal/dav.php
```

### OpenLDAP

Para testar autenticação LDAP:

```bash
# Acesse phpLDAPadmin: http://localhost:8200
# Credenciais: cn=admin,dc=example,dc=org / admin

# Configure LDAP no Easy!Appointments
# Host: openldap
# Port: 389
```

**📖 Mais detalhes**: [docs/ldap.md](ldap.md) | [docs/caldav-calendar-sync.md](caldav-calendar-sync.md)

---

## ⚠️ Notas Importantes

### Desenvolvimento
- **Não usar em produção**: Configurações de desenvolvimento incluem Xdebug, debug habilitado, e credenciais simples
- **Hot-reload**: Código local é montado como volume - mudanças são aplicadas instantaneamente
- **Performance**: Mais lento que produção devido a debug e falta de cache

### Produção
- **Nunca expor .env-prod**: Contém credenciais sensíveis
- **Backups automáticos**: Sempre feitos antes de updates
- **Assets pré-compilados**: Imagem já contém tudo pronto (sem build em produção)
- **Smoke tests**: Sempre recomendado testar imagem antes do deploy

---

## 🔗 Links Úteis

- 📖 [Guia Rápido - Desenvolvimento](../DEV-QUICKSTART.md)
- 📖 [Guia Completo - Produção](../PRODUCTION-README.md)
- 📖 [Resumo de Deploy Dev](../DEPLOYMENT-DEV-SUMMARY.md)
- 📖 [Cheatsheet de Produção](../PRODUCTION-CHEATSHEET.md)
- 🔧 [Análise da Pipeline](../ANALISE-DOCKER-BUILD-PIPELINE.md)

---

**⚡ Versão da Documentação**: 2.0  
**📅 Última Atualização**: Outubro 2025

[Voltar](readme.md)
