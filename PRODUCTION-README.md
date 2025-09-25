# 🚀 Easy!Appointments - Ambiente de Produção v2.0

Este guia detalha como configurar e gerenciar o ambiente de produção do Easy!Appointments com Docker usando o sistema unificado de deployment.

## 📋 Pré-requisitos

- Docker Engine 20.10+
- Docker Compose V2
- Servidor Linux (Ubuntu 20.04+ recomendado)
- Domínio configurado (para HTTPS)
- Certificados SSL (recomendado)

## 📁 Estrutura do Projeto

```
easyappointments/
├── .env.production              # Arquivo de configuração de produção (raiz)
├── env.production-example       # Template de configuração
├── docker-compose.prod.yml      # Configuração Docker para produção
├── Makefile                     # Atalhos para comandos (opcional)
├── deploy/                      # Scripts de gerenciamento
│   ├── deploy-production.sh     # Script unificado de produção
│   ├── clean_env.sh            # Limpeza de ambiente de desenvolvimento
│   └── reset_env.sh            # Reset de ambiente de desenvolvimento
├── storage/
│   ├── backups/                # Backups automáticos
│   ├── logs/                   # Logs da aplicação
│   └── ...
└── ... (outros arquivos do projeto)
```

## 🔧 Configuração Inicial

### 1. Configurar Variáveis de Ambiente

```bash
# Copiar arquivo de exemplo para o diretório raiz
cp env.production-example .env.production

# Editar configurações (OBRIGATÓRIO!)
nano .env.production
```

**📍 Localização:** O arquivo `.env.production` deve estar na **raiz do projeto** e está protegido pelo `.gitignore`.

**⚠️ IMPORTANTE:** Altere todas as senhas e chaves:

```bash
# Gerar chave de criptografia
openssl rand -base64 32

# Gerar senhas seguras
openssl rand -base64 24
```

### 🔌 Configuração de Portas (Novo na v2.0)

As portas agora são configuráveis via variáveis de ambiente:

```bash
# Portas da aplicação web
HTTP_PORT=80          # Porta HTTP (padrão: 80)
HTTPS_PORT=443        # Porta HTTPS (padrão: 443)

# Porta do MySQL (opcional - apenas se precisar de acesso externo)
# MYSQL_PORT=3306     # Descomente apenas se necessário (risco de segurança)
```

**⚠️ Segurança:** 
- A porta MySQL externa está comentada por padrão por questões de segurança
- Descomente `MYSQL_PORT` apenas se precisar de acesso direto ao banco
- Para ambientes de produção, mantenha o MySQL acessível apenas internamente

### 2. Configurar Permissões

```bash
# Criar diretórios necessários
mkdir -p storage/{logs,backups,cache,sessions,uploads}

# Configurar permissões
chmod -R 755 storage/
chmod +x deploy/*.sh
```

## 🚀 Deploy com Sistema Unificado v2.0

### ⚡ Comandos Principais

O novo sistema unificado oferece todas as operações através de um único script:

```bash
# Iniciar produção (primeira vez ou após reset)
./deploy/deploy-production.sh --start

# Parar produção graciosamente
./deploy/deploy-production.sh --stop

# Reiniciar (parar + iniciar)
./deploy/deploy-production.sh --stop && ./deploy/deploy-production.sh --start

# Resetar ambiente (DESTRUTIVO!)
./deploy/deploy-production.sh --reset

# Criar backup
./deploy/deploy-production.sh --backup

# Monitorar saúde do sistema
./deploy/deploy-production.sh --monitor

# Ajuda
./deploy/deploy-production.sh --help
```

### 🔧 Usando Makefile (Opcional)

Para conveniência, você pode usar os atalhos do Makefile:

```bash
# Comandos principais
make start      # Iniciar produção
make stop       # Parar produção
make restart    # Reiniciar produção
make reset      # Resetar ambiente
make backup     # Criar backup
make monitor    # Monitorar saúde

# Comandos auxiliares
make status     # Status dos containers
make logs       # Ver logs
make health     # Verificação rápida de saúde
make info       # Informações do ambiente
```

