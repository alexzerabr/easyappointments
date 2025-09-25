#!/bin/bash

# Easy!Appointments Unified Production Deployment Script
# Version: 2.0
# Author: Unified Deployment System
# 
# This script consolidates all production deployment operations into a single tool.
# It replaces the previous deploy-production.sh, reset-production.sh, and stop-production.sh scripts.
#
# USAGE:
#   ./deploy/deploy-production.sh --start     # Start production environment
#   ./deploy/deploy-production.sh --stop      # Stop production environment
#   ./deploy/deploy-production.sh --reset     # Reset production environment (DESTRUCTIVE!)
#   ./deploy/deploy-production.sh --backup    # Create backup of production data
#   ./deploy/deploy-production.sh --monitor   # Monitor production environment health

set -euo pipefail

# Script configuration
SCRIPT_VERSION="2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env.production"
ENV_EXAMPLE="env.production-example"
BACKUP_DIR="storage/backups"
LOG_FILE="storage/logs/deploy-production.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Change to project root
cd "$ROOT_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    # Output to console with colors
    case "$level" in
        "ERROR")   echo -e "${RED}❌ ERROR: $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}⚠️  WARNING: $message${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ️  INFO: $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ SUCCESS: $message${NC}" ;;
        "DEBUG")   echo -e "${PURPLE}🐛 DEBUG: $message${NC}" ;;
        *)         echo -e "${WHITE}📝 $message${NC}" ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Header
print_header() {
    echo -e "${CYAN}"
    echo "============================================="
    echo "🚀 Easy!Appointments Production Manager v${SCRIPT_VERSION}"
    echo "============================================="
    echo -e "${NC}"
}

# Validate environment
validate_environment() {
    log "INFO" "Validating environment..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed or not in PATH"
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose v2 is required"
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running"
    fi
    
    # Check compose file
    if [ ! -f "$COMPOSE_FILE" ]; then
        error_exit "Docker Compose file not found: $COMPOSE_FILE"
    fi
    
    log "SUCCESS" "Environment validation passed"
}

# Setup environment file
setup_environment() {
    if [ ! -f "$ENV_FILE" ]; then
        log "WARN" "Production environment file not found"
        
        if [ -f "$ENV_EXAMPLE" ]; then
            log "INFO" "Creating production environment from example..."
            
            # Generate secure credentials
            local db_password=$(openssl rand -base64 24)
            local mysql_root_password=$(openssl rand -base64 24)
            local wa_token_key=$(openssl rand -base64 32)
            local backup_key=$(openssl rand -base64 32)
            
            # Copy example and replace placeholders
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            
            # Replace placeholder values with generated ones
            sed -i "s/CHANGE_THIS_STRONG_PASSWORD/$db_password/g" "$ENV_FILE"
            sed -i "s/CHANGE_THIS_ROOT_PASSWORD/$mysql_root_password/g" "$ENV_FILE"
            sed -i "s/CHANGE_THIS_GENERATE_NEW_KEY_WITH_OPENSSL/$wa_token_key/g" "$ENV_FILE"
            sed -i "s/CHANGE_THIS_BACKUP_KEY/$backup_key/g" "$ENV_FILE"
            
            log "SUCCESS" "Production environment file created with secure credentials"
            log "INFO" "DB Password: $db_password"
            log "INFO" "MySQL Root Password: $mysql_root_password"
        else
            error_exit "Neither $ENV_FILE nor $ENV_EXAMPLE found"
        fi
    fi
    
    # Load environment variables
    log "INFO" "Loading environment variables..."
    set -a
    source "$ENV_FILE"
    set +a
    
    # Validate required variables
    local required_vars=("WA_TOKEN_ENC_KEY" "DB_PASSWORD" "MYSQL_ROOT_PASSWORD")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            error_exit "Required environment variable $var is not set in $ENV_FILE"
        fi
    done
    
    log "SUCCESS" "Environment setup completed"
}


