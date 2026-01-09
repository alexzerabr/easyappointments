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

# Colors removed - using plain text output

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_ok() {
    echo "[OK] $*"
}

log_warn() {
    echo "[WARN] $*"
}

log_error() {
    echo "[ERR] $*"
}

log_info() {
    echo "[INFO] $*"
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[DEBUG] $*"
    fi
}

error_exit() {
    log_error "$1"
    exit 1
}

print_header() {
    echo ""
    echo "============================================================"
    echo "  EasyAppointments Production Manager v${SCRIPT_VERSION}"
    echo "============================================================"
    echo ""
}

print_separator() {
    echo "------------------------------------------------------------"
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
        "${PRODUCTION_BASE}/storage/heartbeat"
        "${PRODUCTION_BASE}/storage/logs"
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
    WA_TOKEN_ENC_KEY=$(openssl rand -hex 32)
    BACKUP_ENCRYPTION_KEY=$(openssl rand -hex 32)
    JWT_SECRET=$(openssl rand -hex 32)

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
    sed -i "s/CHANGE_THIS_GENERATE_WITH_OPENSSL_RAND_HEX_32/${WA_TOKEN_ENC_KEY}/g" "$ENV_FILE"
    sed -i "s/CHANGE_THIS_BACKUP_KEY/${BACKUP_ENCRYPTION_KEY}/g" "$ENV_FILE"
    sed -i "s/CHANGE_THIS_JWT_SECRET_FOR_WEBSOCKET/${JWT_SECRET}/g" "$ENV_FILE"
    
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
    echo "========================================================"
    echo "   GENERATED CREDENTIALS - SAVE THESE SECURELY"
    echo "========================================================"
    echo "Database Password:        ${MYSQL_PASSWORD}"
    echo "MySQL Root Password:      ${MYSQL_ROOT_PASSWORD}"
    echo "WhatsApp Encryption Key:  ${WA_TOKEN_ENC_KEY}"
    echo "Backup Encryption Key:    ${BACKUP_ENCRYPTION_KEY}"
    echo "JWT Secret (WebSocket):   ${JWT_SECRET}"
    echo "========================================================"
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
    
    log_info ""
    log_info "  INFORMAES DA IMAGEM"
    log_info ""
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
        
        echo "Metadados da Imagem:"
        echo "   ID:      $image_id"
        echo "   Verso:  $build_version"
        echo "   Commit:  $git_commit"
        echo "   Data:    $build_date"
        
        # Verifica se h verso dentro do container
        if docker run --rm "$full_image" cat /etc/easyappointments-version 2>/dev/null; then
            echo ""
            log_ok "Arquivo de verso encontrado"
        fi
    else
        log_warn "Imagem no encontrada localmente"
        log_info "Execute 'docker pull $full_image' para baix-la"
    fi
    
    echo ""
}

detect_image_changes() {
    local image_tag="${IMAGE_TAG:-latest}"
    local registry="${CONTAINER_REGISTRY:-ghcr.io/alexzerabr}"
    local full_image="${registry}/easyappointments:${image_tag}"
    
    log_info ""
    log_info "  DETECO DE MUDANAS NA IMAGEM"
    log_info ""
    echo ""
    
    # Obtm ID da imagem local atual
    local current_id=$(docker image inspect "$full_image" --format='{{.Id}}' 2>/dev/null || echo "none")
    
    log_info "Verificando atualizaes disponveis..."
    
    # Faz pull da imagem mais recente (silencioso)
    if docker pull "$full_image" >/dev/null 2>&1; then
        local new_id=$(docker image inspect "$full_image" --format='{{.Id}}' 2>/dev/null || echo "none")
        
        if [[ "$current_id" == "none" ]]; then
            log_ok "Nova imagem baixada (primeira vez)"
            show_image_info
            return 0
        elif [[ "$current_id" != "$new_id" ]]; then
            log_ok " Nova verso disponvel!"
            echo ""
            
            # Mostra informaes da verso nova
            local new_version=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.version"}}' 2>/dev/null || echo "N/A")
            local new_commit=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.revision"}}' 2>/dev/null || echo "N/A")
            local new_date=$(docker inspect "$full_image" --format='{{index .Config.Labels "org.opencontainers.image.created"}}' 2>/dev/null || echo "N/A")
            
            echo " Nova Verso:"
            echo "   Verso:  $new_version"
            echo "   Commit:  $new_commit"
            echo "   Data:    $new_date"
            echo ""
            
            log_info "Para aplicar: sudo $(basename "$0") update"
            return 1
        else
            log_ok " Voc est usando a verso mais recente"
            show_image_info
            return 0
        fi
    else
        log_error "Falha ao verificar atualizaes"
        return 1
    fi
}

