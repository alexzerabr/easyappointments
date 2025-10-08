#!/bin/bash

# Easy!Appointments Development Deployment Script
# Version: 3.0
# 
# Este script gerencia o ambiente de desenvolvimento Docker do Easy!Appointments
# utilizando exclusivamente .env-dev para configuração.
#
# =============================================================================
# COMANDOS DISPONÍVEIS
# =============================================================================
#
# ./deploy/deploy-development.sh up
#   Sobe o ambiente de desenvolvimento completo (MySQL, PHP-FPM, Nginx, Mailpit, Logrotate)
#   - Carrega variáveis do .env-dev
#   - Inicia todos os containers necessários
#   - Aguarda serviços ficarem saudáveis
#   - Valida que a página de instalação está acessível com conteúdo correto
#
# ./deploy/deploy-development.sh down
#   Para todos os containers de desenvolvimento
#   - Preserva volumes por padrão
#   - Use --volumes para remover volumes também
#
# ./deploy/deploy-development.sh restart
#   Reinicia o ambiente de desenvolvimento
#   - Equivalente a: down && up
#
# ./deploy/deploy-development.sh clean
#   Limpeza completa do ambiente (DESTRUTIVO!)
#   - Para todos os containers
#   - Remove volumes Docker de dev
#   - Executa rm -rf no diretório de dados do MySQL
#   - Limpa cache, sessões e logs
#
# ./deploy/deploy-development.sh rebuild
#   Reconstrói as imagens e reinicia o ambiente
#   - Usa --build --no-cache para forçar rebuild completo
#   - Útil após mudanças no Dockerfile
#
# ./deploy/deploy-development.sh logs [serviço]
#   Exibe logs dos containers
#   - Sem argumentos: mostra logs de todos os serviços
#   - Com serviço: mostra logs apenas do serviço especificado
#   - Exemplos: logs, logs mysql, logs nginx
#
# ./deploy/deploy-development.sh ps
#   Lista status de todos os containers de desenvolvimento
#
# ./deploy/deploy-development.sh health|status
#   Verifica saúde do ambiente de desenvolvimento
#   - Testa healthchecks do MySQL e PHP-FPM
#   - Faz curl para http://localhost/index.php/installation
#   - Valida presença do conteúdo HTML da página de instalação
#   - Falha se conteúdo esperado não for encontrado
#
# ./deploy/deploy-development.sh shell [serviço]
#   Abre shell interativo no container especificado
#   - Padrão: php-fpm
#   - Exemplos: shell, shell mysql, shell nginx
#
# ./deploy/deploy-development.sh --help|-h|help
#   Exibe esta mensagem de ajuda
#
# =============================================================================
# EXEMPLOS DE USO
# =============================================================================
#
# # Primeira vez: copie .env-dev.example para .env-dev e ajuste valores
# cp .env-dev.example .env-dev
# vim .env-dev
#
# # Iniciar ambiente de desenvolvimento
# ./deploy/deploy-development.sh up
#
# # Verificar saúde dos serviços
# ./deploy/deploy-development.sh health
#
# # Ver logs em tempo real
# ./deploy/deploy-development.sh logs -f
#
# # Limpar completamente e reiniciar
# ./deploy/deploy-development.sh clean
# ./deploy/deploy-development.sh up
#
# # Reconstruir imagens após mudanças
# ./deploy/deploy-development.sh rebuild
#
# =============================================================================

set -euo pipefail

# Configuração do script
SCRIPT_VERSION="3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="docker-compose.dev.yml"
ENV_FILE=".env-dev"
ENV_EXAMPLE=".env-dev.example"
MYSQL_DATA_DIR="${ROOT_DIR}/docker/mysql-dev"

# Remove logs antigos antes de criar novo
rm -f /tmp/deploy-development-*.log 2>/dev/null || true

LOG_FILE="/tmp/deploy-development-$(date +%Y%m%d-%H%M%S).log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Mudar para diretório raiz do projeto
cd "$ROOT_DIR"

