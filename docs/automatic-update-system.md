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

Quando `./deploy/deploy-production.sh update` é executado:

1. **Git Pull**: Atualiza o código do repositório
2. **Backup Automático**: Cria backup completo antes de qualquer mudança
3. **Docker Pull**: Baixa a nova imagem do GHCR
4. **Down/Up**: Para e reinicia os containers com `FORCE_UPDATE=true`
5. **Detecção Automática**: O script `start-production` detecta:
   - Nova imagem (comparando timestamps de `/tmp/app` vs `.docker-init-complete`)
   - Ou flag `FORCE_UPDATE=true` definido pelo deploy script

6. **Atualização Seletiva**:
   - **Código da Aplicação**: Atualiza controllers, views, libraries, models, helpers, migrations
   - **Configurações**: Atualiza `config.php` (com merge inteligente para preservar configurações do usuário)
   - **Assets Compilados**:
     - Remove todos os arquivos `.min.js` e `.min.css` antigos
     - Copia recursivamente todos os novos assets minificados (incluindo subdiretórios como `pages/`)
     - Substitui completamente o diretório `vendor`
   - **System Files**: Atualiza arquivos do framework

7. **Database Migrations**: Executa migrations automaticamente
8. **Validação Pós-Update**: Verifica se a aplicação está respondendo corretamente
9. **Relatório de Update**: Mostra timestamp e digest da versão atualizada

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
- Comando `update` agora define `FORCE_UPDATE=true`
- Implementado git pull automático antes de atualizar
- Backup automático criado antes de qualquer mudança
- Validação pós-update garante que aplicação está funcionando
- Relatório detalhado mostra informações da versão atualizada
- Removida necessidade de rebuild manual de assets em produção
- Assets são atualizados automaticamente do cache da imagem

### `docker-compose.yml` (produção)
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
1. ✅ Fazer git pull do código mais recente do repositório
2. ✅ Criar backup completo (banco de dados + configs + storage)
3. ✅ Parar containers antigos
4. ✅ Baixar nova imagem Docker do registry
5. ✅ Iniciar novos containers com `FORCE_UPDATE=true`
6. ✅ Atualizar automaticamente todos os assets compilados
7. ✅ Atualizar código da aplicação (controllers, views, models, etc.)
8. ✅ Atualizar arquivos de configuração (com merge inteligente)
9. ✅ Executar migrations do banco de dados
10. ✅ Validar resposta da aplicação
11. ✅ Exibir relatório com informações da versão atualizada

### Force Update Manual
Se você precisar forçar uma atualização sem fazer git pull ou docker pull:
```bash
FORCE_UPDATE=true docker compose --env-file .env restart php-fpm whatsapp-worker
```

### Verificar Status de Atualização
```bash
# Ver timestamp da última inicialização
docker compose exec php-fpm cat /var/www/html/.docker-init-complete

# Ver digest da imagem atual
docker compose exec php-fpm cat /var/www/html/.docker-image-digest
```

## Arquivos Rastreados

O sistema mantém os seguintes arquivos de controle no volume `app_assets`:

- `.docker-init-complete`: Timestamp da última atualização bem-sucedida
- `.docker-image-digest`: Digest/timestamp da imagem Docker atual
- `config.php.backup`: Backup do config.php anterior (quando atualizado)

## Vantagens

1. **Automação Completa**: Nenhuma intervenção manual necessária
2. **Rollback Seguro**: Backup automático criado antes de qualquer mudança
3. **Preservação de Dados**: Configurações de usuário são preservadas
4. **Atualizações Recursivas**: Subdiretórios de assets são corretamente atualizados
5. **Validação Automática**: Sistema detecta quando assets estão desatualizados
6. **Zero Downtime**: Migrations executam automaticamente sem intervenção
7. **Sincronização de Código**: Git pull automático garante código atualizado
8. **Verificação Pós-Update**: Confirma que aplicação está funcionando após atualização
9. **Rastreabilidade**: Timestamp e digest permitem tracking de versões
10. **Detecção Inteligente**: Múltiplos métodos para detectar necessidade de update

## Troubleshooting

### Assets não estão atualizando
```bash
# Forçar atualização manual
FORCE_UPDATE=true docker compose restart php-fpm
```

### Config.php não atualizou
```bash
# O sistema preserva config.php por padrão para evitar perder configurações
# Verifique o backup e merge manualmente se necessário
docker compose exec php-fpm cat /var/www/html/application/config/config.php.backup
```

### Verificar se assets foram compilados na imagem
```bash
# Listar assets minificados na imagem
docker compose exec php-fpm find /tmp/app/assets -name "*.min.js" -o -name "*.min.css"
```

## Próximos Passos

Para releases futuras, considere:
- ✅ ~~Adicionar git pull automático~~ (Implementado)
- ✅ ~~Adicionar health checks pós-atualização~~ (Implementado)
- ✅ ~~Adicionar relatório de versão~~ (Implementado)
- Implementar versionamento semântico de imagens Docker
- Criar sistema de rollback automático em caso de falha
- Implementar notificações de atualização bem-sucedida (email/webhook)
- Adicionar comparação de changelogs entre versões

