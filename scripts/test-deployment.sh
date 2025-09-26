#!/bin/bash

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")   echo -e "${RED}❌ ERROR: $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}⚠️  WARNING: $message${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ️  INFO: $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ SUCCESS: $message${NC}" ;;
    esac
}

print_header() {
    echo -e "${BLUE}"
    echo "============================================="
    echo "🧪 Easy!Appointments Deployment Test"
    echo "============================================="
    echo -e "${NC}"
}

test_arm64_compatibility() {
    log "INFO" "Testing ARM64 compatibility..."
    
    local image_tag="${1:-latest}"
    local amd64_image="ghcr.io/alexzerabr/easyappointments:${image_tag}"
    local arm64_image="ghcr.io/alexzerabr/easyappointments:arm64-latest"
    
    echo -e "\n${BLUE}📦 Testing Image Availability:${NC}"
    
    # Test AMD64 image
    if docker manifest inspect "$amd64_image" >/dev/null 2>&1; then
        log "SUCCESS" "AMD64 image available: $amd64_image"
    else
        log "ERROR" "AMD64 image not found: $amd64_image"
        return 1
    fi
    
    # Test ARM64 image
    if docker manifest inspect "$arm64_image" >/dev/null 2>&1; then
        log "SUCCESS" "ARM64 image available: $arm64_image"
    else
        log "WARN" "ARM64 image not found: $arm64_image"
        log "INFO" "Use './build-arm64-local-dev.sh' to build ARM64 image"
    fi
    
    # Test multi-arch manifest
    echo -e "\n${BLUE}🏗️  Testing Multi-Architecture Support:${NC}"
    if docker manifest inspect "$amd64_image" | grep -q "architecture"; then
        docker manifest inspect "$amd64_image" | grep -A3 -B1 "architecture"
        log "SUCCESS" "Multi-architecture manifest detected"
    else
        log "WARN" "Single architecture image detected"
    fi
}

test_assets_build() {
    log "INFO" "Testing assets build process..."
    
    echo -e "\n${BLUE}🎨 Checking Built Assets:${NC}"
    
    # Check if assets are built
    local missing_assets=0
    
    if [ ! -d "assets/vendor" ]; then
        log "ERROR" "Vendor assets not found - run 'npm run build' first"
        missing_assets=1
    else
        log "SUCCESS" "Vendor assets directory found"
        echo "  - Vendor files: $(find assets/vendor -type f | wc -l)"
    fi
    
    if [ ! -f "assets/css/layouts/backend_layout.min.css" ]; then
        log "ERROR" "Minified CSS not found - run 'npm run build' first"
        missing_assets=1
    else
        log "SUCCESS" "Minified CSS files found"
        echo "  - CSS files: $(find assets/css -name "*.min.css" | wc -l)"
    fi
    
    local js_count=$(find assets/js -name "*.min.js" | wc -l)
    if [ "$js_count" -eq 0 ]; then
        log "ERROR" "Minified JS not found - run 'npm run build' first"
        missing_assets=1
    else
        log "SUCCESS" "Minified JS files found"
        echo "  - JS files: $js_count"
    fi
    
    if [ $missing_assets -eq 1 ]; then
        echo -e "\n${YELLOW}🔧 To build assets, run:${NC}"
        echo "  npm install"
        echo "  npm run build"
        return 1
    fi
    
    log "SUCCESS" "All assets are properly built"
}

test_docker_configs() {
    log "INFO" "Testing Docker configurations..."
    
    echo -e "\n${BLUE}🐳 Docker Compose Validation:${NC}"
    
    # Test production compose
    if docker compose -f docker-compose.prod.yml config >/dev/null 2>&1; then
        log "SUCCESS" "Production compose file is valid"
    else
        log "ERROR" "Production compose file has errors"
        return 1
    fi
    
    # Test development compose
    if docker compose -f docker-compose.yml config >/dev/null 2>&1; then
        log "SUCCESS" "Development compose file is valid"
    else
        log "ERROR" "Development compose file has errors"
        return 1
    fi
    
    # Check volume configuration
    echo -e "\n${BLUE}📁 Volume Configuration:${NC}"
    if grep -q "app_assets:" docker-compose.prod.yml; then
        log "SUCCESS" "Shared assets volume configured"
    else
        log "ERROR" "Shared assets volume missing in production compose"
        return 1
    fi
}

