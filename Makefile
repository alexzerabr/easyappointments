# Easy!Appointments Production Management Makefile
# 
# This Makefile provides convenient shortcuts for production deployment operations.
# All commands are routed through the unified deploy-production.sh script.
#
# USAGE:
#   make start     # Start production environment
#   make stop      # Stop production environment
#   make restart   # Restart production environment
#   make reset     # Reset production environment (DESTRUCTIVE!)
#   make backup    # Create backup of production data
#   make monitor   # Monitor production environment health
#   make status    # Show current status
#   make logs      # Show production logs
#   make help      # Show this help

.PHONY: help start stop restart reset backup monitor status logs clean

# Default target
help:
	@echo "Easy!Appointments Production Management"
	@echo "======================================="
	@echo ""
	@echo "Available targets:"
	@echo "  start     - Start production environment"
	@echo "  stop      - Stop production environment gracefully"
	@echo "  restart   - Restart production environment"
	@echo "  reset     - Reset production environment (DESTRUCTIVE!)"
	@echo "  backup    - Create backup of production data"
	@echo "  monitor   - Monitor production environment health"
	@echo "  status    - Show current container status"
	@echo "  logs      - Show production logs"
	@echo "  clean     - Clean development environment"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make start    # Start production for the first time"
	@echo "  make backup   # Create a backup before maintenance"
	@echo "  make monitor  # Check system health"
	@echo "  make restart  # Quick restart"
	@echo ""

# Production management commands
start:
	@echo "🚀 Starting production environment..."
	@./deploy/deploy-production.sh --start

stop:
	@echo "🛑 Stopping production environment..."
	@./deploy/deploy-production.sh --stop

restart: stop start
	@echo "🔄 Production environment restarted"

reset:
	@echo "💥 Resetting production environment..."
	@./deploy/deploy-production.sh --reset

backup:
	@echo "📦 Creating production backup..."
	@./deploy/deploy-production.sh --backup

monitor:
	@echo "🔍 Monitoring production environment..."
	@./deploy/deploy-production.sh --monitor

# Status and logs
status:
	@echo "📊 Production environment status:"
	@docker compose -f docker-compose.prod.yml --env-file .env.production ps 2>/dev/null || echo "❌ No containers found or environment not configured"

logs:
	@echo "📋 Production logs (last 50 lines):"
	@docker compose -f docker-compose.prod.yml --env-file .env.production logs --tail=50 2>/dev/null || echo "❌ Cannot access logs - environment may not be running"

# Development environment cleanup (separate from production)
clean:
	@echo "🧹 Cleaning development environment..."
	@./deploy/clean_env.sh

# Quick health check without full monitor
health:
	@echo "💓 Quick health check..."
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" --connect-timeout 5 http://localhost/index.php || echo "❌ Application not responding"

# Show environment info
info:
	@echo "ℹ️  Environment Information:"
	@echo "  Docker: $$(docker --version 2>/dev/null || echo 'Not installed')"
	@echo "  Docker Compose: $$(docker compose version 2>/dev/null || echo 'Not installed')"
	@echo "  Environment file: $$([ -f .env.production ] && echo '✅ Found' || echo '❌ Missing')"
	@echo "  Compose file: $$([ -f docker-compose.prod.yml ] && echo '✅ Found' || echo '❌ Missing')"

# Advanced operations
rebuild:
	@echo "🔨 Rebuilding production environment..."
	@docker compose -f docker-compose.prod.yml --env-file .env.production build --no-cache

pull:
	@echo "📥 Pulling latest images..."
	@docker compose -f docker-compose.prod.yml --env-file .env.production pull

# Maintenance shortcuts
maintenance-start: backup stop
	@echo "🔧 Maintenance mode started - environment stopped and backed up"

maintenance-end: start
	@echo "✅ Maintenance mode ended - environment restarted"

# Database operations
db-backup:
	@echo "💾 Creating database backup..."
	@mkdir -p storage/backups
	@docker compose -f docker-compose.prod.yml --env-file .env.production exec -T mysql mysqldump -u root -p$${MYSQL_ROOT_PASSWORD} --single-transaction --routines --triggers $${DB_DATABASE:-easyappointments} > storage/backups/db_backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "✅ Database backup created in storage/backups/"

db-shell:
	@echo "🐚 Opening database shell..."
	@docker compose -f docker-compose.prod.yml --env-file .env.production exec mysql mysql -u root -p

# Container operations
shell:
	@echo "🐚 Opening PHP container shell..."
	@docker compose -f docker-compose.prod.yml --env-file .env.production exec php-fpm bash

nginx-shell:
	@echo "🐚 Opening Nginx container shell..."
	@docker compose -f docker-compose.prod.yml --env-file .env.production exec nginx sh

# Log operations
logs-follow:
	@echo "📋 Following production logs (Ctrl+C to stop)..."
	@docker compose -f docker-compose.prod.yml --env-file .env.production logs -f

logs-php:
	@echo "📋 PHP-FPM logs:"
	@docker compose -f docker-compose.prod.yml --env-file .env.production logs php-fpm

logs-nginx:
	@echo "📋 Nginx logs:"
	@docker compose -f docker-compose.prod.yml --env-file .env.production logs nginx

logs-mysql:
	@echo "📋 MySQL logs:"
	@docker compose -f docker-compose.prod.yml --env-file .env.production logs mysql

# System cleanup
docker-clean:
	@echo "🧹 Cleaning Docker system..."
	@docker system prune -f
	@docker volume prune -f
	@docker network prune -f

# Development helpers (don't affect production)
dev-start:
	@echo "🚀 Starting development environment..."
	@docker compose up -d

dev-stop:
	@echo "🛑 Stopping development environment..."
	@docker compose down

dev-logs:
	@echo "📋 Development logs:"
	@docker compose logs -f
