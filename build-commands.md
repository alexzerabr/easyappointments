# 🔨 Comandos Manuais de Build e Push

## **Comandos Diretos (Copie e Cole)**

### **1. Configuração Inicial**
```bash
# Definir variáveis (AJUSTE OS VALORES!)
export GH_OWNER="your-github-username"
export GHCR_TOKEN="your-github-token"
export VERSION_TAG="v1.0.0.0"

# Login no GHCR
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin
```

### **2. Build e Push - EasyAppointments**
```bash
# Build com múltiplas arquiteturas e tags
docker buildx build \
  --context . \
  --file docker/php-fpm/Dockerfile \
  --target production \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/$GH_OWNER/easyappointments:$VERSION_TAG \
  --tag ghcr.io/$GH_OWNER/easyappointments:latest \
  --push \
  --cache-from type=gha \
  --cache-to type=gha,mode=max
```

### **3. Build Simples (apenas amd64)**
```bash
# Para desenvolvimento/teste local
docker buildx build \
  --context . \
  --file docker/php-fpm/Dockerfile \
  --target production \
  --platform linux/amd64 \
  --tag ghcr.io/$GH_OWNER/easyappointments:latest \
  --push
```

### **4. Verificação**
```bash
# Verificar se a imagem foi publicada
curl -H "Authorization: Bearer $GHCR_TOKEN" \
  https://ghcr.io/v2/$GH_OWNER/easyappointments/tags/list

# Pull da imagem para teste
docker pull ghcr.io/$GH_OWNER/easyappointments:latest

# Inspecionar a imagem
docker image inspect ghcr.io/$GH_OWNER/easyappointments:latest
```

### **5. Build com Cache Local**
```bash
# Build usando cache local (mais rápido para desenvolvimento)
docker buildx build \
  --context . \
  --file docker/php-fpm/Dockerfile \
  --target production \
  --platform linux/amd64 \
  --tag ghcr.io/$GH_OWNER/easyappointments:dev \
  --cache-from type=local,src=/tmp/.buildx-cache \
  --cache-to type=local,dest=/tmp/.buildx-cache \
  --push
```

## **Script de Uma Linha**

### **Build e Push Completo**
```bash
export GH_OWNER="your-username" && export VERSION_TAG="v1.0.0.0" && echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin && docker buildx build --context . --file docker/php-fpm/Dockerfile --target production --platform linux/amd64,linux/arm64 --tag ghcr.io/$GH_OWNER/easyappointments:$VERSION_TAG --tag ghcr.io/$GH_OWNER/easyappointments:latest --push
```

## **Comandos de Desenvolvimento**

### **Build Local (sem push)**
```bash
# Para testar localmente antes do push
docker buildx build \
  --context . \
  --file docker/php-fpm/Dockerfile \
  --target production \
  --tag easyappointments:local-test \
  --load
```

### **Build com Output para Análise**
```bash
# Build com informações detalhadas
docker buildx build \
  --context . \
  --file docker/php-fpm/Dockerfile \
  --target production \
  --progress=plain \
  --no-cache \
  --tag easyappointments:debug
```

## **Comandos de Limpeza**

### **Limpar Cache de Build**
```bash
# Limpar cache do buildx
docker buildx prune -f

# Limpar imagens não utilizadas
docker image prune -f

# Limpar sistema completo
docker system prune -af --volumes
```

### **Remover Imagens Locais**
```bash
# Remover imagens específicas
docker rmi ghcr.io/$GH_OWNER/easyappointments:latest
docker rmi ghcr.io/$GH_OWNER/easyappointments:$VERSION_TAG

# Remover todas as imagens do projeto
docker images | grep easyappointments | awk '{print $3}' | xargs docker rmi -f
```

## **Troubleshooting**

### **Erro de Autenticação**
```bash
# Re-login
docker logout ghcr.io
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin

# Verificar login
docker system info | grep ghcr.io
```

### **Erro de Buildx**
```bash
# Criar novo builder
docker buildx create --name mybuilder --use

# Verificar builders disponíveis
docker buildx ls

# Remover builder problemático
docker buildx rm mybuilder
```

### **Verificar Dockerfile**
```bash
# Validar sintaxe do Dockerfile
docker buildx build --context . --file docker/php-fpm/Dockerfile --target production --dry-run

# Build com logs detalhados
BUILDKIT_PROGRESS=plain docker buildx build --context . --file docker/php-fpm/Dockerfile --target production --no-cache
```