### ⚠️ Fluxo Recomendado

**Para novo ambiente:**
```bash
# 1. Configurar .env.production (se ainda não foi feito)
cp env.production-example .env.production
nano .env.production

# 2. Iniciar produção
./deploy/deploy-production.sh --start
# OU
make start

# 3. Acessar instalação
# http://localhost/index.php/installation
```

**Para reset completo:**
```bash
# 1. CUIDADO: Isso apaga TODOS os dados!
./deploy/deploy-production.sh --reset
# OU
make reset

# 2. Iniciar novamente
./deploy/deploy-production.sh --start
```

## 🔍 Monitoramento e Manutenção

### 📊 Verificação de Saúde

```bash
# Verificação completa do sistema
./deploy/deploy-production.sh --monitor
make monitor

# Verificação rápida
make health

# Status dos containers
make status
docker compose -f docker-compose.prod.yml --env-file .env.production ps
```

### 📋 Logs

```bash
# Todos os logs
make logs

# Logs específicos
make logs-php      # PHP-FPM
make logs-nginx    # Nginx  
make logs-mysql    # MySQL

# Seguir logs em tempo real
make logs-follow
```

### 💾 Backup e Restauração

```bash
# Backup completo (banco + arquivos)
./deploy/deploy-production.sh --backup
make backup

# Backup apenas do banco
make db-backup

# Localização dos backups
ls -la storage/backups/
```

### 🔧 Manutenção

```bash
# Modo manutenção (backup + parada)
make maintenance-start

# Fim da manutenção (restart)
make maintenance-end

# Reconstruir imagens
make rebuild

# Atualizar imagens
make pull
```

## 🛠️ Troubleshooting

### ❌ Problemas Comuns

**1. Containers não iniciam:**
```bash
# Verificar logs
./deploy/deploy-production.sh --monitor
make logs

# Verificar configuração
make info
```

**2. Aplicação não responde:**
```bash
# Verificar saúde
./deploy/deploy-production.sh --monitor

# Verificar portas
netstat -tlnp | grep :80
netstat -tlnp | grep :443
```

**3. Erro de permissões:**
```bash
# Corrigir permissões do storage
chmod -R 755 storage/
find storage/ -type f -exec chmod 644 {} \;
```

**4. Banco de dados inacessível:**
```bash
# Verificar status do MySQL
make logs-mysql

# Acessar shell do banco
make db-shell
```

### 🔄 Reset e Limpeza

```bash
# Reset completo (CUIDADO: apaga tudo!)
./deploy/deploy-production.sh --reset

# Limpeza do Docker
make docker-clean
```

## 📈 Configurações Avançadas

### 🔒 Segurança de Portas

Por padrão, apenas as portas HTTP/HTTPS são expostas:

```bash
# .env.production
HTTP_PORT=80          # Porta pública HTTP
HTTPS_PORT=443        # Porta pública HTTPS
# MYSQL_PORT=3306     # Comentado por segurança
```

**Para expor MySQL externamente (não recomendado):**
```bash
# Descomente no .env.production
MYSQL_PORT=3306

# Reinicie o ambiente
make restart
```

### 🌐 Configuração de Domínio

```bash
# .env.production
APP_URL=https://yourdomain.com
HTTP_PORT=80
HTTPS_PORT=443
```

### 📊 Logs Avançados

O sistema v2.0 inclui logging avançado:

```bash
# Logs do sistema de deploy
tail -f storage/logs/deploy-production.log

# Logs coloridos e estruturados
./deploy/deploy-production.sh --monitor
```

## 📞 Suporte

- **Logs**: `storage/logs/deploy-production.log`
- **Status**: `./deploy/deploy-production.sh --monitor`
- **Ajuda**: `./deploy/deploy-production.sh --help`

---

**Versão**: 2.0  
**Última atualização**: $(date '+%Y-%m-%d')  
**Sistema**: Docker + Docker Compose v2
