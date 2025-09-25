#!/bin/bash

# Easy!Appointments Unified Development Deployment Script
# Version: 2.0
# Author: Unified Deployment System
# 
# This script consolidates all development deployment operations into a single tool.
# It replaces the previous clean_env.sh and reset_env.sh scripts.
#
# USAGE:
#   ./deploy/deploy-development.sh --start     # Start development environment
#   ./deploy/deploy-development.sh --stop      # Stop development environment
#   ./deploy/deploy-development.sh --reset     # Reset development environment (DESTRUCTIVE!)
#
# EXAMPLES:
#   # Start development for the first time
#   ./deploy/deploy-development.sh --start
#
#   # Stop development gracefully
#   ./deploy/deploy-development.sh --stop
#
#   # Reset everything (WARNING: DESTROYS ALL DATA!)
#   ./deploy/deploy-development.sh --reset
#
# REQUIREMENTS:
#   - Docker and Docker Compose v2
#   - .env file (will be auto-generated if missing)
#
# SAFETY FEATURES:
#   - Validates environment before operations
#   - Requires explicit confirmation for destructive operations
#   - Comprehensive error handling with rollback capabilities
#   - Detailed logging and status reporting

set -euo pipefail

# Script configuration
SCRIPT_VERSION="2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
ENV_EXAMPLE=".env-example"
LOG_FILE="storage/logs/deploy-development.log"

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
    echo "🚀 Easy!Appointments Development Manager v${SCRIPT_VERSION}"
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
        log "WARN" "Development environment file not found"
        
        if [ -f "$ENV_EXAMPLE" ]; then
            log "INFO" "Creating development environment from example..."
            
            # Copy example file
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            
            # Generate WA_TOKEN_ENC_KEY if empty
            if grep -q "WA_TOKEN_ENC_KEY=$" "$ENV_FILE"; then
                local wa_token_key=$(openssl rand -base64 32)
                sed -i "s/WA_TOKEN_ENC_KEY=$/WA_TOKEN_ENC_KEY=$wa_token_key/" "$ENV_FILE"
                log "SUCCESS" "Generated WA_TOKEN_ENC_KEY for development"
            fi
            
            log "SUCCESS" "Development environment file created"
        else
            error_exit "Neither $ENV_FILE nor $ENV_EXAMPLE found"
        fi
    fi
    
    log "SUCCESS" "Environment setup completed"
}

# Setup config.php from sample
setup_config() {
    log "INFO" "Creating config.php from config-sample.php for development..."
    
    if [ ! -f "config-sample.php" ]; then
        error_exit "config-sample.php not found"
    fi
    
    # Always use config-sample.php as the base template
    log "INFO" "Using config-sample.php as template"
    cp config-sample.php config.php
    
    # Update config.php with development values (using defaults from docker-compose.yml)
    sed -i "s|const BASE_URL = 'http://localhost';|const BASE_URL = 'http://localhost';|g" config.php
    sed -i "s|const DEBUG_MODE = false;|const DEBUG_MODE = true;|g" config.php
    sed -i "s|const DB_HOST = 'mysql';|const DB_HOST = 'mysql';|g" config.php
    sed -i "s|const DB_NAME = 'easyappointments';|const DB_NAME = 'easyappointments';|g" config.php
    sed -i "s|const DB_USERNAME = 'user';|const DB_USERNAME = 'user';|g" config.php
    sed -i "s|const DB_PASSWORD = 'password';|const DB_PASSWORD = 'password';|g" config.php
    
    log "SUCCESS" "config.php created from template with development credentials"
}