# Setup config.php from sample
setup_config() {
    log "INFO" "Creating config.php from config-sample.php with production credentials..."
    
    if [ ! -f "config-sample.php" ]; then
        error_exit "config-sample.php not found"
    fi
    
    # Always use config-sample.php as the base template
    log "INFO" "Using config-sample.php as template"
    cp config-sample.php config.php
    
    # Replace placeholders with actual values from environment
    local app_url="${APP_URL:-http://localhost}"
    local http_port="${HTTP_PORT:-80}"
    
    # If using non-standard HTTP port, include it in BASE_URL
    if [ "$http_port" != "80" ] && [ "$http_port" != "443" ]; then
        app_url="${app_url}:${http_port}"
    fi
    
    # Update config.php with production values
    sed -i "s|const BASE_URL = 'http://localhost';|const BASE_URL = '${app_url}';|g" config.php
    sed -i "s|const DEBUG_MODE = false;|const DEBUG_MODE = false;|g" config.php
    sed -i "s|const DB_HOST = 'mysql';|const DB_HOST = '${DB_HOST:-mysql}';|g" config.php
    sed -i "s|const DB_NAME = 'easyappointments';|const DB_NAME = '${DB_DATABASE:-easyappointments}';|g" config.php
    sed -i "s|const DB_USERNAME = 'user';|const DB_USERNAME = '${DB_USERNAME:-easyapp_user}';|g" config.php
    sed -i "s|const DB_PASSWORD = 'password';|const DB_PASSWORD = '${DB_PASSWORD}';|g" config.php
    
    # Set production language if specified
    if [ -n "${APP_LANGUAGE:-}" ]; then
        sed -i "s|const LANGUAGE = 'english';|const LANGUAGE = '${APP_LANGUAGE}';|g" config.php
    fi
    
    log "SUCCESS" "config.php created from template with production credentials"
    log "INFO" "Configuration details:"
    log "INFO" "  - BASE_URL: ${app_url}"
    log "INFO" "  - DB_HOST: ${DB_HOST:-mysql}"
    log "INFO" "  - DB_NAME: ${DB_DATABASE:-easyappointments}"
    log "INFO" "  - DB_USERNAME: ${DB_USERNAME:-easyapp_user}"
    log "INFO" "  - DEBUG_MODE: false"
}

# Start production environment
start_production() {
    log "INFO" "Starting production environment..."
    
    # Check for existing containers
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
    
    # Setup config.php with production credentials
    setup_config
    
    # Pull latest images
    log "INFO" "Pulling latest images..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" pull
    
    # Build production images
    log "INFO" "Building production images..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build --no-cache
    
    # Start services
    log "INFO" "Starting services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    # Wait for services to be ready
    log "INFO" "Waiting for services to initialize..."
    sleep 30

    # Set permissions
    log "INFO" "Setting storage permissions..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T --user root php-fpm bash -c '
        chown -R appuser:appuser /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads 2>/dev/null || true
        find /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads -type d -exec chmod 755 {} \; 2>/dev/null || true
        find /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads -type f -exec chmod 644 {} \; 2>/dev/null || true
        chmod g+w /var/www/html/storage/sessions /var/www/html/storage/cache /var/www/html/storage/uploads 2>/dev/null || true
    ' || log "WARN" "Could not set permissions via Docker"
    
    # Basic validation
    log "INFO" "Validating deployment..."
    
    # Check if config.php was created successfully
    if [ -f "config.php" ]; then
        log "SUCCESS" "config.php created successfully"
    else
        log "ERROR" "config.php not found"
    fi
    
    # Give containers time to initialize
    log "INFO" "Waiting for services to initialize..."
    sleep 10
    
    # Display status
    echo -e "\n${GREEN}🎉 Production environment started successfully!${NC}\n"
    echo -e "${BLUE}📊 Service Status:${NC}"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    echo -e "\n${BLUE}🌐 Access URLs:${NC}"
    local http_port="${HTTP_PORT:-80}"
    echo -e "  Installation: http://localhost:$http_port/index.php/installation"
    echo -e "  Application:  http://localhost:$http_port"
    
    echo -e "\n${BLUE}📊 Database Info:${NC}"
    echo -e "  Host: localhost:${MYSQL_PORT:-3306} (external) / mysql:3306 (internal)"
    echo -e "  Database: ${DB_DATABASE:-easyappointments}"
    echo -e "  Username: ${DB_USERNAME:-user}"
    
    log "SUCCESS" "Production start completed"
}

# Stop production environment
stop_production() {
    log "INFO" "Stopping production environment..."
    
    # Check if containers are running
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
    
    # Stop all services gracefully
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" stop
    
    echo -e "\n${GREEN}✅ Production environment stopped successfully!${NC}"
    log "SUCCESS" "Production stop completed"
}