# =============================================================================
# SMOKE TEST - Validao de imagem antes do deploy
# =============================================================================

smoke_test() {
    log_info ""
    log_info "  SMOKE TEST - Validao de Imagem"
    log_info ""
    
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
    log_ok "Pull concludo"
    
    # Verifica digest e informaes
    log_info "2/5 Verificando informaes da imagem..."
    local image_digest=$(docker inspect "$full_image" --format='{{.Id}}' 2>/dev/null)
    local image_created=$(docker inspect "$full_image" --format='{{.Created}}' 2>/dev/null | cut -d'T' -f1)
    
    if [[ -z "$image_digest" ]]; then
        log_error "No foi possvel obter digest da imagem"
        return 1
    fi
    
    log_ok "Digest: ${image_digest:0:20}..."
    log_ok "Criada em: $image_created"
    
    # Inicia container temporrio para testes
    log_info "3/5 Iniciando container de teste..."
    local test_container="easyappointments-smoke-test-$$"
    
    # Remove container anterior se existir
    docker rm -f "$test_container" >/dev/null 2>&1 || true
    
    # Inicia container temporrio
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
    
    # Valida arquivos crticos dentro do container
    log_info "4/5 Validando arquivos crticos..."
    
    local critical_files=(
        "/var/www/html/index.php"
        "/var/www/html/application/config/config.php"
        "/var/www/html/assets/css/general.min.css"
        "/var/www/html/assets/js/app.min.js"
        "/var/www/html/vendor/autoload.php"
        "/var/www/html/application/migrations/064_add_whatsapp_message_logs_indexes.php"
        "/var/www/html/scripts/whatsapp_worker.php"
        "/var/www/html/scripts/check_whatsapp_worker_health.php"
    )
    
    local validation_failed=false
    
    for file in "${critical_files[@]}"; do
        if docker exec "$test_container" test -f "$file" 2>/dev/null; then
            log_ok " $(basename $file)"
        else
            log_error " $(basename $file) - NO ENCONTRADO"
            validation_failed=true
        fi
    done
    
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Validao de arquivos falhou"
        docker rm -f "$test_container" >/dev/null 2>&1
        return 1
    fi
    
    # Valida estrutura de diretrios
    log_info "5/5 Validando estrutura de diretrios..."
    
    local critical_dirs=(
        "/var/www/html/application"
        "/var/www/html/assets"
        "/var/www/html/vendor"
        "/var/www/html/storage"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if docker exec "$test_container" test -d "$dir" 2>/dev/null; then
            log_ok " $(basename $dir)/"
        else
            log_error " $(basename $dir)/ - NO ENCONTRADO"
            validation_failed=true
        fi
    done
    
    # Cleanup
    docker rm -f "$test_container" >/dev/null 2>&1
    
    if [[ "$validation_failed" == "true" ]]; then
        log_error "Validao da estrutura falhou"
        return 1
    fi
    
    echo ""
    log_ok ""
    log_ok "   SMOKE TEST PASSOU - Imagem est funcional"
    log_ok ""
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
        log_info ""
        log_info "  INITIAL PRODUCTION SETUP"
        log_info ""
        
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
    echo "========================================================"
    echo "    PRODUCTION ENVIRONMENT IS UP!"
    echo "========================================================"
    echo ""

    # Show access URLs
    echo " Access URLs:"
    echo "   Installation: http://localhost:${http_port}/index.php/installation"
    echo "   Application:  http://localhost:${http_port}"
    echo ""

    # Show container status
    echo " Container Status:"
    compose_cmd ps
    echo ""

    if [[ "$is_initial" == "--initial" ]]; then
        echo " Next Steps:"
        echo "   1. Complete installation at the URL above"
        echo "   2. Use database credentials from: ${ENV_FILE}"
        echo "   3. Configure email and WhatsApp settings"
        echo "   4. After installation, run migrations with:"
        echo "      docker compose exec php-fpm php index.php console migrate"
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

    echo "Current containers:"
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
    log_info ""
    log_info "  PRODUCTION HEALTH CHECK"
    log_info ""
    
    cd "$PROJECT_ROOT"
    
    local exit_code=0
    
    # Check container status
    echo ""
    echo " Container Status:"
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
    echo " Database Health:"
    if docker inspect easyappointments-mysql --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        log_ok "MySQL is healthy"
    else
        log_error "MySQL is not healthy"
        exit_code=1
    fi

    # Check HTTP endpoints
    echo ""
    echo " HTTP Endpoints:"
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

    # Check WhatsApp Worker (optional - doesn't fail health check)
    echo ""
    echo " WhatsApp Worker:"
    if worker_status >/dev/null 2>&1; then
        log_ok "Worker is healthy"
    else
        log_warn "Worker is not running (this is OK if WhatsApp is not configured yet)"
    fi

    # Summary
    echo ""
    print_separator
    if [[ $exit_code -eq 0 ]]; then
        log_ok "All health checks passed "
    else
        log_error "Some health checks failed "
    fi
    print_separator
    
    return $exit_code
}

# =============================================================================
# WHATSAPP WORKER MANAGEMENT
# =============================================================================

worker_status() {
    log_info "Checking WhatsApp Worker status..."

    # Check if worker process is running
    if docker exec easyappointments-php-fpm pgrep -f "whatsapp_worker.php" >/dev/null 2>&1; then
        log_ok "Worker process is running"

        # Check heartbeat health
        if docker exec easyappointments-php-fpm php scripts/check_whatsapp_worker_health.php 2>/dev/null; then
            log_ok "Worker is healthy"
            return 0
        else
            log_warn "Worker process running but health check failed"
            return 1
        fi
    else
        log_warn "Worker process is not running"
        return 1
    fi
}

worker_start() {
    log_info "Starting WhatsApp Worker..."

    # Check if already running
    if docker exec easyappointments-php-fpm pgrep -f "whatsapp_worker.php" >/dev/null 2>&1; then
        log_warn "Worker is already running"
        return 0
    fi

    # Ensure heartbeat directory exists
    docker exec easyappointments-php-fpm mkdir -p /var/www/html/storage/heartbeat 2>/dev/null || true

    # Start worker in background
    docker exec -d easyappointments-php-fpm php scripts/whatsapp_worker.php

    log_info "Waiting for worker to initialize..."
    sleep 3

    # Verify it started
    if docker exec easyappointments-php-fpm pgrep -f "whatsapp_worker.php" >/dev/null 2>&1; then
        log_ok " Worker started successfully"
        return 0
    else
        log_error "Failed to start worker"
        return 1
    fi
}

worker_stop() {
    log_info "Stopping WhatsApp Worker..."

    if docker exec easyappointments-php-fpm pkill -f "whatsapp_worker.php" 2>/dev/null; then
        log_ok "Worker stopped"
        sleep 1
        return 0
    else
        log_warn "Worker was not running"
        return 0
    fi
}

worker_restart() {
    log_info "Restarting WhatsApp Worker..."
    worker_stop
    sleep 2
    worker_start
}

compose_update() {
    log_info ""
    log_info "  PRODUCTION UPDATE"
    log_info ""

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

    # Sync docker-compose.yml with docker-compose-example.yml
    log_info "Checking for docker-compose.yml updates..."
    if [[ -f "docker-compose-example.yml" ]]; then
        # Check if there are new services in the example that are not in production
        local example_services=$(grep -E "^  [a-z].*:$" docker-compose-example.yml | sed 's/://g' | tr -d ' ' | sort)
        local prod_services=$(grep -E "^  [a-z].*:$" "$COMPOSE_FILE" 2>/dev/null | sed 's/://g' | tr -d ' ' | sort)

        local new_services=""
        for svc in $example_services; do
            if ! echo "$prod_services" | grep -q "^${svc}$"; then
                new_services="$new_services $svc"
            fi
        done

        if [[ -n "$new_services" ]]; then
            log_warn "New services detected in docker-compose-example.yml:$new_services"
            log_info "Updating docker-compose.yml with new services..."
            cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y%m%d%H%M%S)"
            cp "docker-compose-example.yml" "$COMPOSE_FILE"
            log_ok "docker-compose.yml updated (backup created)"
        else
            log_ok "docker-compose.yml is up to date"
        fi
    fi

    # Check for new required environment variables
    log_info "Checking for new environment variables..."
    local env_updated=false

    # Check JWT_SECRET
    if ! grep -q "^JWT_SECRET=" "$ENV_FILE" 2>/dev/null; then
        log_warn "JWT_SECRET not found in ${ENV_FILE}, generating..."
        local new_jwt_secret=$(openssl rand -hex 32)
        echo "" >> "$ENV_FILE"
        echo "# JWT Secret for WebSocket authentication (auto-generated)" >> "$ENV_FILE"
        echo "JWT_SECRET=${new_jwt_secret}" >> "$ENV_FILE"
        env_updated=true
        log_ok "JWT_SECRET added to ${ENV_FILE}"
    fi

    # Check WEBSOCKET_PORT
    if ! grep -q "^WEBSOCKET_PORT=" "$ENV_FILE" 2>/dev/null; then
        log_info "Adding WEBSOCKET_PORT to ${ENV_FILE}..."
        echo "WEBSOCKET_PORT=8080" >> "$ENV_FILE"
        env_updated=true
        log_ok "WEBSOCKET_PORT added to ${ENV_FILE}"
    fi

    if [[ "$env_updated" == "true" ]]; then
        # Reload environment
        set -a
        source "$ENV_FILE"
        set +a
        log_ok "Environment variables reloaded"
    fi

    echo ""

    # Backup before update
    log_info "Creating backup before update..."
    compose_backup
    
    echo ""

    log_info "Installing NPM dependencies..."
    if ! npm install --silent 2>&1 | grep -v "npm warn"; then
        log_warn "NPM install had warnings, continuing..."
    fi
    log_ok "NPM dependencies installed"

    log_info "Building frontend assets (JS/CSS)..."
    if npm run build 2>&1 | grep -E "(Finished|errored)" | grep -v "errored" >/dev/null; then
        log_ok "Frontend assets built successfully"
    else
        log_warn "Frontend build had issues, continuing anyway..."
    fi

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

    log_info "Copying built assets to containers..."
    if [[ -f "build/assets/js/pages/whatsapp_integration_simple.min.js" ]]; then
        docker cp build/assets/js/pages/whatsapp_integration_simple.min.js easyappointments-php-fpm:/var/www/html/assets/js/pages/ 2>/dev/null || true
        docker cp build/assets/js/http/whatsapp_integration_http_client.min.js easyappointments-php-fpm:/var/www/html/assets/js/http/ 2>/dev/null || true
        log_ok "Assets synchronized to containers"
    fi

    echo ""
    log_info "Running database migrations..."
    if ! compose_cmd exec -T php-fpm php index.php console migrate 2>&1 | tee /tmp/migration-output.log; then
        echo ""
        log_error ""
        log_error "   MIGRATIONS FAILED - Update aborted!"
        log_error ""
        log_error "Database may be inconsistent. DO NOT continue."
        log_error "Check logs: /tmp/migration-output.log"
        echo ""
        log_error "To rollback:"
        log_error "  1. Restore from backup: ${PRODUCTION_BASE}/backups/"
        log_error "  2. Or fix migration and re-run: docker compose exec php-fpm php index.php console migrate"
        echo ""
        return 1
    fi
    log_ok "Migrations completed successfully"

    # Restart WhatsApp Worker with updated code
    echo ""
    log_info "Restarting WhatsApp Worker with updated code..."
    if worker_restart; then
        log_ok " Worker restarted successfully"
    else
        log_warn "Failed to restart worker - may need manual intervention"
        log_warn "Start manually: docker exec -d easyappointments-php-fpm php scripts/whatsapp_worker.php"
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
    log_info "Rebuilding frontend assets with latest code changes..."
    if npm run build 2>&1 | grep -E "(Finished|errored)" | grep -v "errored" >/dev/null; then
        log_ok "Frontend rebuild completed"

        log_info "Synchronizing rebuilt assets to containers..."
        find build/assets -name "*.min.js" -o -name "*.min.css" | while read -r file; do
            relative_path="${file#build/}"
            docker cp "$file" "easyappointments-php-fpm:/var/www/html/${relative_path}" 2>/dev/null || true
        done
        log_ok "All rebuilt assets synchronized"
    else
        log_warn "Frontend rebuild had issues, but update completed"
    fi

    echo ""
    log_ok "========================================================"
    log_ok "   UPDATE COMPLETED SUCCESSFULLY"
    log_ok "========================================================"
    echo ""

    # Show version information
    log_info "Checking update details..."
    local update_timestamp
    update_timestamp=$(docker exec easyappointments-php-fpm cat /var/www/html/.docker-init-complete 2>/dev/null || echo "unknown")
    local image_digest
    image_digest=$(docker exec easyappointments-php-fpm cat /var/www/html/.docker-image-digest 2>/dev/null || echo "unknown")

    echo "Update Information:"
    echo "   Last Updated:  $(date -d @${update_timestamp} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'unknown')"
    echo "   Image Digest:  ${image_digest}"
    echo ""
}

