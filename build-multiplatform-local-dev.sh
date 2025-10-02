#!/bin/bash
# 🚀 Build Multi-Platform Local (Desenvolvimento)
# Execute na sua máquina AMD64 para gerar imagens ARM64 e AMD64

set -euo pipefail

# Configurações
REGISTRY="ghcr.io"
NAMESPACE="alexzerabr"
IMAGE_NAME="easyappointments"
DOCKERFILE="docker/php-fpm/Dockerfile"
TARGET="production"

echo "🚀 Build Multi-Platform Local (Desenvolvimento)"
echo "=============================================="
echo "Platforms: linux/amd64,linux/arm64"
echo "Registry: $REGISTRY"
echo "Images:"
echo "  - $REGISTRY/$NAMESPACE/$IMAGE_NAME:latest (amd64)"
echo "  - $REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest (arm64)"
echo "Tempo estimado: 45-60 minutos"
echo ""

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

# Limpa e cria novo log com data/hora
LOG_FILE="/tmp/build-production.log"
echo "📝 Log: $LOG_FILE"
echo "🕐 Iniciado em: $(date '+%Y-%m-%d %H:%M:%S')" > "$LOG_FILE"
echo "=============================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

time docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --file "$DOCKERFILE" \
    --target "$TARGET" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:latest" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:latest-arm64" \
    --progress=plain \
    --push \
    . 2>&1 | tee -a "$LOG_FILE"

echo ""
echo "🕐 Finalizado em: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "✅ Build multi-platform concluído!" | tee -a "$LOG_FILE"
echo "📝 Log completo salvo em: $LOG_FILE"
echo ""
echo "🏷️  Tags criadas:"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:latest (multi-arch)"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest (arm64)"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:latest-arm64 (arm64)"
echo ""
echo "🧪 Teste AMD64 (local):"
echo "   ./deploy/deploy-production.sh --start"
echo ""
echo "🧪 Teste ARM64 (servidor):"
echo "   docker pull $REGISTRY/$NAMESPACE/$IMAGE_NAME:arm64-latest"
echo "   IMAGE_TAG=arm64-latest ./deploy/deploy-production.sh --start"