# =============================================================================
# FUNÇÕES AUXILIARES
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Garante que diretório de log existe
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Escreve no arquivo de log
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    # Output no console com cores
    case "$level" in
        "ERROR")   echo -e "${RED}❌ ERROR: $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}⚠️  WARNING: $message${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ️  INFO: $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ SUCCESS: $message${NC}" ;;
        "DEBUG")   echo -e "${PURPLE}🐛 DEBUG: $message${NC}" ;;
        *)         echo -e "${WHITE}📝 $message${NC}" ;;
    esac
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

print_header() {
    echo -e "${CYAN}"
    echo "============================================="
    echo "🚀 Easy!Appointments Dev Manager v${SCRIPT_VERSION}"
    echo "============================================="
    echo -e "${NC}"
}

# =============================================================================
# VALIDAÇÕES
# =============================================================================

validate_environment() {
    log "INFO" "Validando ambiente..."
    
    # Verifica Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker não está instalado ou não está no PATH"
    fi
    
    # Verifica Docker Compose v2
    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose v2 é necessário"
    fi
    
    # Verifica se daemon Docker está rodando
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon não está rodando"
    fi
    
    # Verifica arquivo compose
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "Arquivo Docker Compose não encontrado: $COMPOSE_FILE"
    fi
    
    log "SUCCESS" "Validação do ambiente passou"
}

validate_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        error_exit "Arquivo $ENV_FILE não encontrado! Copie $ENV_EXAMPLE para $ENV_FILE e configure as variáveis."
    fi
    
    log "INFO" "Carregando variáveis do $ENV_FILE..."
    
    # Carrega variáveis
    set -a
    source "$ENV_FILE"
    set +a
    
    # Valida variáveis obrigatórias
    local required_vars=(
        "MYSQL_DATABASE"
        "MYSQL_USER"
        "MYSQL_PASSWORD"
        "MYSQL_ROOT_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error_exit "Variável obrigatória $var não está definida em $ENV_FILE"
        fi
    done
    
    log "SUCCESS" "Arquivo $ENV_FILE validado com sucesso"
}

# =============================================================================
# SETUP DE CONFIGURAÇÃO
# =============================================================================

setup_config() {
    log "INFO" "Configurando config.php para desenvolvimento..."
    
    if [ ! -f "config-sample.php" ]; then
        error_exit "Arquivo config-sample.php não encontrado!"
    fi
    
    # Cria config.php a partir do sample
    cp config-sample.php config.php
    log "SUCCESS" "config.php criado a partir de config-sample.php"
    
    # Carrega variáveis do .env-dev para uso no sed
    local DB_HOST="${DB_HOST:-easyappointments-dev-db}"
    local DB_NAME="${MYSQL_DATABASE:-easyappointments}"
    local DB_USER="${MYSQL_USER:-user}"
    local DB_PASS="${MYSQL_PASSWORD:-password}"
    local APP_URL="${APP_URL:-http://localhost}"
    
    # Atualiza config.php com valores do .env-dev
    sed -i "s|const BASE_URL = 'http://localhost';|const BASE_URL = '${APP_URL}';|g" config.php
    sed -i "s|const DEBUG_MODE = false;|const DEBUG_MODE = true;|g" config.php
    sed -i "s|const DB_HOST = 'mysql';|const DB_HOST = '${DB_HOST}';|g" config.php
    sed -i "s|const DB_NAME = 'easyappointments';|const DB_NAME = '${DB_NAME}';|g" config.php
    sed -i "s|const DB_USERNAME = 'user';|const DB_USERNAME = '${DB_USER}';|g" config.php
    sed -i "s|const DB_PASSWORD = 'password';|const DB_PASSWORD = '${DB_PASS}';|g" config.php
    
    log "SUCCESS" "config.php configurado com credenciais de desenvolvimento"
    log "INFO" "Credenciais configuradas:"
    log "INFO" "  - BASE_URL: ${APP_URL}"
    log "INFO" "  - DB_HOST: ${DB_HOST}"
    log "INFO" "  - DB_NAME: ${DB_NAME}"
    log "INFO" "  - DB_USERNAME: ${DB_USER}"
    log "INFO" "  - DEBUG_MODE: true"
}

