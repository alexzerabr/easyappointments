# 🔨 Guia de Build - EasyAppointments

> **Guia completo para build de imagens Docker e assets da aplicação**

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Build Docker (Multi-arch)](#build-docker-multi-arch)
- [Build Local (NPM)](#build-local-npm)
- [Pipeline CI/CD](#pipeline-cicd)
- [Troubleshooting](#troubleshooting)
- [Referências](#referências)

---

## 🎯 Visão Geral

O EasyAppointments oferece duas formas de build:

1. **🐳 Docker Multi-arch**: Build de imagens para produção (AMD64 + ARM64)
2. **💻 Build Local (NPM)**: Compilação de assets para desenvolvimento local

---

# 🐳 Build Docker (Multi-arch)

## Script Automatizado

### Build Completo com Validações

```bash
# Build multi-plataforma (AMD64 + ARM64)
./build-multiplatform-local-dev.sh
```

**O que o script faz:**

### **1. Pré-Validações (Antes do Build)**
- ✅ Valida arquivos essenciais (composer.json, package.json, gulpfile.js)
- ✅ Verifica integridade do composer.lock
- ✅ Valida estrutura de diretórios
- ✅ Verifica sintaxe do Dockerfile

### **2. Build Multi-Arquitetura**
- ✅ Compila para linux/amd64 e linux/arm64
- ✅ Compila assets dentro da imagem (npm + gulp)
- ✅ Instala vendor otimizado (composer --no-dev)
- ✅ Adiciona metadados de versão (labels OCI)
- ✅ Faz push automático para GHCR

### **3. Pós-Validações (Depois do Build)**
- ✅ Valida tags criadas no registry
- ✅ Inspeciona digest e metadados
- ✅ Gera relatório de build completo

**Tempo estimado:** 45-60 minutos

### Tags Criadas

```
ghcr.io/alexzerabr/easyappointments:latest        (multi-arch)
ghcr.io/alexzerabr/easyappointments:arm64-latest  (arm64)
ghcr.io/alexzerabr/easyappointments:latest-arm64  (arm64)
```

---

## Comandos Manuais de Build

### 1. Configuração Inicial

```bash
# Configurar variáveis
export GH_OWNER="alexzerabr"
export GHCR_TOKEN="<seu-token-ghcr>"
export VERSION_TAG="v1.0.0"

# Login no GHCR
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin
```

### 2. Build Multi-Arquitetura (AMD64 + ARM64)

```bash
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

### 3. Build Simples (apenas AMD64)

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

### 4. Build Local (sem push)

```bash
# Para testar localmente antes do push
docker buildx build \
  --context . \
  --file docker/php-fpm/Dockerfile \
  --target production \
  --tag easyappointments:local-test \
  --load
```

### 5. Build com Debug

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

---

## Verificação de Imagens

### Listar Tags Publicadas

```bash
# Verificar tags no GHCR
curl -H "Authorization: Bearer $GHCR_TOKEN" \
  https://ghcr.io/v2/$GH_OWNER/easyappointments/tags/list
```

### Pull e Inspeção

```bash
# Pull da imagem
docker pull ghcr.io/$GH_OWNER/easyappointments:latest

# Inspecionar imagem
docker image inspect ghcr.io/$GH_OWNER/easyappointments:latest

# Ver manifest multi-arch
docker buildx imagetools inspect ghcr.io/$GH_OWNER/easyappointments:latest
```

### Verificar Metadados da Imagem

```bash
# Ver labels OCI
docker inspect ghcr.io/alexzerabr/easyappointments:latest | grep -A5 Labels

# Ver versão dentro do container
docker run --rm ghcr.io/alexzerabr/easyappointments:latest \
  cat /etc/easyappointments-version
```

---

## Smoke Test da Imagem

Antes de fazer deploy em produção, teste a imagem:

```bash
# Executar smoke test
./deploy/deploy-production.sh smoke-test
```

**Validações realizadas:**
- ✅ Pull da imagem bem-sucedido
- ✅ Arquivos críticos presentes (index.php, vendor/, assets/)
- ✅ Assets compilados (CSS/JS minificados)
- ✅ Estrutura de diretórios correta

---

# 💻 Build Local (NPM)

## Setup Sem Docker

Para desenvolvimento local sem Docker, você pode compilar assets diretamente:

### Pré-requisitos

```bash
# Versões necessárias
node --version    # v18.20.8+
npm --version     # v10.9.3+
php --version     # PHP 8.4.12+
composer --version # 2.8.12+
```

### Instalação

#### 1. Instalar Dependências

```bash
# Dependências NPM
npm install

# Dependências PHP
composer install
```

#### 2. Build dos Assets

```bash
# Build completo
npm run build

# Ou tarefas individuais
npx gulp clean      # Limpar arquivos temporários
npx gulp vendor     # Copiar dependências vendor
npx gulp scripts    # Minificar JavaScript
npx gulp styles     # Compilar SCSS para CSS
```

#### 3. Watch Mode (Desenvolvimento)

```bash
# Compilação automática ao salvar arquivos
npm start
```

---

## Comandos NPM Disponíveis

### Build

```bash
# Build completo de produção
npm run build

# Build específico
npx gulp scripts    # Apenas JavaScript
npx gulp styles     # Apenas CSS
npx gulp clean      # Limpar arquivos
```

### Manutenção

```bash
# Atualizar dependências
npm update
composer update

# Limpar cache
npm cache clean --force
composer clear-cache

# Verificar vulnerabilidades
npm audit
npm audit fix
```

---

## Estrutura de Assets

### Diretórios

```
assets/
├── css/                 # SCSS sources
│   ├── general.scss
│   ├── themes/          # Temas
│   └── components/      # Componentes
├── js/                  # JavaScript sources
│   ├── app.js
│   ├── components/
│   ├── pages/
│   └── utils/
└── vendor/              # Dependências externas (geradas)
```

### Assets Compilados

```
assets/
├── css/
│   └── general.min.css     # CSS minificado
├── js/
│   └── app.min.js          # JS minificado
└── vendor/                 # Bibliotecas externas
```

---

# 🔄 Pipeline CI/CD

## GitHub Actions

O projeto usa GitHub Actions para build automático:

### Workflow Principal

**Arquivo:** `.github/workflows/build-and-push.yml`

**Triggers:**
- Push na branch `main`
- Push em tags `v*`
- Pull requests

**Etapas:**
1. Checkout do código
2. Setup do Docker Buildx
3. Login no GHCR
4. Build multi-arch (AMD64 + ARM64)
5. Push para registry
6. Scan de vulnerabilidades

### Tags Automáticas

```bash
# Push na main
→ ghcr.io/alexzerabr/easyappointments:latest

# Tag de versão
git tag v1.2.3
git push origin v1.2.3
→ ghcr.io/alexzerabr/easyappointments:v1.2.3
→ ghcr.io/alexzerabr/easyappointments:latest (atualizada)
```

---

## Deploy Pós-Build

### Atualizar Produção

Após build bem-sucedido, atualize o ambiente:

```bash
# Pull da nova imagem e restart
./deploy/deploy-production.sh update

# Ou com refresh de assets
./deploy/deploy-production.sh update --refresh-assets

# Ou para tag específica
IMAGE_TAG=v1.2.3 ./deploy/deploy-production.sh update
```

### Fluxo Completo

```bash
# 1. Build local (opcional - testar antes)
./build-multiplatform-local-dev.sh

# 2. Smoke test
./deploy/deploy-production.sh smoke-test

# 3. Verificar updates disponíveis
./deploy/deploy-production.sh check-updates

# 4. Deploy
sudo ./deploy/deploy-production.sh update
```

---

# 🐛 Troubleshooting

## Problemas de Build Docker

### Erro: Login no GHCR falhou

```bash
# Re-login
docker logout ghcr.io
echo $GHCR_TOKEN | docker login ghcr.io -u $GH_OWNER --password-stdin

# Verificar login
docker system info | grep ghcr.io
```

### Erro: Buildx não disponível

```bash
# Criar novo builder
docker buildx create --name mybuilder --use

# Verificar builders
docker buildx ls

# Remover builder problemático
docker buildx rm mybuilder
```

### Erro: Validação pré-build falha

```bash
# Verificar arquivos essenciais
ls -la composer.json package.json gulpfile.js babel.config.json

# Verificar composer.lock
cat composer.lock | grep "packages"

# Verificar Dockerfile
docker build --check docker/php-fpm/Dockerfile
```

### Build muito lento

```bash
# Usar cache local
docker buildx build \
  --cache-from type=local,src=/tmp/.buildx-cache \
  --cache-to type=local,dest=/tmp/.buildx-cache \
  ...
```

---

## Problemas de Build NPM

### Erro: Permission denied

```bash
# Opção 1: Configurar prefix
npm config set prefix ~/.npm-global

# Opção 2: Usar yarn
yarn install

# Opção 3: Ajustar permissões
sudo chown -R $USER:$USER node_modules/
```

### Erro: Assets não compilam

```bash
# Limpar e reinstalar
rm -rf node_modules/
npm install
npm run build

# Verificar gulp
npx gulp --version
```

### Erro: SCSS compilation failed

```bash
# Verificar sintaxe dos arquivos SCSS
find assets/css -name "*.scss" -exec node-sass {} --output /tmp \;

# Reinstalar node-sass
npm rebuild node-sass
```

---

## Limpeza

### Limpar Cache de Build

```bash
# Docker buildx
docker buildx prune -f

# Imagens não utilizadas
docker image prune -f

# Sistema completo (CUIDADO!)
docker system prune -af --volumes
```

### Remover Imagens Locais

```bash
# Remover imagem específica
docker rmi ghcr.io/alexzerabr/easyappointments:latest

# Remover todas as imagens do projeto
docker images | grep easyappointments | awk '{print $3}' | xargs docker rmi -f
```

### Limpar NPM

```bash
# Limpar node_modules
rm -rf node_modules/

# Limpar cache
npm cache clean --force

# Reinstalar
npm install
```

---

## 🔗 Referências

### Documentação Relacionada

| Documento | Descrição |
|-----------|-----------|
| [DEPLOY.md](DEPLOY.md) | Guia de deploy completo |
| [README.md](README.md) | Visão geral do projeto |
| [docs/docker.md](docs/docker.md) | Arquitetura Docker |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Guia de contribuição |

### Scripts

| Script | Localização | Uso |
|--------|-------------|-----|
| Build Multi-arch | `build-multiplatform-local-dev.sh` | Build Docker |
| Deploy Produção | `deploy/deploy-production.sh` | Deploy |

### Arquivos de Configuração

| Arquivo | Propósito |
|---------|-----------|
| `docker/php-fpm/Dockerfile` | Build da imagem |
| `gulpfile.js` | Build de assets |
| `package.json` | Dependências NPM |
| `composer.json` | Dependências PHP |
| `babel.config.json` | Configuração Babel |

---

## 📊 Comparação de Métodos

| Aspecto | Docker Build | NPM Local |
|---------|--------------|-----------|
| **Tempo** | 45-60 min | 2-5 min |
| **Plataformas** | AMD64 + ARM64 | Host apenas |
| **Assets** | Incluídos | Manual |
| **Vendor** | Incluído | Manual |
| **Uso** | Produção | Desenvolvimento |
| **Isolamento** | Total | Nenhum |

---

**Versão:** 1.0  
**Última Atualização:** Outubro 2025  
**Status:** ✅ Produção

