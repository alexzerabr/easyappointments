#!/bin/bash
################################################################################
# EasyAppointments Production Deployment Script
# Version: 3.0.0
# Description: Complete, robust production management for EasyAppointments
# Author: DevOps Team
# License: GPL-3.0
################################################################################

set -euo pipefail

# =============================================================================
# CONFIGURATION & GLOBALS
# =============================================================================

readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PRODUCTION_BASE="/srv/easyappointments"

# File names for production
readonly COMPOSE_FILE="docker-compose.yml"
readonly ENV_FILE=".env-prod"
readonly ENV_EXAMPLE=".env-example"
readonly CONFIG_SAMPLE="config-sample.php"
readonly CONFIG_FILE="config.php"

# Timeouts and retries
readonly HTTP_TIMEOUT=10
readonly HTTP_MAX_ATTEMPTS=30
readonly SERVICE_WAIT_TIME=5

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERR]${NC} $*"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $*"
    fi
}

error_exit() {
    log_error "$1"
    exit 1
}

print_header() {
    echo -e "${CYAN}"
    echo "============================================================"
    echo "  EasyAppointments Production Manager v${SCRIPT_VERSION}"
    echo "============================================================"
    echo -e "${NC}"
}

print_separator() {
    echo -e "${CYAN}------------------------------------------------------------${NC}"
}

# =============================================================================
# PREREQUISITE VALIDATION
# =============================================================================

ensure_prereqs() {
    log_info "Validating prerequisites..."
    
    local missing_deps=()
    
    # Check required commands
    for cmd in docker curl sed awk openssl tar gzip; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error_exit "Missing required dependencies: ${missing_deps[*]}"
    fi
    
    # Check Docker version
    if ! docker version &>/dev/null; then
        error_exit "Docker is not running or not accessible"
    fi
    
    local docker_version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0")
    log_debug "Docker version: $docker_version"
    
    # Check Docker Compose v2
    if ! docker compose version &>/dev/null; then
        error_exit "Docker Compose v2 is required (use 'docker compose' not 'docker-compose')"
    fi
    
    local compose_version
    compose_version=$(docker compose version --short 2>/dev/null || echo "0")
    log_debug "Docker Compose version: $compose_version"
    
    log_ok "All prerequisites satisfied"
}

# =============================================================================
# DIRECTORY STRUCTURE MANAGEMENT
# =============================================================================