setup_dependencies() {
    log "INFO" "Verificando dependências do Composer..."
    
    local needs_install=false
    local reason=""
    
    # Verifica se diretório vendor existe
    if [ ! -d "vendor" ]; then
        needs_install=true
        reason="Diretório vendor não encontrado"
    else
        # Verifica se vendor está completo checando pacotes críticos
        local missing_packages=()
        
        if [ ! -d "vendor/ralouphie/getallheaders" ]; then
            missing_packages+=("ralouphie/getallheaders")
        fi
        
        if [ ! -d "vendor/google/apiclient" ]; then
            missing_packages+=("google/apiclient")
        fi
        
        if [ ! -d "vendor/sabre/dav" ]; then
            missing_packages+=("sabre/dav")
        fi
        
        if [ ! -f "vendor/autoload.php" ]; then
            missing_packages+=("autoload.php")
        fi
        
        # Se algum pacote crítico está faltando, reinstala tudo
        if [ ${#missing_packages[@]} -gt 0 ]; then
            needs_install=true
            reason="Pacotes críticos ausentes: ${missing_packages[*]}"
            
            log "WARN" "Vendor corrompido ou incompleto!"
            log "WARN" "Faltando: ${missing_packages[*]}"
            log "INFO" "Removendo vendor corrompido..."
            
            # Remove vendor corrompido usando Docker para evitar problemas de permissão
            docker run --rm -v "$ROOT_DIR":/app -w /app alpine:3.18 rm -rf vendor 2>/dev/null || \
            sudo rm -rf vendor 2>/dev/null || \
            rm -rf vendor 2>/dev/null || true
        fi
    fi
    
    # Instala ou reinstala dependências se necessário
    if [ "$needs_install" = true ]; then
        log "INFO" "$reason"
        log "INFO" "Instalando dependências do Composer (pode levar 1-2 minutos)..."
        
        # Aguarda container PHP estar pronto
        sleep 3
        
        # Remove logs antigos do Composer antes de criar novo
        rm -f /tmp/composer-install-*.log 2>/dev/null || true
        
        # Tenta instalar dependências
        local composer_log="/tmp/composer-install-$(date +%Y%m%d-%H%M%S).log"
        if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T easyappointments-dev-php composer install --no-interaction 2>&1 | tee "$composer_log" | grep -E "^(Installing|Generating)"; then
            log "SUCCESS" "Dependências do Composer instaladas"
            
            # Valida instalação
            local vendor_count=$(ls -1 vendor/ 2>/dev/null | wc -l)
            log "INFO" "Pacotes instalados: $vendor_count"
            
            if [ "$vendor_count" -lt 20 ]; then
                log "WARN" "Vendor parece incompleto (apenas $vendor_count pacotes)"
            fi
        else
            log "ERROR" "Falha ao instalar dependências do Composer"
            log "INFO" "Log detalhado: $composer_log"
            log "INFO" "Execute manualmente: docker compose -f $COMPOSE_FILE --env-file $ENV_FILE exec easyappointments-dev-php composer install"
            
            # Não falha o script, mas avisa
            return 1
        fi
    else
        # Vendor existe e está completo
        local vendor_count=$(ls -1 vendor/ 2>/dev/null | wc -l)
        log "SUCCESS" "Dependências do Composer OK ($vendor_count pacotes)"
    fi
}

ensure_storage_permissions() {
    log "INFO" "Verificando permissões do diretório storage..."
    
    # Verifica se containers estão rodando
    if ! docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q easyappointments-dev-php &>/dev/null; then
        log "WARN" "Container PHP não está rodando, pulando verificação de permissões"
        return 0
    fi
    
    # Ajusta permissões através do container para evitar problemas de ownership
    local dirs=(
        "/var/www/html/storage/sessions"
        "/var/www/html/storage/cache"
        "/var/www/html/storage/logs"
        "/var/www/html/storage/uploads"
        "/var/www/html/storage/backups"
    )
    
    for dir in "${dirs[@]}"; do
        if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T easyappointments-dev-php test -d "$dir" 2>/dev/null; then
            docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T easyappointments-dev-php chmod -R 777 "$dir" 2>/dev/null || true
        fi
    done
    
    log "SUCCESS" "Permissões do storage configuradas (777 para dev)"
}

# =============================================================================
# COMANDOS PRINCIPAIS
# =============================================================================

cmd_up() {
    log "INFO" "Iniciando ambiente de desenvolvimento..."
    
    validate_environment
    validate_env_file
    
    # Configura config.php automaticamente
    setup_config
    
    # Cria diretório de dados do MySQL se não existir
    mkdir -p "$MYSQL_DATA_DIR"
    log "INFO" "Diretório de dados MySQL: $MYSQL_DATA_DIR"
    
    # Inicia serviços
    log "INFO" "Subindo containers de desenvolvimento..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --remove-orphans
    
    log "INFO" "Aguardando serviços ficarem saudáveis..."
    
    # Aguarda MySQL ficar saudável
    local mysql_timeout=120
    local mysql_elapsed=0
    log "INFO" "Aguardando MySQL..."
    
    while [ $mysql_elapsed -lt $mysql_timeout ]; do
        local mysql_container=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q easyappointments-dev-db 2>/dev/null || true)
        if [ -n "$mysql_container" ]; then
            local health_status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' "$mysql_container" 2>/dev/null || echo "unknown")
            if [ "$health_status" = "healthy" ]; then
                log "SUCCESS" "MySQL está saudável"
                break
            fi
            log "INFO" "MySQL status: $health_status (aguardando...)"
        fi
        sleep 3
        mysql_elapsed=$((mysql_elapsed + 3))
    done
    
    if [ $mysql_elapsed -ge $mysql_timeout ]; then
        log "WARN" "Timeout aguardando MySQL ficar saudável (mas continuando...)"
    fi
    
    # Aguarda PHP-FPM ficar pronto
    log "INFO" "Aguardando PHP-FPM..."
    sleep 5
    
    # Aguarda Nginx e aplicação
    log "INFO" "Aguardando aplicação ficar disponível..."
    local app_timeout=60
    local app_elapsed=0
    
    while [ $app_elapsed -lt $app_timeout ]; do
        if curl -fsS --connect-timeout 3 "http://localhost/index.php/installation" >/dev/null 2>&1; then
            log "SUCCESS" "Aplicação está respondendo"
            break
        fi
        sleep 3
        app_elapsed=$((app_elapsed + 3))
    done
    
    if [ $app_elapsed -ge $app_timeout ]; then
        log "WARN" "Aplicação pode ainda estar inicializando"
    fi
    
    # Instala dependências do Composer se necessário
    setup_dependencies
    
    # Garante permissões corretas do storage
    ensure_storage_permissions
    
    # Verifica healthcheck completo
    cmd_health
    
    # Exibe informações de acesso
    echo -e "\n${GREEN}🎉 Ambiente de desenvolvimento iniciado com sucesso!${NC}\n"
    
    echo -e "${BLUE}📊 Status dos Containers:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    echo -e "\n${BLUE}🌐 URLs de Acesso:${NC}"
    echo -e "  📋 Instalação:  ${WHITE}http://localhost/index.php/installation${NC}"
    echo -e "  🏠 Aplicação:   ${WHITE}http://localhost${NC}"
    echo -e "  📧 Mailpit:     ${WHITE}http://localhost:8025${NC}"
    
    echo -e "\n${BLUE}🗄️  Credenciais do Banco:${NC}"
    echo -e "  Host:     ${WHITE}localhost:3306${NC} (externo) / ${WHITE}mysql:3306${NC} (interno)"
    echo -e "  Database: ${WHITE}${MYSQL_DATABASE}${NC}"
    echo -e "  Usuário:  ${WHITE}${MYSQL_USER}${NC}"
    echo -e "  Senha:    ${WHITE}${MYSQL_PASSWORD}${NC}"
    echo -e "  Root:     ${WHITE}${MYSQL_ROOT_PASSWORD}${NC}"
    
    echo -e "\n${YELLOW}📝 Próximos Passos:${NC}"
    echo -e "  1. Acesse: ${WHITE}http://localhost/index.php/installation${NC}"
    echo -e "  2. Use as credenciais do banco acima"
    echo -e "  3. Complete o wizard de instalação"
    
    log "SUCCESS" "Ambiente de desenvolvimento pronto!"
}

cmd_down() {
    log "INFO" "Parando ambiente de desenvolvimento..."
    
    validate_environment
    
    local remove_volumes=false
    if [[ "${1:-}" == "--volumes" ]]; then
        remove_volumes=true
    fi
    
    if ! docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q &>/dev/null; then
        log "WARN" "Nenhum container encontrado"
        return 0
    fi
    
    echo -e "${BLUE}📊 Containers atualmente rodando:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    if $remove_volumes; then
        log "WARN" "Parando containers e removendo volumes..."
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --volumes --remove-orphans
    else
        log "INFO" "Parando containers (preservando volumes)..."
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans
    fi
    
    echo -e "\n${GREEN}✅ Ambiente de desenvolvimento parado!${NC}"
    log "SUCCESS" "Containers parados"
}

cmd_restart() {
    log "INFO" "Reiniciando ambiente de desenvolvimento..."
    cmd_down
    sleep 2
    cmd_up
}

cmd_clean() {
    local remove_images=false
    
    # Verifica se flag --images foi passada
    if [[ "${1:-}" == "--images" ]]; then
        remove_images=true
    fi
    
    echo -e "${RED}⚠️  ATENÇÃO: Limpeza Completa do Ambiente de Desenvolvimento${NC}"
    echo "==========================================================="
    echo -e "${YELLOW}AVISO: Esta operação irá DESTRUIR PERMANENTEMENTE:${NC}"
    echo "  • Todos os containers de desenvolvimento"
    echo "  • Todos os volumes Docker de dev"
    echo "  • Todo o diretório de dados do MySQL ($MYSQL_DATA_DIR)"
    echo "  • Cache, sessões e logs da aplicação"
    echo "  • Arquivos gerados (config.php, vendor/)"
    
    if $remove_images; then
        echo -e "  ${RED}• IMAGENS DOCKER DE DEV (~2GB)${NC}"
    fi
    
    echo ""
    
    if $remove_images; then
        echo -e "${YELLOW}⚠️  ATENÇÃO: Você escolheu remover as IMAGENS também!${NC}"
        echo -e "${YELLOW}   Isso forçará um rebuild completo no próximo 'up' (pode demorar 5-10 minutos)${NC}"
        echo ""
    fi
    
    read -p "Tem CERTEZA que deseja continuar? Digite 'LIMPAR' para confirmar: " confirm
    
    if [ "$confirm" != "LIMPAR" ]; then
        log "INFO" "Operação de limpeza cancelada pelo usuário"
        exit 0
    fi
    
    log "WARN" "Iniciando limpeza completa do ambiente de desenvolvimento..."
    
    # Para e remove containers e volumes
    log "INFO" "Removendo containers e volumes..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --volumes --remove-orphans --timeout 30 2>/dev/null || true
    
    # Remove imagens se solicitado
    if $remove_images; then
        log "INFO" "Removendo imagens Docker de desenvolvimento..."
        
        # Remove imagens buildadas do projeto
        local images_to_remove=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "easyappointments-easyappointments-dev" || true)
        
        if [ -n "$images_to_remove" ]; then
            echo "$images_to_remove" | while read -r image; do
                log "INFO" "Removendo imagem: $image"
                docker rmi -f "$image" 2>/dev/null || true
            done
            log "SUCCESS" "Imagens de desenvolvimento removidas"
        else
            log "INFO" "Nenhuma imagem de desenvolvimento encontrada"
        fi
    fi
    
    # Remove diretório de dados do MySQL com rm -rf
    if [ -d "$MYSQL_DATA_DIR" ]; then
        log "INFO" "Removendo diretório de dados do MySQL: $MYSQL_DATA_DIR"
        if [ -w "$MYSQL_DATA_DIR" ]; then
            rm -rf "$MYSQL_DATA_DIR"
            log "SUCCESS" "Diretório MySQL removido"
        else
            log "INFO" "Tentando remover com sudo..."
            sudo rm -rf "$MYSQL_DATA_DIR" || log "ERROR" "Falha ao remover diretório MySQL"
        fi
    else
        log "INFO" "Diretório MySQL não existe: $MYSQL_DATA_DIR"
    fi
    
    # Limpa diretórios de storage
    log "INFO" "Limpando diretórios de storage..."
    find storage/logs -name "*.log" -type f -delete 2>/dev/null || true
    find storage/cache -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    find storage/sessions -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    find storage/uploads -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    
    # Remove arquivos gerados durante o desenvolvimento
    log "INFO" "Removendo arquivos gerados..."
    
    if [ -f "config.php" ]; then
        rm -f config.php
        log "SUCCESS" "config.php removido"
    fi
    
    if [ -d "vendor" ]; then
        log "INFO" "Removendo diretório vendor..."
        # Usa Docker para remover vendor com permissões corretas
        if command -v docker &> /dev/null; then
            docker run --rm -v "$ROOT_DIR":/app -w /app alpine:3.18 rm -rf vendor || \
            sudo rm -rf vendor 2>/dev/null || \
            log "WARN" "Não foi possível remover vendor automaticamente. Execute: sudo rm -rf vendor"
        else
            rm -rf vendor 2>/dev/null || sudo rm -rf vendor || \
            log "WARN" "Não foi possível remover vendor automaticamente. Execute: sudo rm -rf vendor"
        fi
        if [ ! -d "vendor" ]; then
            log "SUCCESS" "vendor removido"
        fi
    fi
    
    if [ -f "composer.lock" ]; then
        # Mantemos composer.lock se for commitado, senão removemos
        if ! git ls-files --error-unmatch composer.lock >/dev/null 2>&1; then
            rm -f composer.lock
            log "INFO" "composer.lock (não versionado) removido"
        fi
    fi
    
    echo -e "\n${GREEN}🎯 Limpeza completa do ambiente de desenvolvimento finalizada!${NC}"
    echo -e "${BLUE}📊 Resumo:${NC}"
    echo "  • Containers: REMOVIDOS"
    echo "  • Volumes: REMOVIDOS"
    echo "  • Dados MySQL: LIMPOS"
    echo "  • Storage: LIMPO"
    echo "  • Arquivos Gerados: REMOVIDOS (config.php, vendor/)"
    
    if $remove_images; then
        echo "  • Imagens Docker: REMOVIDAS"
        echo ""
        echo -e "${YELLOW}⚠️  Imagens removidas - próximo 'up' fará rebuild completo (5-10 min)${NC}"
    else
        echo "  • Imagens Docker: PRESERVADAS (use --images para remover)"
    fi
    
    echo ""
    echo -e "${YELLOW}📝 Para reiniciar o ambiente:${NC}"
    echo "  ./deploy/deploy-development.sh up"
    
    if ! $remove_images; then
        echo ""
        echo -e "${BLUE}💡 Dica:${NC} Para remover as imagens também (~2GB):"
        echo "  ./deploy/deploy-development.sh clean --images"
    fi
    
    echo ""
    echo -e "${BLUE}ℹ️  Nota:${NC} O próximo 'up' recriará automaticamente:"
    echo "  • config.php (a partir de config-sample.php)"
    echo "  • vendor/ (via composer install)"
    
    if $remove_images; then
        echo "  • Imagens Docker (via docker build)"
    fi
    
    log "SUCCESS" "Limpeza completa finalizada"
}