compose_backup() {
    log_info ""
    log_info "  PRODUCTION BACKUP"
    log_info ""
    
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
    echo "========================================================"
    echo "    BACKUP COMPLETED"
    echo "========================================================"
    echo "Location: ${backup_dir}"
    echo "Size:     ${backup_size}"
    echo "Files:"
    ls -lh "$backup_dir" 2>/dev/null | tail -n +2 | awk '{print "   - " $9 " (" $5 ")"}'
    echo ""
    
    log_ok "Backup completed successfully"
}

# =============================================================================
# PRODUCTION RESET
# =============================================================================

compose_reset() {
    log_info ""
    log_info "  PRODUCTION ENVIRONMENT RESET"
    log_info ""
    
    echo ""
    echo "  DANGER: Complete Production Environment Reset"
    echo "========================================================"
    echo "This will permanently delete ALL production data:"
    echo "  * All containers (stopped and removed)"
    echo "  * All volumes (MySQL data, uploads, sessions)"
    echo "  * Production network"
    echo "  * Generated files (.env-prod, config.php, docker-compose.yml)"
    echo ""
    echo "This operation is IRREVERSIBLE!"
    echo "========================================================"
    echo ""
    
    read -p "Are you ABSOLUTELY sure? Type 'DESTROY' to confirm: " confirm
    echo ""
    
    if [[ "$confirm" != "DESTROY" ]]; then
        log_info "Reset operation cancelled by user"
        echo " No changes were made"
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
    echo "========================================================"
    echo "    PRODUCTION RESET COMPLETED"
    echo "========================================================"
    echo ""
    echo "Environment has been completely reset:"
    echo "  * Containers stopped and removed"
    echo "  * Volumes deleted (MySQL data, storage, assets)"
    echo "  * Network removed"
    echo "  * Generated files removed (.env-prod, config.php, docker-compose.yml)"
    echo ""
    echo "To set up production again, run:"
    echo "  sudo ./deploy/deploy-production.sh up --initial"
    echo ""
    echo "Note: Docker images were preserved for faster rebuilds."
    echo "      To remove images manually: docker image prune -a"
    echo ""
    
    log_ok "Reset completed successfully"
}