# Reset production environment (simplified version)
reset_production() {
    echo -e "${RED}⚠️  DANGER: Production Environment Reset${NC}"
    echo "============================================="
    echo -e "${YELLOW}WARNING: This will permanently delete ALL production data!${NC}"
    echo ""
    
    # Confirmation
    read -p "Are you ABSOLUTELY sure you want to continue? Type 'DESTROY' to confirm: " confirm
    
    if [ "$confirm" != "DESTROY" ]; then
        log "INFO" "Reset operation cancelled by user"
        exit 0
    fi
    
    log "WARN" "Starting production environment destruction..."
    
    # Stop and remove containers with volumes
    log "INFO" "Removing containers and volumes..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans --volumes --timeout 30 || true
    
    # Remove production images
    log "INFO" "Removing production images..."
    docker images -q "easyappointments-*" 2>/dev/null | xargs -r docker rmi -f || true
    
    # Clean storage
    log "INFO" "Cleaning storage directories..."
    find storage/logs -name "*.log" -delete 2>/dev/null || true
    find storage/cache -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    find storage/sessions -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    
    # Docker cleanup
    docker system prune -f >/dev/null 2>&1 || true
    
    echo -e "\n${GREEN}🎯 Production environment reset completed!${NC}"
    log "SUCCESS" "Production reset completed"
}

# Backup production environment
backup_production() {
    log "INFO" "Starting production backup..."
    
    # Setup backup directory
    local backup_timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="$BACKUP_DIR/backup_$backup_timestamp"
    mkdir -p "$backup_path"
    
    log "INFO" "Creating backup at: $backup_path"
    
    # Backup database
    log "INFO" "Backing up database..."
    if docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" exec -T mysql mysqldump \
        -u root -p"${MYSQL_ROOT_PASSWORD}" \
        --single-transaction --routines --triggers \
        "${DB_DATABASE:-easyappointments}" > "$backup_path/database.sql"; then
        log "SUCCESS" "Database backup completed"
    else
        log "ERROR" "Database backup failed"
    fi
    
    # Backup storage
    log "INFO" "Backing up storage files..."
    if [ -d "storage" ]; then
        tar -czf "$backup_path/storage.tar.gz" storage/ 2>/dev/null || true
        log "SUCCESS" "Storage backup completed"
    fi
    
    # Backup configuration
    cp "$ENV_FILE" "$backup_path/env.production" 2>/dev/null || true
    cp "$COMPOSE_FILE" "$backup_path/" 2>/dev/null || true
    
    echo -e "\n${GREEN}📦 Backup completed successfully!${NC}"
    echo -e "  Location: $backup_path"
    log "SUCCESS" "Backup completed: $backup_path"
}

# Monitor production environment
monitor_production() {
    log "INFO" "Monitoring production environment..."
    
    local exit_code=0
    
    echo -e "${BLUE}🔍 Production Environment Health Check${NC}"
    echo "============================================="
    
    # Check container status
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
    
    # Check application health
    echo -e "\n${CYAN}Application Health${NC}"
    local http_port="${HTTP_PORT:-80}"
    
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "http://localhost:$http_port/index.php" | grep -q "200\|302"; then
        echo -e "${GREEN}✅ Application is responding${NC}"
    else
        echo -e "${RED}❌ Application is not responding${NC}"
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

# Show usage
show_usage() {
    print_header
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTION]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo -e "  ${GREEN}--start${NC}     Start production environment"
    echo -e "  ${YELLOW}--stop${NC}      Stop production environment gracefully"
    echo -e "  ${RED}--reset${NC}     Reset production environment (DESTRUCTIVE!)"
    echo -e "  ${BLUE}--backup${NC}    Create backup of production data"
    echo -e "  ${PURPLE}--monitor${NC}   Monitor production environment health"
    echo -e "  ${CYAN}--help${NC}      Show this help message"
    echo ""
    echo -e "${WHITE}VERSION:${NC} $SCRIPT_VERSION"
}

# Main script logic
main() {
    # Check arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    case "$1" in
        --start)
            print_header
            validate_environment
            setup_environment
            start_production
            ;;
        --stop)
            print_header
            validate_environment
            setup_environment
            stop_production
            ;;
        --reset)
            print_header
            validate_environment
            setup_environment
            reset_production
            ;;
        --backup)
            print_header
            validate_environment
            setup_environment
            backup_production
            ;;
        --monitor)
            print_header
            validate_environment
            setup_environment
            monitor_production
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

# Run main function
main "$@"