test_deployment_scripts() {
    log "INFO" "Testing deployment scripts..."
    
    echo -e "\n${BLUE}📜 Script Validation:${NC}"
    
    # Test deploy script exists and is executable
    if [ -x "deploy/deploy-production.sh" ]; then
        log "SUCCESS" "Production deployment script is executable"
    else
        log "ERROR" "Production deployment script not found or not executable"
        return 1
    fi
    
    # Test script syntax
    if bash -n deploy/deploy-production.sh; then
        log "SUCCESS" "Production deployment script syntax is valid"
    else
        log "ERROR" "Production deployment script has syntax errors"
        return 1
    fi
    
    # Test ARM64 build script
    if [ -x "build-arm64-local-dev.sh" ]; then
        log "SUCCESS" "ARM64 build script is executable"
    else
        log "ERROR" "ARM64 build script not found or not executable"
        return 1
    fi
}

test_environment_files() {
    log "INFO" "Testing environment configuration..."
    
    echo -e "\n${BLUE}⚙️  Environment Files:${NC}"
    
    if [ -f "env.production-example" ]; then
        log "SUCCESS" "Production environment example found"
        
        # Check for required variables
        local required_vars=("WA_TOKEN_ENC_KEY" "DB_PASSWORD" "MYSQL_ROOT_PASSWORD")
        for var in "${required_vars[@]}"; do
            if grep -q "^${var}=" env.production-example; then
                log "SUCCESS" "Required variable $var found in example"
            else
                log "ERROR" "Required variable $var missing in example"
            fi
        done
    else
        log "ERROR" "Production environment example not found"
        return 1
    fi
    
    if [ -f "config-sample.php" ]; then
        log "SUCCESS" "Configuration sample file found"
    else
        log "ERROR" "Configuration sample file not found"
        return 1
    fi
}

run_quick_deployment_test() {
    log "INFO" "Running quick deployment test..."
    
    echo -e "\n${BLUE}🚀 Quick Deployment Test:${NC}"
    echo "This will test the deployment process without actually starting services"
    
    # Create test environment
    if [ ! -f ".env.test" ]; then
        cat > .env.test << EOF
WA_TOKEN_ENC_KEY=test_key_32_characters_long_test
DB_PASSWORD=test_password_123
MYSQL_ROOT_PASSWORD=test_root_password_123
DB_DATABASE=easyappointments_test
DB_USERNAME=test_user
HTTP_PORT=8080
MYSQL_PORT=3307
APP_URL=http://localhost:8080
EOF
        log "INFO" "Created test environment file"
    fi
    
    # Validate compose with test environment
    if docker compose -f docker-compose.prod.yml --env-file .env.test config >/dev/null 2>&1; then
        log "SUCCESS" "Compose validation with test environment passed"
    else
        log "ERROR" "Compose validation with test environment failed"
        return 1
    fi
    
    # Clean up test file
    rm -f .env.test
    log "INFO" "Cleaned up test environment file"
}

main() {
    local exit_code=0
    
    print_header
    
    echo "🧪 Running comprehensive deployment tests..."
    echo ""
    
    # Run all tests
    test_arm64_compatibility "${1:-latest}" || exit_code=1
    test_assets_build || exit_code=1
    test_docker_configs || exit_code=1
    test_deployment_scripts || exit_code=1
    test_environment_files || exit_code=1
    run_quick_deployment_test || exit_code=1
    
    echo ""
    echo "============================================="
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! Deployment is ready.${NC}"
        echo ""
        echo -e "${BLUE}🚀 Next steps:${NC}"
        echo "1. For ARM64: ./build-arm64-local-dev.sh"
        echo "2. For deployment: ./deploy/deploy-production.sh --start"
        echo "3. For monitoring: ./deploy/deploy-production.sh --monitor"
    else
        echo -e "${RED}❌ Some tests failed! Please fix the issues above.${NC}"
    fi
    echo "============================================="
    
    return $exit_code
}

# Show usage if help requested
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [IMAGE_TAG]"
    echo ""
    echo "Tests the deployment configuration for Easy!Appointments"
    echo ""
    echo "Options:"
    echo "  IMAGE_TAG   Image tag to test (default: latest)"
    echo "  --help, -h  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Test with latest image"
    echo "  $0 arm64-latest      # Test with ARM64 image"
    echo "  $0 v1.0.0.0         # Test with specific version"
    exit 0
fi

main "$@"
