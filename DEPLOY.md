# 🚀 Guia de Deploy - EasyAppointments

> **Guia unificado de deploy para ambientes de produção e desenvolvimento**

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Produção](#produção)
  - [Início Rápido](#início-rápido-produção)
  - [Comandos Principais](#comandos-principais-produção)
  - [Configuração Avançada](#configuração-avançada)
  - [Troubleshooting](#troubleshooting-produção)
- [Desenvolvimento](#desenvolvimento)
  - [Início Rápido](#início-rápido-desenvolvimento)
  - [Comandos Principais](#comandos-principais-desenvolvimento)
  - [Troubleshooting](#troubleshooting-desenvolvimento)
- [Docker](#docker)
- [Referências](#referências)

---

## 🎯 Visão Geral

Este documento consolida toda a documentação de deploy do EasyAppointments, incluindo:
- ✅ **Produção**: Deploy automatizado com segurança enterprise
- ✅ **Desenvolvimento**: Setup local rápido para desenvolvimento
- ✅ **Docker**: Ambos os ambientes são containerizados

**Ambientes Isolados**: Produção e desenvolvimento podem rodar simultaneamente sem conflitos.

---

# 🏭 Produção

## 📦 Início Rápido (Produção)

### Instalação Completa em Um Comando

```bash
cd /home/alexzera/Projects/easyappointments
sudo ./deploy/deploy-production.sh up --initial
```

**O script fará automaticamente:**
1. ✅ Gerar credenciais seguras
2. ✅ Solicitar portas HTTP/HTTPS
3. ✅ Criar estrutura de diretórios
4. ✅ Configurar ambiente
5. ✅ Iniciar todos os serviços
6. ✅ Executar health checks
7. ✅ Exibir URLs de acesso

**Tempo estimado:** 2-3 minutos

### O Que Você Verá

```
═══════════════════════════════════════════════════════════
   🔐 CREDENCIAIS GERADAS - SALVE COM SEGURANÇA!
═══════════════════════════════════════════════════════════
Database Password:        xK8mL2pQ9vR4nT6wY1zA
MySQL Root Password:      aB3cD4eF5gH6iJ7kL8mN9oP0qR1sT2u
WhatsApp Encryption Key:  f8e7d6c5b4a3210987654321fedcba98...
Backup Encryption Key:    1234567890abcdef1234567890abcdef...
═══════════════════════════════════════════════════════════

🌐 URLs de Acesso:
   Instalação: http://localhost/index.php/installation
   Aplicação:  http://localhost
```

### Próximos Passos

1. Acesse: `http://seu-servidor/index.php/installation`
2. Use as credenciais exibidas
3. Complete o wizard de instalação

---

## 📖 Comandos Principais (Produção)

### Operações Diárias

```bash
# Iniciar ambiente
sudo ./deploy/deploy-production.sh up

# Parar ambiente
sudo ./deploy/deploy-production.sh down

# Verificar saúde
./deploy/deploy-production.sh health

# Ver logs em tempo real
./deploy/deploy-production.sh logs -f

# Ver logs de serviço específico
./deploy/deploy-production.sh logs nginx
./deploy/deploy-production.sh logs php-fpm
./deploy/deploy-production.sh logs mysql
```

### Manutenção

```bash
# Atualizar aplicação (com backup automático)
sudo ./deploy/deploy-production.sh update

# Criar backup manual
sudo ./deploy/deploy-production.sh backup

# Validar imagem Docker antes do deploy
./deploy/deploy-production.sh smoke-test

# Ver informações da versão atual
./deploy/deploy-production.sh image-info

# Verificar atualizações disponíveis
./deploy/deploy-production.sh check-updates
```

### Ajuda

```bash
# Mostrar todos os comandos disponíveis
./deploy/deploy-production.sh help
```

---

## ⚙️ Configuração Avançada

### Arquivos de Configuração

| Arquivo | Localização | Propósito |
|---------|-------------|-----------|
| `.env-prod` | Raiz do projeto | Variáveis de ambiente (produção) |
| `.env-dev` | Raiz do projeto | Variáveis de ambiente (desenvolvimento) |
| `config.php` | Raiz do projeto | Configuração da aplicação |
| `docker-compose.yml` | Raiz do projeto | Orquestração Docker |

**⚠️ Importante:** Arquivos `.env-prod`, `.env-dev` e `config.php` contêm credenciais sensíveis!

### Localizações de Dados

| Tipo | Localização |
|------|-------------|
| **Backups** | `/srv/easyappointments/backups/` |
| **Logs** | `/srv/easyappointments/logs/` |
| **Config** | `/srv/easyappointments/config/` |

### Containers e Volumes

**Containers:**
- `easyappointments-php-fpm`
- `easyappointments-nginx`
- `easyappointments-mysql`
- `easyappointments-whatsapp-worker`
- `easyappointments-logrotate`

**Volumes:**
- `ea_mysql_data` - Dados do MySQL
- `ea_storage` - Uploads e sessões
- `ea_assets` - Assets compilados

### Isolamento de Ambientes

| Aspecto | Desenvolvimento | Produção |
|---------|----------------|----------|
| **Project Name** | `easyappointments` | `easyappointments_prod` |
| **Containers** | `ea-*` | `easyappointments-*` |
| **Volumes** | (default) | `ea_*` |
| **HTTP Port** | 8080 | 80 |
| **HTTPS Port** | 8443 | 443 |

**✅ Sem conflitos:** Ambos podem rodar simultaneamente!

---

## 🔧 Troubleshooting (Produção)

### Problema: Serviço não inicia

```bash
# Verificar logs
./deploy/deploy-production.sh logs

# Verificar saúde
./deploy/deploy-production.sh health

# Verificar Docker daemon
sudo systemctl status docker

# Verificar recursos
docker system df
df -h
```

### Problema: Erro de conexão com banco

```bash
# Verificar MySQL
docker inspect easyappointments-mysql --format='{{.State.Health.Status}}'

# Testar conexão
docker exec -it easyappointments-mysql mysql \
  -u easyapp_user -p easyappointments
```

### Problema: Aplicação não responde

```bash
# Verificar endpoints
curl -I http://localhost/

# Verificar logs nginx
./deploy/deploy-production.sh logs nginx

# Verificar logs PHP
./deploy/deploy-production.sh logs php-fpm

# Restart completo
sudo ./deploy/deploy-production.sh down
sudo ./deploy/deploy-production.sh up
```

### Problema: Permissões

```bash
# Ajustar permissões de storage
docker exec -u root easyappointments-php-fpm \
  chown -R appuser:appuser /var/www/html/storage
```

### Restaurar Backup

```bash
# Parar serviços
sudo ./deploy/deploy-production.sh down

# Restaurar database
cd /srv/easyappointments/backups/backup_[timestamp]
gunzip < database.sql.gz | \
  docker exec -i easyappointments-mysql \
  mysql -u root -p[MYSQL_ROOT_PASSWORD] easyappointments

# Iniciar serviços
sudo ./deploy/deploy-production.sh up
```

---

# 💻 Desenvolvimento

## 🚀 Início Rápido (Desenvolvimento)

### Setup em 2 Comandos

```bash
# 1. Iniciar ambiente completo
./deploy/deploy-development.sh up

# 2. Acessar aplicação
# http://localhost/index.php/installation
```

**O script fará automaticamente:**
- ✅ Validar pré-requisitos
- ✅ Configurar banco de dados
- ✅ Instalar dependências Composer
- ✅ Aguardar serviços ficarem saudáveis
- ✅ Exibir URLs e credenciais

**Tempo estimado:** ~1 minuto

### Credenciais Padrão

Use estas credenciais no wizard de instalação:

```
Host:     localhost
Database: easyappointments
Usuário:  user
Senha:    password
```

⚠️ **Importante:** Credenciais inseguras - **APENAS para desenvolvimento!**

### URLs de Acesso

| Serviço | URL | Descrição |
|---------|-----|-----------|
| **Aplicação** | http://localhost | Interface principal |
| **Instalação** | http://localhost/index.php/installation | Wizard |
| **Mailpit** | http://localhost:8025 | Captura de emails |

---

## 📖 Comandos Principais (Desenvolvimento)

### Operações Diárias

```bash
# Iniciar ambiente
./deploy/deploy-development.sh up

# Parar ambiente (preserva dados)
./deploy/deploy-development.sh down

# Verificar saúde
./deploy/deploy-development.sh health

# Ver logs
./deploy/deploy-development.sh logs -f

# Reiniciar
./deploy/deploy-development.sh restart

# Shell no container PHP
./deploy/deploy-development.sh shell
```

### Limpeza e Reset

```bash
# Limpar TUDO e reiniciar do zero
./deploy/deploy-development.sh clean
# Digite 'LIMPAR' para confirmar

# Rebuild completo das imagens
./deploy/deploy-development.sh rebuild
```

### Comandos Docker Diretos

```bash
# Status dos containers
docker compose -f docker-compose.dev.yml ps

# Logs de serviço específico
docker compose -f docker-compose.dev.yml logs mysql
docker compose -f docker-compose.dev.yml logs php-fpm
docker compose -f docker-compose.dev.yml logs nginx

# Parar todos
docker compose -f docker-compose.dev.yml down
```

---

## 🔧 Troubleshooting (Desenvolvimento)

### Problema: Porta 80 já em uso

```bash
# Opção 1: Parar serviço que está usando a porta
sudo netstat -tlnp | grep :80
sudo systemctl stop apache2  # ou nginx

# Opção 2: Editar docker-compose.dev.yml para usar outra porta
```

### Problema: MySQL não inicia

```bash
# Verificar logs
./deploy/deploy-development.sh logs mysql

# Limpar e reiniciar
./deploy/deploy-development.sh clean
./deploy/deploy-development.sh up
```

### Problema: Página retorna erro 500

```bash
# Verificar logs
./deploy/deploy-development.sh logs nginx
./deploy/deploy-development.sh logs php-fpm

# Verificar healthcheck
./deploy/deploy-development.sh health

# Verificar permissões
sudo chown -R $USER:$USER storage/
```

### Problema: Dependências desatualizadas

```bash
# Rebuild com cache limpo
./deploy/deploy-development.sh rebuild

# Ou manualmente no container
docker compose -f docker-compose.dev.yml exec php-fpm composer install
docker compose -f docker-compose.dev.yml exec php-fpm npm install
```

---

## 🐳 Docker

Para informações detalhadas sobre a arquitetura Docker, consulte:

📖 **[docs/docker.md](docs/docker.md)** - Documentação completa Docker

**Conteúdo:**
- Arquitetura de containers
- Volumes e redes
- Build de imagens
- Troubleshooting Docker
- Serviços adicionais

---

## 🔗 Referências

### Documentação Relacionada

| Documento | Descrição |
|-----------|-----------|
| [README.md](README.md) | Visão geral do projeto |
| [BUILD.md](BUILD.md) | Guia de build e CI/CD |
| [docs/docker.md](docs/docker.md) | Documentação Docker completa |
| [docs/installation-guide.md](docs/installation-guide.md) | Instalação manual |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Guia de contribuição |

### Scripts de Deploy

| Script | Localização | Uso |
|--------|-------------|-----|
| Deploy Produção | `deploy/deploy-production.sh` | Produção |
| Deploy Desenvolvimento | `deploy/deploy-development.sh` | Desenvolvimento |

### Comandos Rápidos

```bash
# Produção
sudo ./deploy/deploy-production.sh up --initial    # Primeira vez
sudo ./deploy/deploy-production.sh up              # Start
sudo ./deploy/deploy-production.sh update          # Atualizar
./deploy/deploy-production.sh health               # Health check

# Desenvolvimento
./deploy/deploy-development.sh up                  # Start
./deploy/deploy-development.sh logs -f             # Logs
./deploy/deploy-development.sh clean               # Reset completo
```

---

## 📞 Suporte

- **Documentação**: Diretório `/docs`
- **Issues**: GitHub Issues
- **Logs Produção**: `/srv/easyappointments/logs/`
- **Logs Dev**: `./deploy/deploy-development.sh logs`

---

**Versão:** 1.0  
**Última Atualização:** Outubro 2025  
**Status:** ✅ Produção

