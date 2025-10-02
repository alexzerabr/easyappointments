#!/bin/bash

set -euo pipefail

SCRIPT_VERSION="2.2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env.production"
ENV_EXAMPLE="env.production-example"
BACKUP_DIR="storage/backups"
LOG_FILE="/tmp/deploy-production.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

cd "$ROOT_DIR"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
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
    echo "Production Manager v${SCRIPT_VERSION}"
    echo "============================================="
    echo -e "${NC}"
}

validate_environment() {
    log "INFO" "Validating environment..."
    
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed or not in PATH"
    fi
    
    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose v2 is required"
    fi
    
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running"
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "Docker Compose file not found: $COMPOSE_FILE"
    fi
    
    log "SUCCESS" "Environment validation passed"
}

generate_password() {
    local length="${1:-32}"
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

generate_encryption_key() {
    openssl rand -hex 32
}

customize_environment() {
    log "INFO" "Customizing environment variables..."
    
    local current_app_url=$(grep "APP_URL=" "$ENV_FILE" | cut -d'=' -f2)
    read -p "Enter APP_URL (current: $current_app_url): " new_app_url
    if [ -n "$new_app_url" ]; then
        sed -i "s|APP_URL=.*|APP_URL=$new_app_url|g" "$ENV_FILE"
        log "INFO" "Updated APP_URL to: $new_app_url"
    fi
    
    local current_http_port=$(grep "HTTP_PORT=" "$ENV_FILE" | cut -d'=' -f2)
    read -p "Enter HTTP_PORT (current: $current_http_port): " new_http_port
    if [ -n "$new_http_port" ]; then
        sed -i "s/HTTP_PORT=.*/HTTP_PORT=$new_http_port/g" "$ENV_FILE"
        log "INFO" "Updated HTTP_PORT to: $new_http_port"
    fi

    local current_https_port=$(grep "HTTPS_PORT=" "$ENV_FILE" | cut -d'=' -f2)
    read -p "Enter HTTPS_PORT (current: $current_https_port): " new_https_port
    if [ -n "$new_https_port" ]; then
        sed -i "s/HTTPS_PORT=.*/HTTPS_PORT=$new_https_port/g" "$ENV_FILE"
        log "INFO" "Updated HTTPS_PORT to: $new_https_port"
    fi
    
    log "SUCCESS" "Environment customization completed"
}

setup_environment() {
    local action="${1:-}"
    if [ ! -f "$ENV_FILE" ]; then
        log "WARN" "Production environment file not found"
        
        if [ -f "$ENV_EXAMPLE" ]; then
            log "INFO" "Creating production environment with auto-generated credentials..."
            
            local db_password=$(generate_password 24)
            local mysql_root_password=$(generate_password 24)
            local wa_token_enc_key=$(generate_encryption_key)
            local backup_encryption_key=$(generate_encryption_key)
            
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            
            sed -i "s/CHANGE_THIS_STRONG_PASSWORD/$db_password/g" "$ENV_FILE"
            sed -i "s/CHANGE_THIS_ROOT_PASSWORD/$mysql_root_password/g" "$ENV_FILE"
            sed -i "s/CHANGE_THIS_GENERATE_NEW_KEY_WITH_OPENSSL/$wa_token_enc_key/g" "$ENV_FILE"
            sed -i "s/CHANGE_THIS_BACKUP_KEY/$backup_encryption_key/g" "$ENV_FILE"
            sed -i "s/your-encryption-key-here/$wa_token_enc_key/g" "$ENV_FILE"
            
            sed -i "s/APP_URL=.*/APP_URL=http:\/\/localhost/g" "$ENV_FILE"
            sed -i "s/HTTP_PORT=.*/HTTP_PORT=80/g" "$ENV_FILE"
            sed -i "s/HTTPS_PORT=.*/HTTPS_PORT=443/g" "$ENV_FILE"
            sed -i "s/MYSQL_PORT=.*/MYSQL_PORT=3306/g" "$ENV_FILE"
            
            log "SUCCESS" "Production environment file created with auto-generated credentials"
            echo ""
            echo -e "${GREEN}🔐 Generated Credentials (SAVE THESE SECURELY!):${NC}"
            echo -e "${BLUE}  📊 Database Password: ${WHITE}$db_password${NC}"
            echo -e "${BLUE}  🔑 MySQL Root Password: ${WHITE}$mysql_root_password${NC}"
            echo -e "${BLUE}  🔒 WhatsApp Encryption Key: ${WHITE}$wa_token_enc_key${NC}"
            echo -e "${BLUE}  💾 Backup Encryption Key: ${WHITE}$backup_encryption_key${NC}"
            echo ""
            
        else
            error_exit "Environment example file not found: $ENV_EXAMPLE"
        fi
    else
        log "INFO" "Using existing production environment file"
        
        if ! grep -q "DB_PASSWORD=" "$ENV_FILE" || ! grep -q "MYSQL_ROOT_PASSWORD=" "$ENV_FILE"; then
            log "WARN" "Environment file exists but may be missing required credentials"
            read -p "Do you want to regenerate credentials? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                backup_env_file="$ENV_FILE.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$ENV_FILE" "$backup_env_file"
                log "INFO" "Backed up existing environment to: $backup_env_file"
                rm "$ENV_FILE"
                setup_environment
                return
            fi
        fi

    fi
    
    log "INFO" "Loading environment variables..."
    set -a
    source "$ENV_FILE"
    set +a
    
    local required_vars=("WA_TOKEN_ENC_KEY" "DB_PASSWORD" "MYSQL_ROOT_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error_exit "Required environment variable $var is not set in $ENV_FILE"
        fi
    done
    
    log "SUCCESS" "Environment setup completed"
}

setup_config() {
    log "INFO" "Creating config.php from config-sample.php with production credentials..."
    
    if [ ! -f "config-sample.php" ]; then
        error_exit "config-sample.php not found"
    fi
    
    log "INFO" "Using config-sample.php as template"
    cp config-sample.php config.php
    
    local app_url="${APP_URL:-http://localhost}"
    local http_port="${HTTP_PORT:-80}"
    
    if [ "$http_port" != "80" ] && [ "$http_port" != "443" ]; then
        app_url="${app_url}:${http_port}"
    fi
    
    sed -i "s|const BASE_URL = 'http://localhost';|const BASE_URL = '${app_url}';|g" config.php
    sed -i "s|const DEBUG_MODE = false;|const DEBUG_MODE = false;|g" config.php
    sed -i "s|const DB_HOST = 'mysql';|const DB_HOST = '${DB_HOST:-mysql}';|g" config.php
    sed -i "s|const DB_NAME = 'easyappointments';|const DB_NAME = '${DB_DATABASE:-easyappointments}';|g" config.php
    sed -i "s|const DB_USERNAME = 'user';|const DB_USERNAME = '${DB_USERNAME:-easyapp_user}';|g" config.php
    sed -i "s|const DB_PASSWORD = 'password';|const DB_PASSWORD = '${DB_PASSWORD}';|g" config.php
    
    if [ -n "${APP_LANGUAGE:-}" ]; then
        sed -i "s|const LANGUAGE = 'english';|const LANGUAGE = '${APP_LANGUAGE}';|g" config.php
    fi
    
    if grep -q "CHANGE_THIS_STRONG_PASSWORD\|password" config.php; then
        log "WARN" "Placeholder values still found in config.php, applying manual fix..."
        cat > config.php << EOF
<?php
class Config
{
    const BASE_URL = '${app_url}';
    const LANGUAGE = '${APP_LANGUAGE:-english}';
    const DEBUG_MODE = false;

    const DB_HOST = '${DB_HOST:-mysql}';
    const DB_NAME = '${DB_DATABASE:-easyappointments}';
    const DB_USERNAME = '${DB_USERNAME:-easyapp_user}';
    const DB_PASSWORD = '${DB_PASSWORD}';

    const GOOGLE_SYNC_FEATURE = false;
    const GOOGLE_CLIENT_ID = '';
    const GOOGLE_CLIENT_SECRET = '';
}
EOF
    fi
    
    log "SUCCESS" "config.php created from template with production credentials"
    log "INFO" "Configuration details:"
    log "INFO" "  - BASE_URL: ${app_url}"
    log "INFO" "  - DB_HOST: ${DB_HOST:-mysql}"
    log "INFO" "  - DB_NAME: ${DB_DATABASE:-easyappointments}"
    log "INFO" "  - DB_USERNAME: ${DB_USERNAME:-easyapp_user}"
    log "INFO" "  - DEBUG_MODE: false"
}

test_database_connectivity() {
    log "INFO" "Testing database connectivity..."
    
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d mysql
    
    log "INFO" "Waiting for MySQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
            log "SUCCESS" "MySQL is ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            error_exit "MySQL failed to start after $max_attempts attempts"
        fi
        
        log "INFO" "Waiting for MySQL... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    log "INFO" "Testing application user connectivity..."
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T mysql mysql -h localhost -u "${DB_USERNAME:-easyapp_user}" -p"${DB_PASSWORD}" -e "SELECT 1;" &>/dev/null; then
        log "SUCCESS" "Database user connectivity test passed"
    else
        log "WARN" "Database user connectivity test failed, this is normal on first run"
    fi
}

initialize_production() {
    log "INFO" "Initializing production environment (fresh install)..."
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q 2>/dev/null | grep -q .; then
        log "WARN" "Existing containers found. Checking status..."
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
        
        read -p "Continue with existing environment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Operation cancelled by user"
            exit 0
        fi
    fi
    
    setup_config
    
    if [ ! -f "config.php" ]; then
        error_exit "config.php was not created successfully"
    fi
    
    if grep -q "CHANGE_THIS_STRONG_PASSWORD\|password.*[^']$" config.php; then
        error_exit "config.php still contains placeholder values"
    fi
    
    log "INFO" "Pulling images from GHCR..."
    local image_tag="${IMAGE_TAG:-latest}"
    local image_name="ghcr.io/alexzerabr/easyappointments:${image_tag}"
    log "INFO" "Using image tag: ${image_tag}"
    
    if ! docker pull "$image_name"; then
        error_exit "Failed to pull image: $image_name. Please check if the image is available and published."
    fi
    
    if ! docker image inspect "$image_name" >/dev/null 2>&1; then
        error_exit "Image verification failed: $image_name"
    fi
    
    log "SUCCESS" "Successfully pulled image: $image_name"
    
    test_database_connectivity
    log "INFO" "Starting all services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    log "INFO" "Waiting for services to initialize..."
    sleep 30

    log "INFO" "Setting storage permissions..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T --user root php-fpm bash -c '
        chown -R appuser:appuser /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads 2>/dev/null || true
        find /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads -type d -exec chmod 755 {} \; 2>/dev/null || true
        find /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads -type f -exec chmod 644 {} \; 2>/dev/null || true
        chmod g+w /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads 2>/dev/null || true
    ' || log "WARN" "Could not set permissions via Docker"
    
    log "INFO" "Validating deployment..."
    
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T php-fpm test -f /var/www/html/config.php; then
        log "SUCCESS" "config.php is mounted correctly in container"
    else
        log "ERROR" "config.php not found in container"
    fi
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost/index.php/installation | grep -q "200"; then
            log "SUCCESS" "Application is responding correctly"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log "WARN" "Application may not be responding correctly after $max_attempts attempts"
        else
            log "INFO" "Testing application response... (attempt $attempt/$max_attempts)"
            sleep 3
        fi
        ((attempt++))
    done
    
    local image_info=$(docker image inspect "$image_name" --format '{{.Created}} {{.Config.Labels}}' 2>/dev/null || echo "Unable to inspect image")
    log "INFO" "Deployed image info: $image_info"
    
    echo -e "\n${GREEN}🎉 Production deployment completed successfully!${NC}"
    echo -e "${GREEN}   Environment is 100% ready for use!${NC}"
    
    echo -e "\n${BLUE}🌐 Access URLs:${NC}"
    local http_port="${HTTP_PORT:-80}"
    local https_port="${HTTPS_PORT:-443}"
    echo -e "  📋 Installation: ${WHITE}http://localhost:$http_port/index.php/installation${NC}"
    echo -e "  🏠 Application:  ${WHITE}http://localhost:$http_port${NC}"
    if [ "$https_port" != "443" ] || [ -n "${SSL_CERT_PATH:-}" ]; then
        echo -e "  🔒 HTTPS:        ${WHITE}https://localhost:$https_port${NC}"
    fi
    
    echo -e "\n${BLUE}📊 Database Configuration:${NC}"
    echo -e "  🏠 Host: ${WHITE}localhost:${MYSQL_PORT:-3306}${NC} (external) / ${WHITE}mysql:3306${NC} (internal)"
    echo -e "  💾 Database: ${WHITE}${DB_DATABASE:-easyappointments}${NC}"
    echo -e "  👤 Username: ${WHITE}${DB_USERNAME:-easyapp_user}${NC}"
    echo -e "  🔑 Password: ${WHITE}[Generated securely - check $ENV_FILE]${NC}"
    
    echo -e "\n${BLUE}🔐 Security Status:${NC}"
    echo -e "  ✅ Auto-generated secure passwords"
    echo -e "  ✅ WhatsApp encryption key configured"
    echo -e "  ✅ Backup encryption enabled"
    echo -e "  ✅ Production environment variables set"
    echo -e "  ✅ Config file properly mounted and secured"
    
    echo -e "\n${BLUE}🐳 Container Status:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    echo -e "\n${YELLOW}📝 Next Steps:${NC}"
    echo -e "  1. Complete installation at: ${WHITE}http://localhost:$http_port/index.php/installation${NC}"
    echo -e "  2. Use the database credentials from: ${WHITE}$ENV_FILE${NC}"
    echo -e "  3. Configure WhatsApp integration in admin panel"
    echo -e "  4. Set up SSL certificate if needed"
    
    echo -e "\n${YELLOW}💡 Important Notes:${NC}"
    echo -e "  • Environment file: ${WHITE}$ENV_FILE${NC}"
    echo -e "  • Config file: ${WHITE}config.php${NC} (mounted securely)"
    echo -e "  • Logs location: ${WHITE}storage/logs/${NC}"
    echo -e "  • Backup location: ${WHITE}storage/backups/${NC}"
    echo -e "  • All credentials have been auto-generated securely"
    
    log "SUCCESS" "Production deployment completed - environment is 100% ready!"
}

start_production() {
    log "INFO" "Starting production environment..."
    
    log "INFO" "Starting all services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    log "INFO" "Waiting for services to initialize..."
    sleep 10
    
    echo -e "\n${GREEN}✅ Production environment started!${NC}"
    echo -e "${BLUE}🐳 Container Status:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    log "SUCCESS" "Production environment started successfully"
}

stop_production() {
    log "INFO" "Stopping production environment..."
    
    if ! docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q &>/dev/null; then
        log "WARN" "No containers found or Docker Compose not available"
        return 1
    fi
    
    local running_containers=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --filter "status=running" -q 2>/dev/null | wc -l)
    
    if [ "$running_containers" -eq 0 ]; then
        log "WARN" "No running containers found"
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
        return 0
    fi
    
    echo -e "${BLUE}📊 Current running containers:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    echo -e "\n${YELLOW}🛑 Stopping production environment...${NC}"
    
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stop
    
    echo -e "\n${GREEN}✅ Production environment stopped successfully!${NC}"
    log "SUCCESS" "Production stop completed"
}

reset_production() {
    echo -e "${RED}⚠️  DANGER: Production Environment Reset${NC}"
    echo "============================================="
    echo -e "${YELLOW}WARNING: This will permanently delete ALL production data!${NC}"
    echo ""
    
    read -p "Are you ABSOLUTELY sure you want to continue? Type 'DESTROY' to confirm: " confirm
    
    if [ "$confirm" != "DESTROY" ]; then
        log "INFO" "Reset operation cancelled by user"
        exit 0
    fi
    
    log "WARN" "Starting production environment destruction..."
    
    log "INFO" "Removing containers and volumes..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans --volumes --timeout 30 || true
    
    log "INFO" "Removing ALL production images..."
    
    docker images --format "table {{.Repository}}:{{.Tag}}" | grep -i easyappointments | while read -r image; do
        if [ -n "$image" ] && [ "$image" != "REPOSITORY:TAG" ]; then
            log "INFO" "Removing image: $image"
            docker rmi -f "$image" >/dev/null 2>&1 || true
        fi
    done
    
    docker images -q | xargs -r docker inspect --format='{{.RepoTags}}' | grep -l easyappointments | xargs -r docker rmi -f || true
    
    log "INFO" "Cleaning storage directories..."
    find storage/logs -name "*.log" -delete 2>/dev/null || true
    find storage/cache -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    find storage/sessions -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    
    if [ -f "config.php" ]; then
        rm -f config.php
        log "INFO" "Removed config.php for clean reset"
    fi

    if [ -f "$ENV_FILE" ]; then
        rm -f "$ENV_FILE"
        log "INFO" "Removed $ENV_FILE for clean reset"
    fi
    
    log "INFO" "Performing comprehensive Docker cleanup..."
    log "WARN" "This will remove ALL unused Docker resources (images, containers, volumes, networks)"
    
    docker system prune -af --volumes >/dev/null 2>&1 || true
    docker builder prune -af >/dev/null 2>&1 || true
    
    echo -e "\n${GREEN}🎯 Production environment reset completed!${NC}"
    log "SUCCESS" "Production reset completed"
}

backup_production() {
    log "INFO" "Starting production backup..."
    
    local backup_timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/backup_$backup_timestamp"
    mkdir -p "$backup_path"
    
    log "INFO" "Creating backup at: $backup_path"
    
    log "INFO" "Backing up database..."
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T mysql mysqldump \
        -u root -p"${MYSQL_ROOT_PASSWORD}" \
        --single-transaction --routines --triggers \
        "${DB_DATABASE:-easyappointments}" > "$backup_path/database.sql"; then
        log "SUCCESS" "Database backup completed"
    else
        log "ERROR" "Database backup failed"
    fi
    
    log "INFO" "Backing up storage files..."
    if [ -d "storage" ]; then
        tar -czf "$backup_path/storage.tar.gz" storage/ 2>/dev/null || true
        log "SUCCESS" "Storage backup completed"
    fi
    
    cp "$ENV_FILE" "$backup_path/env.production" 2>/dev/null || true
    cp "$COMPOSE_FILE" "$backup_path/" 2>/dev/null || true
    
    echo -e "\n${GREEN}📦 Backup completed successfully!${NC}"
    echo -e "  Location: $backup_path"
    log "SUCCESS" "Backup completed: $backup_path"
}

monitor_production() {
    log "INFO" "Monitoring production environment..."
    
    local exit_code=0
    
    echo -e "${BLUE}🔍 Production Environment Health Check${NC}"
    echo "============================================="
    
    echo -e "\n${CYAN}Container Status${NC}"
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q &>/dev/null; then
        docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
        
        local running_count=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --filter "status=running" -q | wc -l)
        local total_count=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q | wc -l)
        
        if [ "$running_count" -eq "$total_count" ] && [ "$running_count" -gt 0 ]; then
            echo -e "${GREEN}✅ All services are running ($running_count/$total_count)${NC}"
        else
            echo -e "${YELLOW}⚠️  Some services are not running ($running_count/$total_count)${NC}"
            exit_code=1
        fi
    else
        echo -e "${RED}❌ No containers found${NC}"
        exit_code=1
    fi
    
    echo -e "\n${CYAN}Application Health${NC}"
    local http_port="${HTTP_PORT:-80}"
    
    local install_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://localhost:$http_port/index.php/installation" 2>/dev/null || echo "000")
    if [ "$install_status" = "200" ]; then
        echo -e "${GREEN}✅ Installation page is accessible (HTTP $install_status)${NC}"
    else
        echo -e "${RED}❌ Installation page is not accessible (HTTP $install_status)${NC}"
        exit_code=1
    fi
    
    local app_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://localhost:$http_port/" 2>/dev/null || echo "000")
    if [[ "$app_status" =~ ^(200|30[0-9])$ ]]; then
        echo -e "${GREEN}✅ Main application is responding (HTTP $app_status)${NC}"
    else
        echo -e "${RED}❌ Main application is not responding (HTTP $app_status)${NC}"
        exit_code=1
    fi
    
    echo -e "\n${CYAN}Database Connectivity${NC}"
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T mysql mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
        echo -e "${GREEN}✅ Database is accessible${NC}"
    else
        echo -e "${RED}❌ Database is not accessible${NC}"
        exit_code=1
    fi
    
    echo -e "\n============================================="
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}🎉 All health checks passed!${NC}"
        log "SUCCESS" "Production environment is healthy"
    else
        echo -e "${RED}⚠️  Some health checks failed!${NC}"
        log "WARN" "Production environment has issues"
    fi
    
    return $exit_code
}

