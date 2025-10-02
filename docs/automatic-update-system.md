# Sistema de Atualização Automática de Assets

## Visão Geral

O sistema de deploy foi aprimorado para garantir que todos os arquivos compilados (assets minificados, arquivos de configuração, e código da aplicação) sejam automaticamente atualizados quando uma nova imagem Docker for implantada.

## Como Funciona

### 1. Build da Imagem

Durante o build da imagem Docker (`build-multiplatform-local-dev.sh`):
- Todos os assets são compilados via `gulp` (JS, CSS, vendor files)
- Os arquivos compilados são armazenados em `/tmp/app/assets/` dentro da imagem
- A configuração do framework (incluindo mapeamento de locales) é empacotada
- Todo o código da aplicação é incluído na imagem

### 2. Inicialização do Container (Primeira Vez)

Quando o container `php-fpm` inicia pela primeira vez:
- O script `start-production` detecta que o volume está vazio
- Copia todos os arquivos de `/tmp/app/` para `/var/www/html/`
- Cria um arquivo marker `.docker-init-complete` com timestamp
- Armazena o timestamp da imagem em `.docker-image-digest`

### 3. Atualizações Subsequentes

Quando `./deploy/deploy-production.sh --update` é executado:

1. **Git Pull**: Atualiza o código do repositório
2. **Docker Pull**: Baixa a nova imagem do GHCR
3. **Down/Up**: Para e reinicia os containers com `FORCE_UPDATE=true`
4. **Detecção Automática**: O script `start-production` detecta:
   - Nova imagem (comparando timestamps de `/tmp/app` vs `.docker-init-complete`)
   - Ou flag `FORCE_UPDATE=true` definido pelo deploy script

5. **Atualização Seletiva**:
   - **Código da Aplicação**: Atualiza controllers, views, libraries, models, helpers, migrations
   - **Configurações**: Atualiza `config.php` (com merge inteligente para preservar configurações do usuário)
   - **Assets Compilados**:
     - Remove todos os arquivos `.min.js` e `.min.css` antigos
     - Copia recursivamente todos os novos assets minificados (incluindo subdiretórios como `pages/`)
     - Substitui completamente o diretório `vendor`
   - **System Files**: Atualiza arquivos do framework

### 4. Detecção de Mudanças

O sistema usa múltiplos métodos para detectar quando uma atualização é necessária:

1. **Timestamp Comparison**: Compara `mtime` de `/tmp/app` com `.docker-init-complete`
2. **Force Update Flag**: `FORCE_UPDATE=true` força atualização mesmo sem mudança de timestamp
3. **Image Digest**: Armazena digest da última atualização para rastreamento

## Arquivos Modificados

### `docker/php-fpm/start-production`
- Adicionado suporte para `FORCE_UPDATE` env var
- Melhorada a lógica de cópia de assets recursiva
- Adicionado merge inteligente de `config.php`
- Implementado sistema de tracking de image digest

### `deploy/deploy-production.sh`
- Comando `--update` agora define `FORCE_UPDATE=true`
- Removida necessidade de rebuild manual de assets em produção
- Assets são atualizados automaticamente do cache da imagem

### `docker-compose.prod.yml`
- Adicionada env var `FORCE_UPDATE` para containers `php-fpm` e `whatsapp-worker`
- Permite propagação da flag de force update para os containers

## Fluxo de Trabalho de Produção

### Atualização Completa (Recomendado)
```bash
# No servidor de produção
cd /opt/easyappointments
./deploy/deploy-production.sh --update
```

Isso irá:
1. ✅ Fazer git pull do código mais recente
2. ✅ Baixar nova imagem Docker do registry
3. ✅ Parar containers antigos
4. ✅ Iniciar novos containers com `FORCE_UPDATE=true`
5. ✅ Atualizar automaticamente todos os assets compilados
6. ✅ Atualizar arquivos de configuração (com merge)
7. ✅ Executar migrations do banco de dados
8. ✅ Validar resposta da aplicação

### Force Update Manual
Se você precisar forçar uma atualização sem fazer git pull ou docker pull:
```bash
FORCE_UPDATE=true docker compose -f docker-compose.prod.yml --env-file .env.production restart php-fpm whatsapp-worker
```

### Verificar Status de Atualização
```bash
# Ver timestamp da última inicialização
docker compose -f docker-compose.prod.yml exec php-fpm cat /var/www/html/.docker-init-complete

# Ver digest da imagem atual
docker compose -f docker-compose.prod.yml exec php-fpm cat /var/www/html/.docker-image-digest
```

## Arquivos Rastreados

O sistema mantém os seguintes arquivos de controle no volume `app_assets`:

- `.docker-init-complete`: Timestamp da última atualização bem-sucedida
- `.docker-image-digest`: Digest/timestamp da imagem Docker atual
- `config.php.backup`: Backup do config.php anterior (quando atualizado)

## Vantagens

1. **Automação Completa**: Nenhuma intervenção manual necessária
2. **Rollback Seguro**: Backup automático de configurações críticas
3. **Preservação de Dados**: Configurações de usuário são preservadas
4. **Atualizações Recursivas**: Subdiretórios de assets são corretamente atualizados
5. **Validação Automática**: Sistema detecta quando assets estão desatualizados
6. **Zero Downtime**: Migrations executam automaticamente sem intervenção

## Troubleshooting

### Assets não estão atualizando
```bash
# Forçar atualização manual
FORCE_UPDATE=true docker compose -f docker-compose.prod.yml restart php-fpm
```

### Config.php não atualizou
```bash
# O sistema preserva config.php por padrão para evitar perder configurações
# Verifique o backup e merge manualmente se necessário
docker compose -f docker-compose.prod.yml exec php-fpm cat /var/www/html/application/config/config.php.backup
```

### Verificar se assets foram compilados na imagem
```bash
# Listar assets minificados na imagem
docker compose -f docker-compose.prod.yml exec php-fpm find /tmp/app/assets -name "*.min.js" -o -name "*.min.css"
```

## Próximos Passos

Para releases futuras, considere:
- Implementar versionamento semântico de imagens Docker
- Adicionar health checks pós-atualização
- Criar sistema de rollback automático em caso de falha
- Implementar notificações de atualização bem-sucedida (email/webhook)