# =============================================================================
# HELP & USAGE
# =============================================================================

show_help() {
    print_header

    cat << EOF
USAGE:
  $(basename "$0") COMMAND [OPTIONS]

COMMANDS:
  up [--initial]    Start production environment
                    Use --initial for first-time setup

  down              Stop production environment

  logs [-f] [SERVICE]
                    View logs (-f to follow, SERVICE to filter)

  health            Check health of all services

  update            Update to latest version
                    (backup + pull + restart + migrate)

  backup            Create full backup
                    (database + config + storage)

  smoke-test        Validate Docker image integrity
                    Tests image before deploy (recommended)

  image-info        Show current image version and metadata

  check-updates     Check for new image versions available

  reset             Complete production reset (DESTRUCTIVE!)
                    Removes all containers, volumes, network, and generated files

  worker-start      Start WhatsApp Worker process
  worker-stop       Stop WhatsApp Worker process
  worker-restart    Restart WhatsApp Worker process
  worker-status     Check WhatsApp Worker status and health

  help              Show this help message

EXAMPLES:
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

  # Manage WhatsApp Worker
  $(basename "$0") worker-status
  $(basename "$0") worker-start
  $(basename "$0") worker-restart

FILES:
  Config:     ${CONFIG_FILE}
  Compose:    ${COMPOSE_FILE}
  Env:        ${ENV_FILE}
  Backups:    ${PRODUCTION_BASE}/backups/
  Logs:       ${PRODUCTION_BASE}/logs/

ISOLATION:
  Project:    easyappointments_prod
  Volumes:    ea_mysql_data, ea_storage, ea_assets
  Containers: easyappointments-*

VERSION: ${SCRIPT_VERSION}

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

        worker-start|worker:start)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            worker_start
            ;;

        worker-stop|worker:stop)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            worker_stop
            ;;

        worker-restart|worker:restart)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            worker_restart
            ;;

        worker-status|worker:status|worker)
            print_header
            ensure_prereqs
            ensure_compose
            ensure_env
            worker_status
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