cmd_rebuild() {
    log "INFO" "Reconstruindo imagens e reiniciando ambiente..."
    
    validate_environment
    validate_env_file
    
    log "INFO" "Parando containers..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans || true
    
    log "INFO" "Reconstruindo imagens (--build --no-cache)..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build --no-cache
    
    log "INFO" "Iniciando com novas imagens..."
    cmd_up
    
    log "SUCCESS" "Rebuild completo!"
}

cmd_logs() {
    validate_environment
    
    local service="${1:-}"
    
    if [ -z "$service" ]; then
        log "INFO" "Exibindo logs de todos os serviços..."
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f
    else
        log "INFO" "Exibindo logs do serviço: $service"
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f "$service"
    fi
}

cmd_ps() {
    validate_environment
    
    echo -e "${BLUE}📊 Status dos Containers de Desenvolvimento:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
}

cmd_health() {
    log "INFO" "Verificando saúde do ambiente de desenvolvimento..."
    
    validate_environment
    
    local exit_code=0
    
    echo -e "\n${CYAN}🔍 Verificação de Saúde do Ambiente${NC}"
    echo "=========================================="
    
    # Verifica status dos containers
    echo -e "\n${BLUE}1. Status dos Containers${NC}"
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q &>/dev/null; then
        local running_count=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --filter "status=running" -q 2>/dev/null | wc -l)
        local total_count=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q 2>/dev/null | wc -l)
        
        if [ "$running_count" -eq "$total_count" ] && [ "$running_count" -gt 0 ]; then
            echo -e "   ${GREEN}✅ Todos os containers rodando ($running_count/$total_count)${NC}"
        else
            echo -e "   ${RED}❌ Alguns containers não estão rodando ($running_count/$total_count)${NC}"
            exit_code=1
        fi
    else
        echo -e "   ${RED}❌ Nenhum container encontrado${NC}"
        exit_code=1
    fi
    
    # Verifica healthcheck do MySQL
    echo -e "\n${BLUE}2. MySQL Healthcheck${NC}"
    local mysql_container=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q easyappointments-dev-db 2>/dev/null || true)
    if [ -n "$mysql_container" ]; then
        local mysql_health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$mysql_container" 2>/dev/null || echo "error")
        if [ "$mysql_health" = "healthy" ]; then
            echo -e "   ${GREEN}✅ MySQL está saudável${NC}"
        else
            echo -e "   ${YELLOW}⚠️  MySQL status: $mysql_health${NC}"
            exit_code=1
        fi
    else
        echo -e "   ${RED}❌ Container MySQL não encontrado${NC}"
        exit_code=1
    fi
    
    # Verifica conectividade HTTP
    echo -e "\n${BLUE}3. Conectividade HTTP${NC}"
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost/index.php/installation" 2>/dev/null || echo "000")
    if [ "$http_code" = "200" ]; then
        echo -e "   ${GREEN}✅ Aplicação respondendo (HTTP $http_code)${NC}"
    else
        echo -e "   ${RED}❌ Aplicação não responde corretamente (HTTP $http_code)${NC}"
        exit_code=1
    fi
    
    # Verifica CONTEÚDO da página de instalação
    echo -e "\n${BLUE}4. Validação de Conteúdo HTML${NC}"
    local page_content=$(curl -fsS --connect-timeout 10 "http://localhost/index.php/installation" 2>/dev/null || echo "")
    
    # Procura por marcadores que indicam que a página de instalação/setup está carregada
    if echo "$page_content" | grep -qi "installation\|install\|database\|config"; then
        echo -e "   ${GREEN}✅ Página de instalação carregada com conteúdo correto${NC}"
        if echo "$page_content" | grep -qi "config.php"; then
            echo -e "   ${YELLOW}ℹ️  Aplicação pede config.php (comportamento esperado)${NC}"
        fi
    else
        echo -e "   ${RED}❌ Página de instalação não contém o conteúdo esperado${NC}"
        echo -e "   ${YELLOW}⚠️  Primeiros 200 caracteres recebidos:${NC}"
        echo "$page_content" | head -c 200
        exit_code=1
    fi
    
    # Verifica Mailpit
    echo -e "\n${BLUE}5. Mailpit${NC}"
    local mailpit_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:8025" 2>/dev/null || echo "000")
    if [ "$mailpit_code" = "200" ]; then
        echo -e "   ${GREEN}✅ Mailpit acessível (HTTP $mailpit_code)${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Mailpit não acessível (HTTP $mailpit_code)${NC}"
        # Não falha por causa do Mailpit
    fi
    
    echo -e "\n=========================================="
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}🎉 Todas as verificações passaram!${NC}"
        log "SUCCESS" "Ambiente de desenvolvimento está saudável"
    else
        echo -e "${RED}⚠️  Algumas verificações falharam!${NC}"
        log "WARN" "Ambiente de desenvolvimento tem problemas"
    fi
    
    return $exit_code
}