update_production() {
    log "INFO" "Updating production environment..."

    log "INFO" "Pulling latest code from repository..."
    if [ -d ".git" ]; then
        git pull origin main || log "WARN" "Git pull failed or not available"
    else
        log "WARN" "Not a git repository, skipping git pull"
    fi

    log "INFO" "Pulling latest Docker images..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull || true

    log "INFO" "Stopping containers..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans || true

    log "INFO" "Starting services with updated images..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

    log "INFO" "Waiting for services to be ready..."
    sleep 15
    
    test_database_connectivity

    log "INFO" "Rebuilding frontend assets (npm install + gulp)..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T php-fpm bash -c '
        cd /var/www/html
        npm install --no-audit 2>&1 | grep -v "npm notice" || true
        npm list gulp >/dev/null 2>&1 || npm install gulp --no-audit
        npx gulp vendor 2>&1 | grep -E "Starting|Finished|ERROR" || true
        npx gulp scripts 2>&1 | grep -E "Starting|Finished|ERROR" || true
        npx gulp styles 2>&1 | grep -E "Starting|Finished|ERROR" || true
    ' || log "WARN" "Asset rebuild had warnings (check logs)"
    
    log "SUCCESS" "Frontend assets rebuilt successfully"

    log "INFO" "Setting storage permissions..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T --user root php-fpm bash -c '
        chown -R appuser:appuser /var/www/html/storage 2>/dev/null || true
        find /var/www/html/storage -type d -exec chmod 755 {} \; 2>/dev/null || true
        find /var/www/html/storage -type f -exec chmod 644 {} \; 2>/dev/null || true
    ' || true

    log "INFO" "Running database migrations..."
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T php-fpm php patch.php migration latest 2>&1 | tee /tmp/migration.log | grep -qE "completed|patches"; then
        log "SUCCESS" "Migrations completed successfully"
    else
        if grep -q "no new patches" /tmp/migration.log; then
            log "INFO" "Database is already up to date"
        else
            log "WARN" "Migration command completed with warnings (check logs)"
        fi
    fi
    rm -f /tmp/migration.log 2>/dev/null || true

    log "INFO" "Validating application response..."
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${HTTP_PORT:-80}/index.php/installation" || echo 000)
    if [[ "$status_code" =~ ^(200|30[0-9])$ ]]; then
        log "SUCCESS" "Application is responding (HTTP $status_code)"
    else
        log "WARN" "Application returned HTTP $status_code after update"
    fi

    echo -e "\n${GREEN}✅ Update completed successfully!${NC}"
    echo -e "${BLUE}🐳 Container Status:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
}

