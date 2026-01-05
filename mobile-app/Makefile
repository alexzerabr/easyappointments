# Easy!Appointments Mobile App - Makefile
# ==========================================

.PHONY: help setup clean deps codegen run run-android run-ios run-web build-apk build-appbundle build-ios test analyze format check

# Cores para output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Variáveis de ambiente (podem ser sobrescritas)
API_BASE_URL ?= http://localhost/api/v1
WS_URL ?= ws://localhost/ws

# Help - comando padrão
help:
	@echo ""
	@echo "$(BLUE)Easy!Appointments Mobile App$(NC)"
	@echo "=============================="
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make setup          - Setup completo (deps + codegen)"
	@echo "  make deps           - Instalar dependências"
	@echo "  make codegen        - Gerar código (build_runner)"
	@echo "  make clean          - Limpar projeto"
	@echo ""
	@echo "$(GREEN)Desenvolvimento:$(NC)"
	@echo "  make run            - Executar no dispositivo padrão"
	@echo "  make run-android    - Executar no Android"
	@echo "  make run-ios        - Executar no iOS"
	@echo "  make run-web        - Executar no Chrome"
	@echo "  make devices        - Listar dispositivos disponíveis"
	@echo ""
	@echo "$(GREEN)Build:$(NC)"
	@echo "  make build-apk      - Build APK Android (release)"
	@echo "  make build-appbundle- Build App Bundle (Play Store)"
	@echo "  make build-ios      - Build iOS (release)"
	@echo "  make build-all      - Build Android + iOS"
	@echo ""
	@echo "$(GREEN)Qualidade:$(NC)"
	@echo "  make test           - Executar testes"
	@echo "  make analyze        - Analisar código (lint)"
	@echo "  make format         - Formatar código"
	@echo "  make check          - Análise + Testes"
	@echo ""
	@echo "$(GREEN)Configuração:$(NC)"
	@echo "  make doctor         - Verificar instalação Flutter"
	@echo "  make upgrade        - Atualizar dependências"
	@echo ""
	@echo "$(YELLOW)Variáveis de ambiente:$(NC)"
	@echo "  API_BASE_URL=$(API_BASE_URL)"
	@echo "  WS_URL=$(WS_URL)"
	@echo ""
	@echo "$(YELLOW)Exemplo com URL customizada:$(NC)"
	@echo "  make run API_BASE_URL=https://api.exemplo.com/v1"
	@echo ""

# ==========================================
# Setup
# ==========================================

setup: deps codegen
	@echo "$(GREEN)✓ Setup completo!$(NC)"

deps:
	@echo "$(BLUE)Instalando dependências...$(NC)"
	flutter pub get
	@echo "$(GREEN)✓ Dependências instaladas$(NC)"

codegen:
	@echo "$(BLUE)Gerando código...$(NC)"
	flutter pub run build_runner build --delete-conflicting-outputs
	@echo "$(GREEN)✓ Código gerado$(NC)"

codegen-watch:
	@echo "$(BLUE)Gerando código (watch mode)...$(NC)"
	flutter pub run build_runner watch --delete-conflicting-outputs

clean:
	@echo "$(BLUE)Limpando projeto...$(NC)"
	flutter clean
	rm -rf .dart_tool/
	rm -rf build/
	@echo "$(GREEN)✓ Projeto limpo$(NC)"

# ==========================================
# Desenvolvimento
# ==========================================

run:
	@echo "$(BLUE)Executando app...$(NC)"
	flutter run \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)

run-android:
	@echo "$(BLUE)Executando no Android...$(NC)"
	flutter run -d android \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)

run-ios:
	@echo "$(BLUE)Executando no iOS...$(NC)"
	flutter run -d ios \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)

run-web:
	@echo "$(BLUE)Executando no Chrome...$(NC)"
	flutter run -d chrome \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)

run-release:
	@echo "$(BLUE)Executando em modo release...$(NC)"
	flutter run --release \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)

run-profile:
	@echo "$(BLUE)Executando em modo profile...$(NC)"
	flutter run --profile \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)

devices:
	@echo "$(BLUE)Dispositivos disponíveis:$(NC)"
	flutter devices

# ==========================================
# Build
# ==========================================

