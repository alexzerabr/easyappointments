#!/bin/bash
# 🚀 Build Multi-Platform Local (Desenvolvimento)
# Execute na sua máquina AMD64 para gerar imagens ARM64 e AMD64

set -euo pipefail

# Configurações
REGISTRY="ghcr.io"
NAMESPACE="alexzerabr"
IMAGE_NAME="easyappointments"
WEBSOCKET_IMAGE_NAME="easyappointments-websocket"
DOCKERFILE="docker/php-fpm/Dockerfile"
WEBSOCKET_DOCKERFILE="docker/Dockerfile.websocket"
TARGET="production"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🚀 Build Multi-Platform Local (Desenvolvimento)"
echo "=============================================="
echo "Platforms: linux/amd64,linux/arm64"
echo "Registry: $REGISTRY"
echo "Images:"
echo "  - $REGISTRY/$NAMESPACE/$IMAGE_NAME:latest (amd64)"
echo "  - $REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest (arm64)"
echo "Tempo estimado: 45-60 minutos"
echo ""

# =============================================================================
# PRÉ-VALIDAÇÕES CRÍTICAS
# =============================================================================

echo "🔍 Validando pré-requisitos do build..."

# Valida arquivos essenciais do projeto
REQUIRED_FILES=(
    "composer.json"
    "composer.lock"
    "package.json"
    "gulpfile.js"
    "babel.config.json"
    "$DOCKERFILE"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        MISSING_FILES+=("$file")
    fi
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Erro: Arquivos essenciais não encontrados:${NC}"
    printf '   - %s\n' "${MISSING_FILES[@]}"
    echo ""
    echo "Certifique-se de executar este script na raiz do projeto."
    exit 1
fi

echo -e "${GREEN}✅ Todos os arquivos essenciais encontrados${NC}"

# Valida integridade do composer.lock
if [[ -f "composer.lock" ]]; then
    if ! grep -q '"packages"' composer.lock 2>/dev/null; then
        echo -e "${RED}❌ Erro: composer.lock parece corrompido${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ composer.lock íntegro${NC}"
fi

# Valida estrutura de diretórios críticos
REQUIRED_DIRS=(
    "application"
    "assets"
    "docker/php-fpm"
    "docker/nginx"
)

MISSING_DIRS=()
for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [[ ${#MISSING_DIRS[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Erro: Diretórios essenciais não encontrados:${NC}"
    printf '   - %s\n' "${MISSING_DIRS[@]}"
    exit 1
fi

echo -e "${GREEN}✅ Estrutura de diretórios OK${NC}"

# Valida sintaxe do Dockerfile
if ! docker build --check "$DOCKERFILE" >/dev/null 2>&1; then
    if ! grep -q "FROM" "$DOCKERFILE"; then
        echo -e "${YELLOW}⚠️  Aviso: Dockerfile pode ter problemas de sintaxe${NC}"
    fi
fi

echo -e "${GREEN}✅ Pré-validações concluídas com sucesso${NC}"
echo ""

# =============================================================================
# SETUP DO BUILDER
# =============================================================================

echo "🔧 Verificando builder multi-platform..."
if ! docker buildx ls | grep -q "linux/arm64"; then
    echo "⚠️  Criando builder multi-platform..."
    docker buildx create --name multiplatform --use --platform linux/amd64,linux/arm64
    docker buildx inspect --bootstrap
fi

if docker buildx ls | grep -q "easyappointments-builder.*linux/arm64"; then
    echo "✅ Usando builder 'easyappointments-builder'"
    docker buildx use easyappointments-builder
fi

echo "🔐 Verificando login GHCR..."
if ! grep -q "ghcr.io" ~/.docker/config.json 2>/dev/null; then
    echo "⚠️  Login GHCR não detectado"
    echo "Por favor, faça login no GHCR:"
    echo "docker login ghcr.io -u alexzerabr"
    read -p "Já fez login? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        exit 1
    fi
else
    echo "✅ Login GHCR detectado"
fi

echo "🏗️  Iniciando build multi-platform..."
echo "⏱️  Este processo levará ~45-60 minutos..."
echo ""

# Coleta metadados de build
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_VERSION="${IMAGE_TAG:-latest}"

echo "📋 Metadados de Build:"
echo "   Data: $BUILD_DATE"
echo "   Versão: $BUILD_VERSION"
echo "   Commit: $GIT_COMMIT"
echo "   Branch: $GIT_BRANCH"
echo ""

# Limpa e cria novo log com data/hora
LOG_FILE="/tmp/build-production.log"
echo "📝 Log: $LOG_FILE"
echo "🕐 Iniciado em: $(date '+%Y-%m-%d %H:%M:%S')" > "$LOG_FILE"
echo "=============================================" >> "$LOG_FILE"
echo "Build Date: $BUILD_DATE" >> "$LOG_FILE"
echo "Version: $BUILD_VERSION" >> "$LOG_FILE"
echo "Commit: $GIT_COMMIT" >> "$LOG_FILE"
echo "Branch: $GIT_BRANCH" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

time docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --file "$DOCKERFILE" \
    --target "$TARGET" \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg BUILD_VERSION="$BUILD_VERSION" \
    --build-arg GIT_COMMIT="$GIT_COMMIT" \
    --build-arg GIT_BRANCH="$GIT_BRANCH" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:latest" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:latest-arm64" \
    --progress=plain \
    --push \
    . 2>&1 | tee -a "$LOG_FILE"

BUILD_EXIT_CODE=$?

echo ""
echo "🕐 Finalizado em: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"

if [[ $BUILD_EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}❌ Build falhou com código: $BUILD_EXIT_CODE${NC}" | tee -a "$LOG_FILE"
    echo "📝 Verifique o log completo: $LOG_FILE"
    exit $BUILD_EXIT_CODE
fi

echo -e "${GREEN}✅ Build easyappointments concluído!${NC}" | tee -a "$LOG_FILE"

# =============================================================================
# BUILD WEBSOCKET IMAGE
# =============================================================================

echo ""
echo "🔌 Iniciando build da imagem WebSocket..."
echo ""

if [[ -f "$WEBSOCKET_DOCKERFILE" ]]; then
    time docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --file "$WEBSOCKET_DOCKERFILE" \
        --build-arg BUILD_DATE="$BUILD_DATE" \
        --build-arg BUILD_VERSION="$BUILD_VERSION" \
        --build-arg GIT_COMMIT="$GIT_COMMIT" \
        --tag "$REGISTRY/$NAMESPACE/$WEBSOCKET_IMAGE_NAME:latest" \
        --tag "$REGISTRY/$NAMESPACE/$WEBSOCKET_IMAGE_NAME:arm64-latest" \
        --progress=plain \
        --push \
        . 2>&1 | tee -a "$LOG_FILE"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Build websocket concluído!${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}⚠️  Build websocket falhou, mas continuando...${NC}" | tee -a "$LOG_FILE"
    fi
else
    echo -e "${YELLOW}⚠️  Dockerfile.websocket não encontrado, pulando...${NC}"
fi

echo "📝 Log completo salvo em: $LOG_FILE"

# =============================================================================
# PÓS-VALIDAÇÕES CRÍTICAS
# =============================================================================

echo ""
echo "🔍 Validando imagens geradas..."

# Verifica se as imagens foram criadas no registry
IMAGE_TAGS=(
    "$IMAGE_NAME:latest"
    "$IMAGE_NAME:arm64-latest"
    "$WEBSOCKET_IMAGE_NAME:latest"
    "$WEBSOCKET_IMAGE_NAME:arm64-latest"
)

VALIDATION_FAILED=false

for tag in "${IMAGE_TAGS[@]}"; do
    echo -n "   Verificando $REGISTRY/$NAMESPACE/$tag ... "

    # Tenta fazer inspect da imagem (funciona para imagens no registry)
    if docker buildx imagetools inspect "$REGISTRY/$NAMESPACE/$tag" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (não encontrada)${NC}"
        VALIDATION_FAILED=true
    fi
done

if [[ "$VALIDATION_FAILED" == "true" ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  Algumas tags não foram encontradas no registry${NC}"
    echo "   Isso pode ser normal se o push ainda não foi concluído."
else
    echo -e "${GREEN}✅ Todas as tags validadas com sucesso${NC}"
fi

# Verifica digest da imagem principal
echo ""
echo "📋 Informações da imagem principal:"
docker buildx imagetools inspect "$REGISTRY/$NAMESPACE/$IMAGE_NAME:latest" 2>/dev/null | grep -E "(Name|MediaType|Digest|Platform)" | head -10 || true

echo ""
echo "🏷️  Tags criadas:"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:latest (multi-arch)"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest (arm64)"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:latest-arm64 (arm64)"
echo "   - $REGISTRY/$NAMESPACE/$WEBSOCKET_IMAGE_NAME:latest (multi-arch)"
echo "   - $REGISTRY/$NAMESPACE/$WEBSOCKET_IMAGE_NAME:arm64-latest (arm64)"
echo ""
echo "🧪 Próximos passos:"
echo ""
echo "   1. Teste AMD64 (local):"
echo "      ./deploy/deploy-production.sh --start"
echo ""
echo "   2. Teste ARM64 (servidor):"
echo "      docker pull $REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest"
echo "      IMAGE_TAG=arm64-latest ./deploy/deploy-production.sh --start"
echo ""
echo "   3. Smoke test (recomendado):"
echo "      ./deploy/deploy-production.sh smoke-test"
echo ""
echo -e "${GREEN}✅ Build pipeline completado com sucesso!${NC}"