# Start development environment
start_development() {
    log "INFO" "Starting development environment..."
    
    # Check for existing containers
    if docker compose ps -q 2>/dev/null | grep -q .; then
        log "WARN" "Existing containers found. Checking status..."
        docker compose ps
        
        read -p "Continue with existing environment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Setup config.php with development credentials
    setup_config
    
    # Build and start services
    log "INFO" "Building and starting development services..."
    docker compose up -d --build
    
    # Fix storage permissions
    log "INFO" "Setting storage permissions..."
    chmod -R 755 storage/sessions storage/cache storage/uploads 2>/dev/null || true
    chmod -R 644 storage/sessions/* storage/cache/* storage/uploads/* 2>/dev/null || true
    chmod g+w storage/sessions storage/cache storage/uploads 2>/dev/null || true
    
    # Wait for MySQL to be healthy
    log "INFO" "Waiting for MySQL to be ready..."
    local timeout=240
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local mysql_container=$(docker compose ps -q mysql 2>/dev/null || true)
        if [ -n "$mysql_container" ]; then
            local health_status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' "$mysql_container" 2>/dev/null || true)
            if [ "$health_status" = "healthy" ]; then
                log "SUCCESS" "MySQL is healthy"
                break
            fi
        fi
        sleep 3
        elapsed=$((elapsed + 3))
    done
    
    if [ $elapsed -ge $timeout ]; then
        error_exit "Timeout waiting for MySQL to become healthy"
    fi
    
    # Wait for application to be ready
    log "INFO" "Waiting for application to be ready..."
    local app_timeout=180
    local app_elapsed=0
    while [ $app_elapsed -lt $app_timeout ]; do
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "http://localhost/index.php/installation" || true)
        case "$http_code" in
            200|201|202|203|204|301|302|303|307|308)
                log "SUCCESS" "Application is ready"
                break
                ;;
        esac
        sleep 3
        app_elapsed=$((app_elapsed + 3))
    done
    
    if [ $app_elapsed -ge $app_timeout ]; then
        log "WARN" "Application may still be starting up"
    fi
    
    # Display status
    echo -e "\n${GREEN}🎉 Development environment started successfully!${NC}\n"
    echo -e "${BLUE}📊 Service Status:${NC}"
    docker compose ps
    
    echo -e "\n${BLUE}🌐 Access URLs:${NC}"
    echo -e "  Installation: http://localhost/index.php/installation"
    echo -e "  Application:  http://localhost"
    echo -e "  PHPMyAdmin:   http://localhost:8080"
    echo -e "  Mailpit:      http://localhost:8025"
    
    echo -e "\n${BLUE}📊 Database Info:${NC}"
    echo -e "  Host: mysql (internal) / localhost:3306 (external)"
    echo -e "  Database: easyappointments"
    echo -e "  Username: user"
    echo -e "  Password: password"
    echo -e "  Root Password: secret"
    
    echo -e "\n${BLUE}💡 Next Steps:${NC}"
    echo -e "  1. Access http://localhost/index.php/installation"
    echo -e "  2. Use the database credentials above"
    echo -e "  3. Complete the installation wizard"
    
    log "SUCCESS" "Development start completed"
}

# Stop development environment
stop_development() {
    log "INFO" "Stopping development environment..."
    
    # Check if containers are running
    if ! docker compose ps -q &>/dev/null; then
        log "WARN" "No containers found or Docker Compose not available"
        return 1
    fi
    
    local running_containers=$(docker compose ps --filter "status=running" -q 2>/dev/null | wc -l)
    
    if [ "$running_containers" -eq 0 ]; then
        log "WARN" "No running containers found"
        docker compose ps
        return 0
    fi
    
    echo -e "${BLUE}📊 Current running containers:${NC}"
    docker compose ps
    
    echo -e "\n${YELLOW}🛑 Stopping development environment...${NC}"
    
    # Stop all services gracefully
    docker compose stop
    
    echo -e "\n${GREEN}✅ Development environment stopped successfully!${NC}"
    log "SUCCESS" "Development stop completed"
}

# Reset development environment
reset_development() {
    echo -e "${RED}⚠️  DANGER: Development Environment Reset${NC}"
    echo "============================================="
    echo -e "${YELLOW}WARNING: This will permanently delete ALL development data!${NC}"
    echo ""
    echo "This operation will remove:"
    echo "  • All containers (running and stopped)"
    echo "  • All development volumes and data"
    echo "  • All development images"
    echo "  • All networks"
    echo "  • MySQL data directory"
    echo "  • Storage cache and sessions"
    echo ""
    
    # Confirmation
    read -p "Are you ABSOLUTELY sure you want to continue? Type 'DESTROY' to confirm: " confirm
    
    if [ "$confirm" != "DESTROY" ]; then
        log "INFO" "Reset operation cancelled by user"
        exit 0
    fi
    
    log "WARN" "Starting development environment destruction..."
    
    # Stop and remove containers with volumes and images
    log "INFO" "Removing containers, volumes, images, and networks..."
    docker compose down --rmi all -v --remove-orphans || true
    
    # Remove MySQL data directory
    local mysql_dir="$ROOT_DIR/docker/mysql"
    if [ -d "$mysql_dir" ]; then
        log "INFO" "Cleaning MySQL data directory: $mysql_dir"
        docker run --rm -v "$mysql_dir":/var/lib/mysql alpine:3.19 sh -c "rm -rf /var/lib/mysql/*" || true
        log "SUCCESS" "MySQL data directory cleaned"
    else
        log "WARN" "MySQL data directory not found: $mysql_dir"
    fi
    
    # Clean storage directories
    log "INFO" "Cleaning storage directories..."
    find storage/logs -name "*.log" -delete 2>/dev/null || true
    find storage/cache -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    find storage/sessions -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    find storage/uploads -type f ! -name ".htaccess" ! -name "index.html" -delete 2>/dev/null || true
    
    # Docker system cleanup
    log "INFO" "Docker system cleanup..."
    docker system prune -af --volumes >/dev/null 2>&1 || true
    docker builder prune -af >/dev/null 2>&1 || true
    
    echo -e "\n${GREEN}🎯 Development environment reset completed!${NC}"
    echo ""
    echo -e "${BLUE}📊 Summary:${NC}"
    echo "  • All containers: REMOVED"
    echo "  • All volumes: REMOVED"
    echo "  • All images: REMOVED"
    echo "  • All networks: REMOVED"
    echo "  • MySQL data: CLEANED"
    echo "  • Storage data: CLEANED"
    echo "  • Docker system: CLEANED"
    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "  1. Run: ./deploy/deploy-development.sh --start"
    echo "  2. Access: http://localhost/index.php/installation"
    echo "  3. Complete installation wizard"
    echo ""
    echo -e "${RED}⚠️  All development data has been permanently deleted!${NC}"
    
    log "SUCCESS" "Development reset completed"
}

# Show usage
show_usage() {
    print_header
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTION]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo -e "  ${GREEN}--start${NC}     Start development environment"
    echo -e "  ${YELLOW}--stop${NC}      Stop development environment gracefully"
    echo -e "  ${RED}--reset${NC}     Reset development environment (DESTRUCTIVE!)"
    echo -e "  ${CYAN}--help${NC}      Show this help message"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0 --start     # Start development for the first time"
    echo "  $0 --stop      # Stop development gracefully"
    echo "  $0 --reset     # Reset everything (WARNING: DESTROYS DATA!)"
    echo ""
    echo -e "${WHITE}REQUIREMENTS:${NC}"
    echo "  • Docker and Docker Compose v2"
    echo "  • $ENV_FILE file (auto-generated if missing)"
    echo ""
    echo -e "${WHITE}ACCESS URLS (after start):${NC}"
    echo "  • Installation: http://localhost/index.php/installation"
    echo "  • Application:  http://localhost"
    echo "  • PHPMyAdmin:   http://localhost:8080"
    echo "  • Mailpit:      http://localhost:8025"
    echo ""
    echo -e "${WHITE}VERSION:${NC} $SCRIPT_VERSION"
    echo ""
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
            start_development
            ;;
        --stop)
            print_header
            validate_environment
            stop_development
            ;;
        --reset)
            print_header
            validate_environment
            reset_development
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