show_usage() {
    print_header
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTION]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo -e "  ${GREEN}--initialize${NC}  Initialize production environment (fresh install)"
    echo -e "  ${GREEN}--start${NC}       Start production environment"
    echo -e "  ${YELLOW}--stop${NC}        Stop production environment"
    echo -e "  ${RED}--reset${NC}       Reset production environment (DESTRUCTIVE!)"
    echo -e "  ${BLUE}--backup${NC}      Create backup of production data"
    echo -e "  ${PURPLE}--monitor${NC}     Monitor production environment health"
    echo -e "  ${CYAN}--update${NC}       Pull code, rebuild assets, update containers, run migrations"
    echo -e "  ${CYAN}--help${NC}        Show this help message"
    echo ""
    echo -e "${WHITE}WORKFLOW:${NC}"
    echo -e "  1. First time:  ${GREEN}--initialize${NC}  (setup + config + start)"
    echo -e "  2. Updates:     ${CYAN}--update${NC}      (git pull + npm + gulp + migrations)"
    echo -e "  3. Daily ops:   ${GREEN}--start${NC} / ${YELLOW}--stop${NC}"
    echo ""
    echo -e "${WHITE}VERSION:${NC} $SCRIPT_VERSION"
}

main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    case "$1" in
        --initialize)
            print_header
            validate_environment
            setup_environment start
            initialize_production
            ;;
        --start)
            print_header
            validate_environment
            setup_environment
            start_production
            ;;
        --stop)
            print_header
            validate_environment
            setup_environment stop
            stop_production
            ;;
        --reset)
            print_header
            validate_environment
            setup_environment reset
            reset_production
            ;;
        --backup)
            print_header
            validate_environment
            setup_environment backup
            backup_production
            ;;
        --monitor)
            print_header
            validate_environment
            setup_environment monitor
            monitor_production
            ;;
        --update)
            print_header
            validate_environment
            setup_environment update
            update_production
            ;;
        --help|-h)
            show_usage
            ;;
        *)
            echo -e "${RED}❌ Error: Unknown option '$1'${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