cmd_shell() {
    validate_environment
    
    local service="${1:-easyappointments-dev-php}"
    
    log "INFO" "Abrindo shell no container: $service"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec "$service" /bin/bash || \
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec "$service" /bin/sh
}

show_help() {
    print_header
    
    cat << 'EOF'
COMANDOS DISPONÍVEIS:

  up, start
    Sobe o ambiente de desenvolvimento completo
    - Carrega variáveis do .env-dev
    - Inicia todos os containers necessários
    - Aguarda serviços ficarem saudáveis
    - Valida que a página de instalação está acessível

  down, stop [--volumes]
    Para todos os containers de desenvolvimento
    - Preserva volumes por padrão
    - Use --volumes para remover volumes também

  restart
    Reinicia o ambiente (down + up)

  clean [--images]
    Limpeza completa do ambiente (DESTRUTIVO!)
    - Para todos os containers
    - Remove volumes Docker de dev
    - Remove diretório de dados do MySQL (rm -rf)
    - Limpa cache, sessões e logs
    - Remove arquivos gerados (config.php, vendor/)
    - Opção --images: Remove também as imagens Docker (~2GB)

  rebuild
    Reconstrói as imagens e reinicia o ambiente
    - Usa --build --no-cache para rebuild completo

  logs [serviço]
    Exibe logs dos containers
    - Sem argumentos: todos os serviços
    - Com serviço: apenas o serviço especificado

  ps, status
    Lista status de todos os containers

  health, healthcheck
    Verifica saúde do ambiente
    - Testa healthchecks do MySQL e PHP-FPM
    - Valida conteúdo HTML da página de instalação

  shell [serviço]
    Abre shell interativo no container
    - Padrão: easyappointments-dev-php

  help, --help, -h
    Exibe esta mensagem de ajuda

EXEMPLOS DE USO:

  # Primeira vez: copie .env-dev.example para .env-dev
  cp .env-dev.example .env-dev
  vim .env-dev

  # Iniciar ambiente de desenvolvimento
  ./deploy/deploy-development.sh up

  # Verificar saúde dos serviços
  ./deploy/deploy-development.sh health

  # Ver logs em tempo real
  ./deploy/deploy-development.sh logs -f

  # Limpar completamente e reiniciar (preserva imagens)
  ./deploy/deploy-development.sh clean
  ./deploy/deploy-development.sh up

  # Limpar TUDO incluindo imagens (~2GB)
  ./deploy/deploy-development.sh clean --images
  ./deploy/deploy-development.sh up

  # Reconstruir imagens após mudanças
  ./deploy/deploy-development.sh rebuild

URLS DE ACESSO (após up):
  • Instalação: http://localhost/index.php/installation
  • Aplicação:  http://localhost
  • Mailpit:    http://localhost:8025

EOF
    
    echo -e "${WHITE}ARQUIVOS DE CONFIGURAÇÃO:${NC}"
    echo -e "  • Compose: ${CYAN}$COMPOSE_FILE${NC}"
    echo -e "  • Env:     ${CYAN}$ENV_FILE${NC}"
    echo -e "  • MySQL:   ${CYAN}$MYSQL_DATA_DIR${NC}"
    echo ""
    echo -e "${WHITE}VERSÃO:${NC} $SCRIPT_VERSION"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi
    
    local command="$1"
    
    case "$command" in
        up|start)
            print_header
            cmd_up "$@"
            ;;
        down|stop)
            print_header
            cmd_down "$@"
            ;;
        restart)
            print_header
            cmd_restart "$@"
            ;;
        clean)
            print_header
            shift  # Remove 'clean' dos argumentos
            cmd_clean "$@"  # Passa o restante dos argumentos
            ;;
        rebuild)
            print_header
            cmd_rebuild "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        ps|status)
            cmd_ps "$@"
            ;;
        health|healthcheck)
            print_header
            cmd_health "$@"
            ;;
        shell|bash|sh)
            cmd_shell "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}❌ Comando desconhecido: $command${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