build-apk:
	@echo "$(BLUE)Gerando APK...$(NC)"
	flutter build apk --release \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)
	@echo "$(GREEN)✓ APK gerado em build/app/outputs/flutter-apk/app-release.apk$(NC)"

build-apk-split:
	@echo "$(BLUE)Gerando APKs por arquitetura...$(NC)"
	flutter build apk --release --split-per-abi \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)
	@echo "$(GREEN)✓ APKs gerados em build/app/outputs/flutter-apk/$(NC)"

build-appbundle:
	@echo "$(BLUE)Gerando App Bundle...$(NC)"
	flutter build appbundle --release \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)
	@echo "$(GREEN)✓ App Bundle gerado em build/app/outputs/bundle/release/app-release.aab$(NC)"

build-ios:
	@echo "$(BLUE)Gerando build iOS...$(NC)"
	flutter build ios --release \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)
	@echo "$(GREEN)✓ Build iOS gerado$(NC)"

build-ipa:
	@echo "$(BLUE)Gerando IPA...$(NC)"
	flutter build ipa --release \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)
	@echo "$(GREEN)✓ IPA gerado em build/ios/ipa/$(NC)"

build-web:
	@echo "$(BLUE)Gerando build Web...$(NC)"
	flutter build web --release \
		--dart-define=API_BASE_URL=$(API_BASE_URL) \
		--dart-define=WS_URL=$(WS_URL)
	@echo "$(GREEN)✓ Build Web gerado em build/web/$(NC)"

build-all: build-apk build-ios
	@echo "$(GREEN)✓ Builds Android e iOS gerados$(NC)"

# ==========================================
# Qualidade
# ==========================================

test:
	@echo "$(BLUE)Executando testes...$(NC)"
	flutter test
	@echo "$(GREEN)✓ Testes concluídos$(NC)"

test-coverage:
	@echo "$(BLUE)Executando testes com cobertura...$(NC)"
	flutter test --coverage
	@echo "$(GREEN)✓ Relatório em coverage/lcov.info$(NC)"

analyze:
	@echo "$(BLUE)Analisando código...$(NC)"
	flutter analyze
	@echo "$(GREEN)✓ Análise concluída$(NC)"

format:
	@echo "$(BLUE)Formatando código...$(NC)"
	dart format lib/ test/
	@echo "$(GREEN)✓ Código formatado$(NC)"

format-check:
	@echo "$(BLUE)Verificando formatação...$(NC)"
	dart format --set-exit-if-changed lib/ test/

check: analyze test
	@echo "$(GREEN)✓ Análise e testes OK$(NC)"

# ==========================================
# Utilitários
# ==========================================

doctor:
	@echo "$(BLUE)Verificando instalação Flutter...$(NC)"
	flutter doctor -v

upgrade:
	@echo "$(BLUE)Atualizando dependências...$(NC)"
	flutter pub upgrade
	@echo "$(GREEN)✓ Dependências atualizadas$(NC)"

outdated:
	@echo "$(BLUE)Verificando dependências desatualizadas...$(NC)"
	flutter pub outdated

icons:
	@echo "$(BLUE)Gerando ícones do app...$(NC)"
	flutter pub run flutter_launcher_icons
	@echo "$(GREEN)✓ Ícones gerados$(NC)"

splash:
	@echo "$(BLUE)Gerando splash screen...$(NC)"
	flutter pub run flutter_native_splash:create
	@echo "$(GREEN)✓ Splash screen gerada$(NC)"

# ==========================================
# Firebase
# ==========================================

firebase-init:
	@echo "$(BLUE)Configurando Firebase...$(NC)"
	@echo "$(YELLOW)Certifique-se de ter o FlutterFire CLI instalado:$(NC)"
	@echo "  dart pub global activate flutterfire_cli"
	@echo ""
	@echo "$(YELLOW)Depois execute:$(NC)"
	@echo "  flutterfire configure"

# ==========================================
# Git Hooks (opcional)
# ==========================================

install-hooks:
	@echo "$(BLUE)Instalando git hooks...$(NC)"
	@echo '#!/bin/sh\nmake format-check && make analyze' > ../.git/hooks/pre-commit
	@chmod +x ../.git/hooks/pre-commit
	@echo "$(GREEN)✓ Pre-commit hook instalado$(NC)"
