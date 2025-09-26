#!/bin/bash
# 🚀 Build ARM64 Local (Desenvolvimento)
# Execute na sua máquina AMD64 para gerar imagem ARM64

set -euo pipefail

# Configurações
REGISTRY="ghcr.io"
NAMESPACE="alexzerabr"
IMAGE_NAME="easyappointments"
TAG="arm64-latest"
DOCKERFILE="docker/php-fpm/Dockerfile"
TARGET="production"

echo "🚀 Build ARM64 Local (Desenvolvimento)"
echo "===================================="
echo "Platform: linux/arm64 (emulado via QEMU)"
echo "Registry: $REGISTRY"
echo "Image: $REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
echo "Tempo estimado: 45-60 minutos"
echo ""

# Verificar builder multi-platform
echo "🔧 Verificando builder multi-platform..."
if ! docker buildx ls | grep -q "linux/arm64"; then
    echo "⚠️  Criando builder multi-platform..."
    docker buildx create --name multiplatform --use --platform linux/amd64,linux/arm64
    docker buildx inspect --bootstrap
fi

# Usar builder existente que suporta ARM64
if docker buildx ls | grep -q "easyappointments-builder.*linux/arm64"; then
    echo "✅ Usando builder 'easyappointments-builder'"
    docker buildx use easyappointments-builder
fi

# Verificar se está logado no GHCR
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

# Build da imagem ARM64
echo "🏗️  Iniciando build ARM64 (emulado)..."
echo "⏱️  Este processo levará ~45-60 minutos..."
echo ""

time docker buildx build \
    --platform linux/arm64 \
    --file "$DOCKERFILE" \
    --target "$TARGET" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG" \
    --tag "$REGISTRY/$NAMESPACE/$IMAGE_NAME:latest-arm64" \
    --progress=plain \
    --push \
    .

echo ""
echo "✅ Build ARM64 concluído!"
echo ""
echo "🏷️  Tags criadas:"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
echo "   - $REGISTRY/$NAMESPACE/$IMAGE_NAME:latest-arm64"
echo ""
echo "🧪 Teste no servidor ARM64:"
echo "   docker pull $REGISTRY/$NAMESPACE/$IMAGE_NAME:$TAG"
echo ""
echo "🚀 Use no deploy:"
echo "   IMAGE_TAG=arm64-latest ./deploy/deploy-production.sh --start"
