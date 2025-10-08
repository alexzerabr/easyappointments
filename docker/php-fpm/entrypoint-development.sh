#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🚀 Easy!Appointments Development Environment${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Function to wait for a service to be ready
wait_for_dependency() {
    local host="$1"
    local port="$2"
    local service_name="$3"
    local max_attempts=60
    local attempt=0
    
    echo -e "${BLUE}⏳ Waiting for ${service_name} (${host}:${port})...${NC}"
    
    while [ $attempt -lt $max_attempts ]; do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo -e "${GREEN}✅ ${service_name} is ready!${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    echo -e "${RED}❌ Timeout waiting for ${service_name}${NC}"
    return 1
}

# Function to check if directory has content
has_content() {
    local dir="$1"
    [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null)" ]
}

# Display environment information
echo -e "${PURPLE}📊 Environment Information:${NC}"
echo -e "  PHP Version:      $(php -v | head -n 1 | cut -d' ' -f2)"
echo -e "  Composer Version: $(composer --version --no-ansi 2>/dev/null | cut -d' ' -f3 || echo 'N/A')"
echo -e "  Node Version:     $(node --version 2>/dev/null || echo 'N/A')"
echo -e "  NPM Version:      $(npm --version 2>/dev/null || echo 'N/A')"
echo -e "  Working Dir:      $(pwd)"
echo ""

# Wait for MySQL to be ready
# Use DB_HOST from environment, fallback to 'mysql' for compatibility
MYSQL_HOST="${DB_HOST:-mysql}"
wait_for_dependency "$MYSQL_HOST" "3306" "MySQL"

# Create necessary directories with proper permissions
echo -e "${BLUE}📁 Ensuring directory structure...${NC}"
mkdir -p storage/logs storage/cache storage/sessions storage/uploads storage/backups
chmod -R 755 storage
echo -e "${GREEN}✅ Directories ready${NC}"

# Handle config.php
if [ ! -f "config.php" ]; then
    if [ -f "config-sample.php" ]; then
        echo -e "${YELLOW}⚙️  Creating config.php from config-sample.php...${NC}"
        cp config-sample.php config.php
        
        # Set development defaults
        sed -i "s|const DEBUG_MODE = false;|const DEBUG_MODE = true;|g" config.php 2>/dev/null || true
        sed -i "s|const DB_HOST = 'localhost';|const DB_HOST = 'mysql';|g" config.php 2>/dev/null || true
        sed -i "s|const DB_NAME = 'easyappointments';|const DB_NAME = 'easyappointments';|g" config.php 2>/dev/null || true
        sed -i "s|const DB_USERNAME = 'root';|const DB_USERNAME = 'user';|g" config.php 2>/dev/null || true
        sed -i "s|const DB_PASSWORD = '';|const DB_PASSWORD = 'password';|g" config.php 2>/dev/null || true
        
        echo -e "${GREEN}✅ config.php created with development defaults${NC}"
    else
        echo -e "${YELLOW}⚠️  config-sample.php not found, skipping config.php creation${NC}"
    fi
else
    echo -e "${GREEN}✅ config.php already exists${NC}"
fi

# Install/Update Composer dependencies
echo -e "${BLUE}📦 Managing Composer dependencies...${NC}"
if [ ! -d "vendor" ] || [ ! -f "vendor/autoload.php" ]; then
    echo -e "${YELLOW}  Installing Composer dependencies (first time)...${NC}"
    composer install --optimize-autoloader --no-dev --no-interaction --prefer-dist
    echo -e "${GREEN}✅ Composer dependencies installed${NC}"
else
    # Check if composer.lock has changed
    COMPOSER_NEEDS_UPDATE=false
    
    if [ -f "composer.lock" ]; then
        # Simple check: if composer.lock is newer than vendor directory
        if [ "composer.lock" -nt "vendor" ]; then
            COMPOSER_NEEDS_UPDATE=true
        fi
    fi
    
    if [ "$COMPOSER_NEEDS_UPDATE" = "true" ]; then
        echo -e "${YELLOW}  Updating Composer dependencies...${NC}"
        composer install --optimize-autoloader --no-dev --no-interaction --prefer-dist
        echo -e "${GREEN}✅ Composer dependencies updated${NC}"
    else
        echo -e "${GREEN}✅ Composer dependencies up to date${NC}"
    fi