ensure_dirs() {
    log_info "Creating directory structure in ${PRODUCTION_BASE}..."
    
    local dirs=(
        "${PRODUCTION_BASE}"
        "${PRODUCTION_BASE}/backups"
        "${PRODUCTION_BASE}/logs"
        "${PRODUCTION_BASE}/logs/nginx"
        "${PRODUCTION_BASE}/logs/php-fpm"
        "${PRODUCTION_BASE}/logs/app"
        "${PRODUCTION_BASE}/config"
        "${PRODUCTION_BASE}/composer-cache"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if ! mkdir -p "$dir" 2>/dev/null; then
                error_exit "Cannot create directory: $dir (try with sudo)"
            fi
            log_debug "Created: $dir"
        fi
    done
    
    # Set appropriate permissions
    local current_user="${SUDO_USER:-${USER}}"
    if [[ -n "$current_user" ]] && [[ "$current_user" != "root" ]]; then
        if [[ -w "${PRODUCTION_BASE}" ]]; then
            chown -R "${current_user}:${current_user}" "${PRODUCTION_BASE}" 2>/dev/null || true
        fi
    fi
    
    log_ok "Directory structure ready"
}

# =============================================================================
# SECRET GENERATION
# =============================================================================

generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

generate_hex_key() {
    local length="${1:-32}"
    openssl rand -hex "$length"
}

generate_secrets() {
    log_info "Generating secure credentials..."
    
    MYSQL_ROOT_PASSWORD=$(generate_password 32)
    MYSQL_PASSWORD=$(generate_password 24)
    WA_TOKEN_ENC_KEY=$(generate_hex_key 32)
    BACKUP_ENCRYPTION_KEY=$(generate_hex_key 32)
    
    log_ok "Credentials generated securely"
}

# =============================================================================
# ENVIRONMENT FILE MANAGEMENT
# =============================================================================

ensure_env() {
    log_info "Setting up environment file..."
    
    cd "$PROJECT_ROOT"
    
    # Check if .env exists
    if [[ -f "$ENV_FILE" ]]; then
        log_info "Environment file exists, loading..."
        # shellcheck disable=SC1090
        set -a
        source "$ENV_FILE"
        set +a
        
        # Validate required variables
        local required_vars=(
            "MYSQL_ROOT_PASSWORD"
            "DB_PASSWORD"
            "WA_TOKEN_ENC_KEY"
        )
        
        local missing_vars=()
        for var in "${required_vars[@]}"; do
            if [[ -z "${!var:-}" ]]; then
                missing_vars+=("$var")
            fi
        done
        
        if [[ ${#missing_vars[@]} -gt 0 ]]; then
            error_exit "Missing required variables in ${ENV_FILE}: ${missing_vars[*]}"
        fi
        
        log_ok "Environment loaded successfully"
        return 0
    fi
    
    # Check for source file to convert
    local source_env="$ENV_EXAMPLE"
    if [[ ! -f "$source_env" ]]; then
        error_exit "Environment example file not found: ${source_env}"
    fi
    
    log_info "Creating ${ENV_FILE} from ${source_env}..."
    
    # Generate credentials
    generate_secrets
    
    # Create .env from template
    cp "$source_env" "$ENV_FILE"
    
    # Replace placeholder values
    sed -i "s/CHANGE_THIS_STRONG_PASSWORD/${MYSQL_PASSWORD}/g" "$ENV_FILE"
    sed -i "s/CHANGE_THIS_ROOT_PASSWORD/${MYSQL_ROOT_PASSWORD}/g" "$ENV_FILE"
    sed -i "s/CHANGE_THIS_GENERATE_NEW_KEY_WITH_OPENSSL/${WA_TOKEN_ENC_KEY}/g" "$ENV_FILE"
    sed -i "s/CHANGE_THIS_BACKUP_KEY/${BACKUP_ENCRYPTION_KEY}/g" "$ENV_FILE"
    
    # Add production-specific settings if not present
    if ! grep -q "COMPOSE_PROJECT_NAME" "$ENV_FILE"; then
        echo "" >> "$ENV_FILE"
        echo "# Docker Compose Project Name (isolates from dev)" >> "$ENV_FILE"
        echo "COMPOSE_PROJECT_NAME=easyappointments_prod" >> "$ENV_FILE"
    fi
    
    # Set secure permissions
    chmod 600 "$ENV_FILE"
    
    log_ok "Environment file created: ${ENV_FILE}"
    
    # Display generated credentials (ONLY once during creation)
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🔐 GENERATED CREDENTIALS - SAVE THESE SECURELY!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Database Password:${NC}        ${MYSQL_PASSWORD}"
    echo -e "${WHITE}MySQL Root Password:${NC}      ${MYSQL_ROOT_PASSWORD}"
    echo -e "${WHITE}WhatsApp Encryption Key:${NC}  ${WA_TOKEN_ENC_KEY}"
    echo -e "${WHITE}Backup Encryption Key:${NC}    ${BACKUP_ENCRYPTION_KEY}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Load the new environment
    set -a
    source "$ENV_FILE"
    set +a
}

prompt_ports() {
    log_info "Configuring network ports..."
    
    local http_port="${HTTP_PORT:-80}"
    local https_port="${HTTPS_PORT:-443}"
    
    read -p "HTTP Port [${http_port}]: " input_http
    http_port="${input_http:-$http_port}"
    
    read -p "HTTPS Port [${https_port}]: " input_https
    https_port="${input_https:-$https_port}"
    
    # Update .env file
    sed -i "s/^HTTP_PORT=.*/HTTP_PORT=${http_port}/" "$ENV_FILE"
    sed -i "s/^HTTPS_PORT=.*/HTTPS_PORT=${https_port}/" "$ENV_FILE"
    
    export HTTP_PORT="$http_port"
    export HTTPS_PORT="$https_port"
    
    log_ok "Ports configured: HTTP=${http_port}, HTTPS=${https_port}"
}

# =============================================================================
# DOCKER COMPOSE FILE MANAGEMENT
# =============================================================================

ensure_compose() {
    log_info "Setting up Docker Compose file..."
    
    cd "$PROJECT_ROOT"
    
    # Check if docker-compose.yml exists
    if [[ -f "$COMPOSE_FILE" ]]; then
        log_ok "Docker Compose file found: ${COMPOSE_FILE}"
        return 0
    fi
    
    # Look for source file
    local source_file="docker-compose-example.yml"
    if [[ ! -f "$source_file" ]]; then
        error_exit "Docker Compose example file not found: ${source_file}"
    fi
    
    log_info "Using ${source_file} as template..."
    cp "$source_file" "$COMPOSE_FILE"
    
    log_ok "Docker Compose file created: ${COMPOSE_FILE}"
}

# =============================================================================
# CONFIG.PHP GENERATION
# =============================================================================

prepare_config() {
    log_info "Generating ${CONFIG_FILE}..."
    
    cd "$PROJECT_ROOT"
    
    if [[ ! -f "$CONFIG_SAMPLE" ]]; then
        error_exit "Template not found: ${CONFIG_SAMPLE}"
    fi
    
    # Build BASE_URL
    local app_url="${APP_URL:-http://localhost}"
    local http_port="${HTTP_PORT:-80}"
    
    if [[ "$http_port" != "80" ]] && [[ "$http_port" != "443" ]]; then
        app_url="${app_url}:${http_port}"
    fi
    
    # Generate config.php
    cat > "$CONFIG_FILE" << EOF
<?php
/* ----------------------------------------------------------------------------
 * Easy!Appointments - Production Configuration
 * Generated: $(date '+%Y-%m-%d %H:%M:%S')
 * WARNING: This file is auto-generated. Manual changes may be overwritten.
 * ---------------------------------------------------------------------------- */

class Config
{
    // ------------------------------------------------------------------------
    // GENERAL SETTINGS
    // ------------------------------------------------------------------------

    const BASE_URL = '${app_url}';
    const LANGUAGE = '${APP_LANGUAGE:-english}';
    const DEBUG_MODE = false;

    // ------------------------------------------------------------------------
    // DATABASE SETTINGS
    // ------------------------------------------------------------------------

    const DB_HOST = '${DB_HOST:-mysql}';
    const DB_NAME = '${DB_DATABASE:-easyappointments}';
    const DB_USERNAME = '${DB_USERNAME:-easyapp_user}';
    const DB_PASSWORD = '${DB_PASSWORD}';

    // ------------------------------------------------------------------------
    // GOOGLE CALENDAR SYNC
    // ------------------------------------------------------------------------

    const GOOGLE_SYNC_FEATURE = false;
    const GOOGLE_CLIENT_ID = '';
    const GOOGLE_CLIENT_SECRET = '';
}
EOF
    
    # Set secure permissions (readable by all, writable by owner)
    # Using 644 instead of 640 to ensure Docker containers can read it
    chmod 644 "$CONFIG_FILE"
    
    # Set owner to current user to ensure it's readable
    local current_user="${SUDO_USER:-${USER}}"
    if [[ -n "$current_user" ]] && [[ "$current_user" != "root" ]]; then
        chown "${current_user}:${current_user}" "$CONFIG_FILE" 2>/dev/null || true
    fi
    
    # Copy to production base if deploying to /srv
    if [[ -d "${PRODUCTION_BASE}/config" ]]; then
        cp "$CONFIG_FILE" "${PRODUCTION_BASE}/config/"
        log_debug "Copied config.php to ${PRODUCTION_BASE}/config/"
    fi
    
    log_ok "Configuration file generated: ${CONFIG_FILE}"
    log_info "  BASE_URL: ${app_url}"
    log_info "  DB_HOST: ${DB_HOST:-mysql}"
    log_info "  DB_NAME: ${DB_DATABASE:-easyappointments}"
    log_info "  DEBUG_MODE: false"
}

# =============================================================================
# HEALTH CHECKS & WAITING
# =============================================================================

wait_http() {
    local url="$1"
    local description="${2:-endpoint}"
    local max_attempts="${HTTP_MAX_ATTEMPTS}"
    local timeout="${HTTP_TIMEOUT}"
    
    log_info "Waiting for ${description} to respond..."
    
    for attempt in $(seq 1 "$max_attempts"); do
        if curl -fsS --connect-timeout "$timeout" --max-time "$timeout" "$url" >/dev/null 2>&1; then
            log_ok "${description} is ready"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "${description} did not respond after ${max_attempts} attempts"
            return 1
        fi
        
        log_debug "Attempt ${attempt}/${max_attempts}..."
        sleep 2
    done
    
    return 1
}

wait_mysql() {
    local max_attempts=30
    local container_name="${1:-easyappointments-mysql}"
    
    log_info "Waiting for MySQL to be ready..."
    
    for attempt in $(seq 1 "$max_attempts"); do
        if docker inspect "$container_name" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
            log_ok "MySQL is healthy"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "MySQL did not become healthy after ${max_attempts} attempts"
            return 1
        fi
        
        log_debug "MySQL health check ${attempt}/${max_attempts}..."
        sleep 2
    done
    
    return 1
}

wait_container() {
    local container_name="$1"
    local max_attempts=20
    
    log_info "Waiting for container: ${container_name}..."
    
    for attempt in $(seq 1 "$max_attempts"); do
        if docker ps --filter "name=${container_name}" --filter "status=running" --format '{{.Names}}' | grep -q "$container_name"; then
            log_ok "Container ${container_name} is running"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Container ${container_name} did not start"
            return 1
        fi
        
        log_debug "Waiting for ${container_name}... ${attempt}/${max_attempts}"
        sleep 2
    done
    
    return 1
}

# =============================================================================
# IMAGE VERSION AND CHANGE DETECTION
# =============================================================================

show_image_info() {
    local image_tag="${IMAGE_TAG:-latest}"
    local registry="${CONTAINER_REGISTRY:-ghcr.io/alexzerabr}"
    local full_image="${registry}/easyappointments:${image_tag}"
    
    log_info "═══════════════════════════════════════════════════════════"
    log_info "  INFORMAÇÕES DA IMAGEM"
    log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    log_info "Imagem: $full_image"
    echo ""
    
    # Verifica se imagem existe localmente
    if docker image inspect "$full_image" >/dev/null 2>&1; then
        log_ok "Imagem encontrada localmente"
        
        # Extrai metadados da imagem
        local build_date=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.created"}}' 2>/dev/null || echo "N/A")
        local build_version=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null || echo "N/A")
        local git_commit=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' 2>/dev/null || echo "N/A")
        local image_id=$(docker inspect "$full_image" --format='{{.Id}}' 2>/dev/null | cut -d':' -f2 | cut -c1-12)
        
        echo "📋 Metadados da Imagem:"
        echo "   ID:      $image_id"
        echo "   Versão:  $build_version"
        echo "   Commit:  $git_commit"
        echo "   Data:    $build_date"
        
        # Verifica se há versão dentro do container
        if docker run --rm "$full_image" cat /etc/easyappointments-version 2>/dev/null; then
            echo ""
            log_ok "Arquivo de versão encontrado"
        fi
    else
        log_warn "Imagem não encontrada localmente"
        log_info "Execute 'docker pull $full_image' para baixá-la"
    fi
    
    echo ""
}

detect_image_changes() {
    local image_tag="${IMAGE_TAG:-latest}"
    local registry="${CONTAINER_REGISTRY:-ghcr.io/alexzerabr}"
    local full_image="${registry}/easyappointments:${image_tag}"
    
    log_info "═══════════════════════════════════════════════════════════"
    log_info "  DETECÇÃO DE MUDANÇAS NA IMAGEM"
    log_info "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Obtém ID da imagem local atual
    local current_id=$(docker image inspect "$full_image" --format='{{.Id}}' 2>/dev/null || echo "none")
    
    log_info "Verificando atualizações disponíveis..."
    
    # Faz pull da imagem mais recente (silencioso)
    if docker pull "$full_image" >/dev/null 2>&1; then
        local new_id=$(docker image inspect "$full_image" --format='{{.Id}}' 2>/dev/null || echo "none")
        
        if [[ "$current_id" == "none" ]]; then
            log_ok "Nova imagem baixada (primeira vez)"
            show_image_info
            return 0
        elif [[ "$current_id" != "$new_id" ]]; then
            log_ok "🔄 Nova versão disponível!"
            echo ""
            
            # Mostra informações da versão nova
            local new_version=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null || echo "N/A")
            local new_commit=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' 2>/dev/null || echo "N/A")
            local new_date=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.created"}}' 2>/dev/null || echo "N/A")
            
            echo "📦 Nova Versão:"
            echo "   Versão:  $new_version"
            echo "   Commit:  $new_commit"
            echo "   Data:    $new_date"
            echo ""
            
            log_info "Para aplicar: sudo $(basename "$0") update"
            return 1
        else
            log_ok "✅ Você está usando a versão mais recente"
            show_image_info
            return 0
        fi
    else
        log_error "Falha ao verificar atualizações"
        return 1
    fi
}

# =============================================================================
# SMOKE TEST - Validação de imagem antes do deploy
# =============================================================================

smoke_test() {
    log_info "═══════════════════════════════════════════════════════════"
    log_info "  SMOKE TEST - Validação de Imagem"
    log_info "═══════════════════════════════════════════════════════════"
    
    local image_tag="${IMAGE_TAG:-latest}"
    local registry="${CONTAINER_REGISTRY:-ghcr.io/alexzerabr}"
    local full_image="${registry}/easyappointments:${image_tag}"
    
    log_info "Imagem a testar: $full_image"
    echo ""
    
    # Pull da imagem
    log_info "1/5 Fazendo pull da imagem..."
    if ! docker pull "$full_image"; then
        log_error "Falha ao fazer pull da imagem"
        return 1
    fi
    log_ok "Pull concluído"
    
    # Verifica digest e informações
    log_info "2/5 Verificando informações da imagem..."
    local image_digest=$(docker inspect "$full_image" --format='{{.Id}}' 2>/dev/null)
    local image_created=$(docker inspect "$full_image" --format='{{.Created}}' 2>/dev/null | cut -d'T' -f1)
    
    if [[ -z "$image_digest" ]]; then
        log_error "Não foi possível obter digest da imagem"
        return 1
    fi
    
    log_ok "Digest: ${image_digest:0:20}..."
    log_ok "Criada em: $image_created"
    
    # Inicia container temporário para testes
    log_info "3/5 Iniciando container de teste..."
    local test_container="easyappointments-smoke-test-$$"
    
    # Remove container anterior se existir
    docker rm -f "$test_container" >/dev/null 2>&1 || true
    
    # Inicia container temporário
    if ! docker run -d \
        --name "$test_container" \
        --env DATABASE_HOST=dummy \
        --env DATABASE_NAME=dummy \
        --env DATABASE_USERNAME=dummy \
        --env DATABASE_PASSWORD=dummy \
        "$full_image" \
        sleep 30; then
        log_error "Falha ao iniciar container de teste"
        return 1
    fi
    
    log_ok "Container de teste iniciado"
    
    # Valida arquivos críticos dentro do container
    log_info "4/5 Validando arquivos críticos..."
    
    local critical_files=(
        "/var/www/html/index.php"
        "/var/www/html/application/config/config.php"
        "/var/www/html/assets/css/general.min.css"
        "/var/www/html/assets/js/app.min.js"
        "/var/www/html/vendor/autoload.php"
    )
    
    local validation_failed=false
    
    for file in "${critical_files[@]}"; do
        if docker exec "$test_container" test -f "$file" 2>/dev/null; then
            log_ok "✓ $(basename $file)"
        else
            log_error "✗ $(basename $file) - NÃO ENCONTRADO"
            validation_failed=true
        fi
    done
    
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Validação de arquivos falhou"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    fi
    
    # Valida estrutura de diretórios
    log_info "5/5 Validando estrutura de diretórios..."
    
    local critical_dirs=(
        "/var/www/html/application"
        "/var/www/html/assets"
        "/var/www/html/vendor"
        "/var/www/html/storage"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if docker exec "$test_container" test -d "$dir" 2>/dev/null; then
            log_ok "✓ $(basename $dir)/"
        else
            log_error "✗ $(basename $dir)/ - NÃO ENCONTRADO"
            validation_failed=true
        fi
    done
    
    # Cleanup
    docker rm -f "$test_container" >/dev/null 2>&1
    
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Validação da estrutura falhou"
        return 1
    fi
    
    echo ""
    log_ok "═══════════════════════════════════════════════════════════"
    log_ok "  ✅ SMOKE TEST PASSOU - Imagem está funcional"
    log_ok "═══════════════════════════════════════════════════════════"
    echo ""
    
    return 0
}

# =============================================================================
# DOCKER COMPOSE OPERATIONS
# =============================================================================

compose_cmd() {
    cd "$PROJECT_ROOT"
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

compose_up() {
    local is_initial="${1:-false}"
    
    if [[ "$is_initial" == "--initial" ]]; then
        log_info "═══════════════════════════════════════════════════════════"
        log_info "  INITIAL PRODUCTION SETUP"
        log_info "═══════════════════════════════════════════════════════════"
        
        # Prompt for ports
        prompt_ports
        
        # Ensure directories
        ensure_dirs
        
        # Generate config
        prepare_config
        
        log_info "Pulling Docker images..."
        if ! compose_cmd pull; then
            log_warn "Image pull encountered issues, but continuing..."
        fi
    fi
    
    log_info "Starting production environment..."
    
    if ! compose_cmd up -d --remove-orphans; then
        error_exit "Failed to start containers"
    fi
    
    log_info "Waiting for services to initialize (${SERVICE_WAIT_TIME}s)..."
    sleep "$SERVICE_WAIT_TIME"
    
    # Wait for MySQL
    if ! wait_mysql "easyappointments-mysql"; then
        log_warn "MySQL health check timed out, but may still be starting"
    fi
    
    # Wait for PHP-FPM
    if ! wait_container "easyappointments-php-fpm"; then
        log_warn "PHP-FPM container not detected"
    fi
    
    # Wait for Nginx
    if ! wait_container "easyappointments-nginx"; then
        log_warn "Nginx container not detected"
    fi
    
    # Check HTTP endpoint
    local http_port="${HTTP_PORT:-80}"
    if ! wait_http "http://localhost:${http_port}/index.php/installation" "installation page"; then
        log_warn "Installation page not responding yet, may need more time"
    fi
    
    # Display success summary
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✅ PRODUCTION ENVIRONMENT IS UP!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Show access URLs
    echo -e "${CYAN}🌐 Access URLs:${NC}"
    echo -e "   Installation: ${WHITE}http://localhost:${http_port}/index.php/installation${NC}"
    echo -e "   Application:  ${WHITE}http://localhost:${http_port}${NC}"
    echo ""
    
    # Show container status
    echo -e "${CYAN}🐳 Container Status:${NC}"
    compose_cmd ps
    echo ""
    
    if [[ "$is_initial" == "--initial" ]]; then
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo -e "   1. Complete installation at the URL above"
        echo -e "   2. Use database credentials from: ${WHITE}${ENV_FILE}${NC}"
        echo -e "   3. Configure email and WhatsApp settings"
        echo ""
    fi
    
    log_ok "Production environment started successfully"
}

compose_down() {
    log_info "Stopping production environment..."
    
    cd "$PROJECT_ROOT"
    
    if ! compose_cmd ps -q 2>/dev/null | grep -q .; then
        log_warn "No running containers found"
        return 0
    fi
    
    echo -e "${CYAN}Current containers:${NC}"
    compose_cmd ps
    echo ""
    
    if ! compose_cmd down --remove-orphans; then
        error_exit "Failed to stop containers"
    fi
    
    log_ok "Production environment stopped"
}

compose_logs() {
    local follow_flag=""
    local service=""
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            -f|--follow)
                follow_flag="-f"
                ;;
            *)
                service="$arg"
                ;;
        esac
    done
    
    log_info "Displaying logs..."
    
    cd "$PROJECT_ROOT"
    
    # shellcheck disable=SC2086
    compose_cmd logs $follow_flag $service
}

compose_health() {
    log_info "═══════════════════════════════════════════════════════════"
    log_info "  PRODUCTION HEALTH CHECK"
    log_info "═══════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT"
    
    local exit_code=0
    
    # Check container status
    echo ""
    echo -e "${CYAN}🐳 Container Status:${NC}"
    if ! compose_cmd ps 2>/dev/null; then
        log_error "Cannot query container status"
        exit_code=1
    fi
    echo ""
    
    # Count running containers
    local running_count
    running_count=$(compose_cmd ps --filter "status=running" -q 2>/dev/null | wc -l)
    local total_count
    total_count=$(compose_cmd ps -q 2>/dev/null | wc -l)
    
    if [[ "$running_count" -eq "$total_count" ]] && [[ "$running_count" -gt 0 ]]; then
        log_ok "All containers running (${running_count}/${total_count})"
    else
        log_error "Some containers not running (${running_count}/${total_count})"
        exit_code=1
    fi
    
    # Check MySQL health
    echo ""
    echo -e "${CYAN}💾 Database Health:${NC}"
    if docker inspect easyappointments-mysql --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        log_ok "MySQL is healthy"
    else
        log_error "MySQL is not healthy"
        exit_code=1
    fi
    
    # Check HTTP endpoints
    echo ""
    echo -e "${CYAN}🌐 HTTP Endpoints:${NC}"
    local http_port="${HTTP_PORT:-80}"
    
    local install_status
    install_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:${http_port}/index.php/installation" 2>/dev/null || echo "000")
    
    if [[ "$install_status" == "200" ]] || [[ "$install_status" =~ ^30[0-9]$ ]]; then
        log_ok "Installation page responding (HTTP ${install_status})"
    else
        log_error "Installation page not responding (HTTP ${install_status})"
        exit_code=1
    fi
    
    local app_status
    app_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:${http_port}/" 2>/dev/null || echo "000")
    
    if [[ "$app_status" == "200" ]] || [[ "$app_status" =~ ^30[0-9]$ ]]; then
        log_ok "Main application responding (HTTP ${app_status})"
    else
        log_warn "Main application status: HTTP ${app_status} (may be normal during setup)"
    fi
    
    # Summary
    echo ""
    print_separator
    if [[ $exit_code -eq 0 ]]; then
        log_ok "All health checks passed ✅"
    else
        log_error "Some health checks failed ❌"
    fi
    print_separator
    
    return $exit_code
}

compose_update() {
    log_info "═══════════════════════════════════════════════════════════"
    log_info "  PRODUCTION UPDATE"
    log_info "═══════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT"
    
    # Pull latest code from repository
    log_info "Pulling latest code from repository..."
    if git pull --rebase 2>&1 | grep -q "Already up to date"; then
        log_info "Repository already up to date"
    elif git pull --rebase; then
        log_ok "Repository updated successfully"
    else
        log_warn "Git pull had issues, continuing anyway..."
    fi
    
    echo ""
    
    # Backup before update
    log_info "Creating backup before update..."
    compose_backup
    
    echo ""
    log_info "Stopping containers..."
    compose_cmd down --remove-orphans
    
    log_info "Pulling latest Docker images..."
    if ! compose_cmd pull; then
        error_exit "Failed to pull images"
    fi
    
    log_info "Cleaning up old images..."
    docker image prune -f >/dev/null 2>&1 || true
    
    log_info "Starting updated environment with FORCE_UPDATE..."
    export FORCE_UPDATE=true
    compose_up
    
    echo ""
    log_info "Running database migrations..."
    if compose_cmd exec -T php-fpm php patch.php migration latest 2>&1 | grep -qE "completed|No new"; then
        log_ok "Migrations completed"
    else
        log_warn "Migration output unclear, check manually"
    fi
    
    echo ""
    log_info "Validating application response..."
    local http_port="${HTTP_PORT:-80}"
    if wait_http "http://localhost:${http_port}/" "application after update"; then
        log_ok "Application responding correctly after update"
    else
        log_error "Application not responding after update - manual verification needed"
        log_error "Check logs: docker logs easyappointments-php-fpm"
        return 1
    fi
    
    echo ""
    log_ok "═══════════════════════════════════════════════════════════"
    log_ok "  ✅ UPDATE COMPLETED SUCCESSFULLY"
    log_ok "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Show version information
    log_info "Checking update details..."
    local update_timestamp
    update_timestamp=$(docker exec easyappointments-php-fpm cat /var/www/html/.docker-init-complete 2>/dev/null || echo "unknown")
    local image_digest
    image_digest=$(docker exec easyappointments-php-fpm cat /var/www/html/.docker-image-digest 2>/dev/null || echo "unknown")
    
    echo -e "${CYAN}Update Information:${NC}"
    echo -e "   Last Updated:  ${WHITE}$(date -d @${update_timestamp} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')${NC}"
    echo -e "   Image Digest:  ${WHITE}${image_digest}${NC}"
    echo ""
}

compose_backup() {
    log_info "═══════════════════════════════════════════════════════════"
    log_info "  PRODUCTION BACKUP"
    log_info "═══════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT"
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${PRODUCTION_BASE}/backups/backup_${timestamp}"
    
    mkdir -p "$backup_dir"
    log_info "Backup destination: ${backup_dir}"
    
    # Backup database
    echo ""
    log_info "Backing up MySQL database..."
    if compose_cmd exec -T mysql mysqldump \
        -u root -p"${MYSQL_ROOT_PASSWORD}" \
        --single-transaction --routines --triggers --events \
        "${DB_DATABASE:-easyappointments}" | gzip > "${backup_dir}/database.sql.gz"; then
        log_ok "Database backup created: database.sql.gz"
    else
        log_error "Database backup failed"
    fi
    
    # Backup config files
    log_info "Backing up configuration..."
    cp "$ENV_FILE" "${backup_dir}/env" 2>/dev/null || true
    cp "$CONFIG_FILE" "${backup_dir}/config.php" 2>/dev/null || true
    cp "$COMPOSE_FILE" "${backup_dir}/docker-compose.yml" 2>/dev/null || true
    
    # Backup application storage (if exists)
    if [[ -d "storage" ]]; then
        log_info "Backing up application storage..."
        tar -czf "${backup_dir}/storage.tar.gz" storage/ 2>/dev/null || true
        log_ok "Storage backup created: storage.tar.gz"
    fi
    
    # Calculate backup size
    local backup_size
    backup_size=$(du -sh "$backup_dir" | cut -f1)
    
    # Verify backup integrity
    log_info "Verifying backup integrity..."
    if [[ -f "${backup_dir}/database.sql.gz" ]] && gzip -t "${backup_dir}/database.sql.gz" 2>/dev/null; then
        log_ok "Database backup integrity verified"
    else
        log_error "Database backup integrity check failed"
    fi
    
    # Rotate old backups (keep last 7 days or 10 backups)
    log_info "Rotating old backups..."
    local backup_count
    backup_count=$(find "${PRODUCTION_BASE}/backups" -maxdepth 1 -type d -name "backup_*" | wc -l)
    
    if [[ $backup_count -gt 10 ]]; then
        find "${PRODUCTION_BASE}/backups" -maxdepth 1 -type d -name "backup_*" -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
        log_info "Removed backups older than 7 days"
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✅ BACKUP COMPLETED${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}Location:${NC} ${backup_dir}"
    echo -e "${WHITE}Size:${NC}     ${backup_size}"
    echo -e "${WHITE}Files:${NC}"
    ls -lh "$backup_dir" 2>/dev/null | tail -n +2 | awk '{print "   - " $9 " (" $5 ")"}'
    echo ""
    
    log_ok "Backup completed successfully"
}

# =============================================================================
# PRODUCTION RESET
# =============================================================================

compose_reset() {
    log_info "═══════════════════════════════════════════════════════════"
    log_info "  PRODUCTION ENVIRONMENT RESET"
    log_info "═══════════════════════════════════════════════════════════"
    
    echo ""
    echo -e "${RED}⚠️  DANGER: Complete Production Environment Reset${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}This will permanently delete ALL production data:${NC}"
    echo -e "  ${RED}✗${NC} All containers (stopped and removed)"
    echo -e "  ${RED}✗${NC} All volumes (MySQL data, uploads, sessions)"
    echo -e "  ${RED}✗${NC} Production network"
    echo -e "  ${RED}✗${NC} Generated files (.env-prod, config.php, docker-compose.yml)"
    echo ""
    echo -e "${YELLOW}This operation is IRREVERSIBLE!${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "Are you ABSOLUTELY sure? Type 'DESTROY' to confirm: " confirm
    echo ""
    
    if [[ "$confirm" != "DESTROY" ]]; then
        log_info "Reset operation cancelled by user"
        echo -e "${GREEN}✅ No changes were made${NC}"
        return 0
    fi
    
    log_warn "Starting production environment destruction..."
    echo ""
    
    cd "$PROJECT_ROOT"
    
    # Step 1: Stop and remove containers
    log_info "Step 1/5: Stopping and removing containers..."
    local containers_found
    containers_found=$(docker ps -aq --filter "name=easyappointments" 2>/dev/null || true)
    
    if [[ -n "$containers_found" ]]; then
        # Stop containers first
        log_info "  Stopping containers..."
        docker stop $(docker ps -q --filter "name=easyappointments") 2>/dev/null || true
        
        # Remove containers
        log_info "  Removing containers..."
        docker rm $(docker ps -aq --filter "name=easyappointments") 2>/dev/null || true
        
        log_ok "Containers stopped and removed"
    else
        log_info "No containers to remove"
    fi
    
    # Remove production network
    log_info "  Removing production network..."
    if docker network inspect easyappointments_prod_app-network &>/dev/null; then
        docker network rm easyappointments_prod_app-network 2>/dev/null || true
        log_ok "Network removed"
    fi
    
    # Step 2: Remove production volumes
    echo ""
    log_info "Step 2/5: Removing production volumes..."
    local volumes_removed=0
    for volume in ea_mysql_data ea_storage ea_assets; do
        if docker volume inspect "$volume" &>/dev/null; then
            docker volume rm "$volume" 2>/dev/null && ((volumes_removed++)) || log_warn "Failed to remove volume: $volume (may be in use)"
        fi
    done
    if [[ $volumes_removed -gt 0 ]]; then
        log_ok "Removed $volumes_removed production volume(s)"
    else
        log_info "No volumes to remove"
    fi
    
    # Step 3: Remove generated files
    echo ""
    log_info "Step 3/3: Removing generated files..."
    local files_removed=0
    for file in "$ENV_FILE" "$CONFIG_FILE" "$COMPOSE_FILE"; do
        if [[ -f "$file" ]]; then
            rm -f "$file" && ((files_removed++))
        fi
    done
    if [[ $files_removed -gt 0 ]]; then
        log_ok "Removed $files_removed generated file(s)"
    else
        log_info "No files to remove"
    fi
    
    # Summary
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✅ PRODUCTION RESET COMPLETED${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Environment has been completely reset:${NC}"
    echo -e "  ${GREEN}✓${NC} Containers stopped and removed"
    echo -e "  ${GREEN}✓${NC} Volumes deleted (MySQL data, storage, assets)"
    echo -e "  ${GREEN}✓${NC} Network removed"
    echo -e "  ${GREEN}✓${NC} Generated files removed (.env-prod, config.php, docker-compose.yml)"
    echo ""
    echo -e "${CYAN}To set up production again, run:${NC}"
    echo -e "  ${WHITE}sudo ./deploy/deploy-production.sh up --initial${NC}"
    echo ""
    echo -e "${YELLOW}Note:${NC} Docker images were preserved for faster rebuilds."
    echo -e "      To remove images manually: ${WHITE}docker image prune -a${NC}"
    echo ""
    
    log_ok "Reset completed successfully"
}

# =============================================================================
# HELP & USAGE
# =============================================================================

show_help() {
    print_header
    
    cat << EOF
${WHITE}USAGE:${NC}
  $(basename "$0") COMMAND [OPTIONS]

${WHITE}COMMANDS:${NC}
  ${GREEN}up [--initial]${NC}    Start production environment
                        Use --initial for first-time setup

  ${YELLOW}down${NC}              Stop production environment

  ${BLUE}logs [-f] [SERVICE]${NC}
                        View logs (-f to follow, SERVICE to filter)

  ${PURPLE}health${NC}            Check health of all services

  ${CYAN}update${NC}            Update to latest version
                        (backup → pull → restart → migrate)

  ${WHITE}backup${NC}            Create full backup
                        (database + config + storage)

  ${CYAN}smoke-test${NC}        Validate Docker image integrity
                        Tests image before deploy (recommended)

  ${PURPLE}image-info${NC}        Show current image version and metadata

  ${PURPLE}check-updates${NC}     Check for new image versions available

  ${RED}reset${NC}             Complete production reset (DESTRUCTIVE!)
                        Removes all containers, volumes, network, and generated files

  ${WHITE}help${NC}              Show this help message

${WHITE}EXAMPLES:${NC}
  # First installation (prompts for ports, generates credentials)
  sudo $(basename "$0") up --initial

  # Start normally
  sudo $(basename "$0") up

  # Stop all services
  sudo $(basename "$0") down

  # View live logs
  $(basename "$0") logs -f

  # Check health
  $(basename "$0") health

  # Update application
  sudo $(basename "$0") update

  # Create backup
  sudo $(basename "$0") backup

  # Test image before deploy (recommended)
  $(basename "$0") smoke-test

  # Check current image version
  $(basename "$0") image-info

  # Check for available updates
  $(basename "$0") check-updates

  # Complete reset (DANGEROUS - removes everything)
  sudo $(basename "$0") reset

${WHITE}FILES:${NC}
  Config:     ${CONFIG_FILE}
  Compose:    ${COMPOSE_FILE}
  Env:        ${ENV_FILE}
  Backups:    ${PRODUCTION_BASE}/backups/
  Logs:       ${PRODUCTION_BASE}/logs/

${WHITE}ISOLATION:${NC}
  Project:    easyappointments_prod
  Volumes:    ea_mysql_data, ea_storage, ea_assets
  Containers: easyappointments-*

${WHITE}VERSION:${NC} ${SCRIPT_VERSION}

EOF
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    # Trap errors
    trap 'log_error "Script failed at line $LINENO"' ERR
    
    # Check if no arguments
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    # Parse command
    local command="$1"
    shift
    
    case "$command" in
        up)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            compose_up "$@"
            ;;
        
        down)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            compose_down
            ;;
        
        logs)
            ensure_prereqs
            ensure_compose
            ensure_env
            compose_logs "$@"
            ;;
        
        health)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            compose_health
            ;;
        
        update|pull)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            compose_update
            ;;
        
        backup)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            compose_backup
            ;;
        
        reset)
            print_header
            ensure_prereqs
            compose_reset
            ;;
        
        smoke-test|smoketest|test)
            print_header
            ensure_prereqs
            smoke_test
            ;;
        
        image-info|info|version)
            print_header
            ensure_prereqs
            show_image_info
            ;;
        
        check-updates|check)
            print_header
            ensure_prereqs
            detect_image_changes
            ;;
        
        help|--help|-h)
            show_help
            ;;
        
        *)
            log_error "Unknown command: ${command}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
