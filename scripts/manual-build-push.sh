#!/bin/bash

# Manual Build and Push Script for GHCR
# Use this script to build and push images manually outside of GitHub Actions

set -euo pipefail

# Configuration (adjust these values)
GH_OWNER="${GH_OWNER:-CHANGE_ME}"
REPO_NAME="easyappointments"
REGISTRY="ghcr.io"
VERSION_TAG="${VERSION_TAG:-v1.0.0.0}"
LATEST_TAG="latest"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "ERROR")   echo -e "${RED}❌ ERROR: $message${NC}" ;;
        "WARN")    echo -e "${YELLOW}⚠️  WARNING: $message${NC}" ;;
        "INFO")    echo -e "${BLUE}ℹ️  INFO: $message${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ SUCCESS: $message${NC}" ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Print header
print_header() {
    echo -e "${BLUE}"
    echo "============================================="
    echo "🐳 Manual Docker Build & Push to GHCR"
    echo "============================================="
    echo -e "${NC}"
}

# Validate environment
validate_environment() {
    log "INFO" "Validating environment..."
    
    # Check required variables
    if [ "$GH_OWNER" = "CHANGE_ME" ]; then
        error_exit "Please set GH_OWNER environment variable or edit this script"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed or not in PATH"
    fi
    
    # Check Docker Buildx
    if ! docker buildx version &> /dev/null; then
        error_exit "Docker Buildx is required"
    fi
    
    # Check if logged in to GHCR
    if ! docker system info | grep -q "ghcr.io"; then
        log "WARN" "Not logged in to GHCR. Attempting login..."
        login_ghcr
    fi
    
    log "SUCCESS" "Environment validation passed"
}

# Login to GHCR
login_ghcr() {
    log "INFO" "Logging in to GitHub Container Registry..."
    
    if [ -n "${GHCR_TOKEN:-}" ]; then
        echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GH_OWNER" --password-stdin
    elif [ -n "${GITHUB_TOKEN:-}" ]; then
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GH_OWNER" --password-stdin
    else
        log "WARN" "No GHCR_TOKEN or GITHUB_TOKEN found."
        echo -n "Please enter your GitHub token: "
        read -s token
        echo
        echo "$token" | docker login ghcr.io -u "$GH_OWNER" --password-stdin
    fi
    
    log "SUCCESS" "Successfully logged in to GHCR"
}

# Build and push image
build_and_push() {
    local context="$1"
    local dockerfile="$2"
    local image_name="$3"
    local target="$4"
    
    local full_image_name="${REGISTRY}/${GH_OWNER}/${image_name}"
    
    log "INFO" "Building and pushing: $full_image_name"
    log "INFO" "Context: $context"
    log "INFO" "Dockerfile: $dockerfile"
    log "INFO" "Target: $target"
    
    # Build and push with multiple tags
    docker buildx build \
        --context "$context" \
        --file "$dockerfile" \
        --target "$target" \
        --platform linux/amd64,linux/arm64 \
        --tag "${full_image_name}:${VERSION_TAG}" \
        --tag "${full_image_name}:${LATEST_TAG}" \
        --push \
        --cache-from type=gha \
        --cache-to type=gha,mode=max \
        .
    
    log "SUCCESS" "Successfully built and pushed: $full_image_name"
    echo -e "\n${BLUE}📦 Available tags:${NC}"
    echo "  - ${full_image_name}:${VERSION_TAG}"
    echo "  - ${full_image_name}:${LATEST_TAG}"
}

# Main execution
main() {
    print_header
    
    echo "Configuration:"
    echo "  GH_OWNER: $GH_OWNER"
    echo "  REPO_NAME: $REPO_NAME"
    echo "  VERSION_TAG: $VERSION_TAG"
    echo "  REGISTRY: $REGISTRY"
    echo ""
    
    # Confirm before proceeding
    read -p "Proceed with build and push? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Operation cancelled by user"
        exit 0
    fi
    
    validate_environment
    
    # Build and push EasyAppointments image
    log "INFO" "Starting build process..."
    build_and_push "." "docker/php-fpm/Dockerfile" "easyappointments" "production"
    
    echo -e "\n${GREEN}🎉 Build and push completed successfully!${NC}"
    echo -e "\n${BLUE}📋 Next steps:${NC}"
    echo "1. Update your production environment:"
    echo "   docker pull ${REGISTRY}/${GH_OWNER}/easyappointments:latest"
    echo ""
    echo "2. Deploy using the updated script:"
    echo "   ./deploy/deploy-production.sh --start"
    echo ""
    echo "3. Verify the deployment:"
    echo "   curl -I http://localhost/index.php/installation"
}

# Help function
show_help() {
    echo "Manual Build and Push Script for GHCR"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Environment Variables:"
    echo "  GH_OWNER         GitHub username or organization (required)"
    echo "  VERSION_TAG      Version tag for the image (default: v1.0.0.0)"
    echo "  GHCR_TOKEN       GitHub token with packages:write permission"
    echo "  GITHUB_TOKEN     Alternative to GHCR_TOKEN"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Set environment variables and run"
    echo "  export GH_OWNER=myusername"
    echo "  export GHCR_TOKEN=ghp_xxxxxxxxxxxx"
    echo "  $0"
    echo ""
    echo "  # Override version tag"
    echo "  VERSION_TAG=v2.0.0 $0"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