fi

# Install/Update NPM dependencies (optional, only if package.json exists and we want to build assets)
if [ -f "package.json" ] && [ "${SKIP_NPM:-false}" != "true" ]; then
    echo -e "${BLUE}📦 Managing NPM dependencies...${NC}"
    
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}  Installing NPM dependencies...${NC}"
        npm install --silent
        echo -e "${GREEN}✅ NPM dependencies installed${NC}"
    else
        # Check if package-lock.json has changed
        NPM_NEEDS_UPDATE=false
        
        if [ -f "package-lock.json" ] && [ "package-lock.json" -nt "node_modules" ]; then
            NPM_NEEDS_UPDATE=true
        fi
        
        if [ "$NPM_NEEDS_UPDATE" = "true" ]; then
            echo -e "${YELLOW}  Updating NPM dependencies...${NC}"
            npm install --silent
            echo -e "${GREEN}✅ NPM dependencies updated${NC}"
        else
            echo -e "${GREEN}✅ NPM dependencies up to date${NC}"
        fi
    fi
else
    echo -e "${CYAN}ℹ️  NPM dependency management skipped${NC}"
fi

# Build assets if needed (independently of NPM management above)
if [ -f "package.json" ]; then
    # Check if assets need to be built
    SHOULD_BUILD_ASSETS=false
    
    # Check if assets exist
    if [ ! -f "assets/css/general.min.css" ] || [ ! -f "assets/js/app.min.js" ]; then
        echo -e "${YELLOW}🎨 Assets não encontrados, compilando automaticamente...${NC}"
        SHOULD_BUILD_ASSETS=true
    fi
    
    # Or if explicitly requested
    if [ "${BUILD_ASSETS:-false}" = "true" ]; then
        SHOULD_BUILD_ASSETS=true
    fi
    
    if [ "$SHOULD_BUILD_ASSETS" = "true" ]; then
        # Ensure node_modules exists
        if [ ! -d "node_modules" ]; then
            echo -e "${YELLOW}  Installing NPM dependencies for asset build...${NC}"
            npm install --silent
        fi
        
        echo -e "${BLUE}🎨 Compilando frontend assets...${NC}"
        npx gulp compile 2>&1 | grep -E "Starting|Finished|error" || true
        
        if [ -f "assets/css/general.min.css" ] && [ -f "assets/js/app.min.js" ]; then
            echo -e "${GREEN}✅ Assets compilados com sucesso${NC}"
        else
            echo -e "${YELLOW}⚠️  Compilação de assets pode ter falhado${NC}"
        fi
    else
        echo -e "${GREEN}✅ Assets já existem${NC}"
    fi
fi

# Set proper permissions for storage
echo -e "${BLUE}🔐 Setting storage permissions...${NC}"
find storage -type d -exec chmod 755 {} \; 2>/dev/null || true
find storage -type f -exec chmod 644 {} \; 2>/dev/null || true
chmod -R g+w storage 2>/dev/null || true
echo -e "${GREEN}✅ Storage permissions set${NC}"

# Display startup information
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Development environment initialized successfully!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}📋 Quick Info:${NC}"
echo -e "  • Composer dependencies: ${GREEN}✓ Installed${NC}"
echo -e "  • Storage directories:   ${GREEN}✓ Ready${NC}"
echo -e "  • Configuration:         ${GREEN}✓ Loaded${NC}"
echo ""
echo -e "${YELLOW}🔧 Development Mode Active:${NC}"
echo -e "  • DEBUG_MODE enabled"
echo -e "  • XDebug available"
echo -e "  • Hot reload: Changes reflect immediately"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Execute the original command (usually start-container script)
exec "$@"

