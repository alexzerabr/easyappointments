# 🚀 Easy!Appointments - Setup com NPM (Sem Docker)

Este guia fornece instruções completas para configurar e executar o Easy!Appointments usando NPM sem Docker, ideal para desenvolvimento local.

## 📋 Pré-requisitos

### Software Necessário
- **Node.js**: v18.20.8 ou superior
- **npm**: v10.9.3 ou superior
- **PHP**: 8.4.12 ou superior
- **Composer**: 2.8.12 ou superior
- **MySQL**: 8.0 ou superior
- **Apache/Nginx**: Para servir a aplicação

### Verificação de Versões
```bash
node --version    # Deve retornar v18.20.8+
npm --version     # Deve retornar v10.9.3+
php --version     # Deve retornar PHP 8.4.12+
composer --version # Deve retornar Composer 2.8.12+
mysql --version   # Deve retornar mysql Ver 8.0+
```

## 🛠️ Instalação Passo a Passo

### 1. Clone e Navegue para o Projeto
```bash
git clone <repository-url>
cd easyappointments
```

### 2. Instalar Dependências NPM
```bash
# Instalar dependências do projeto
npm install

# Verificar se não há vulnerabilidades
npm audit

# Corrigir vulnerabilidades se necessário
npm audit fix
```

### 3. Build dos Assets
```bash
# Executar build completo dos assets
npm run build

# Ou executar tarefas individuais
npx gulp clean      # Limpar arquivos temporários
npx gulp vendor     # Copiar dependências vendor
npx gulp scripts    # Minificar JavaScript
npx gulp styles     # Compilar SCSS para CSS
```

### 4. Configurar Banco de Dados MySQL

#### 4.1. Criar Banco de Dados
```sql
-- Conectar ao MySQL como root
mysql -u root -p

-- Criar banco de dados
CREATE DATABASE easyappointments CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Criar usuário (opcional)
CREATE USER 'easyappointments'@'localhost' IDENTIFIED BY 'senha_segura';
GRANT ALL PRIVILEGES ON easyappointments.* TO 'easyappointments'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

#### 4.2. Configurar Arquivo de Configuração
```bash
# Copiar arquivo de exemplo
cp config-sample.php config.php

# Editar configurações do banco
nano config.php
```

**Configurações importantes no `config.php`:**
```php
$config['base_url'] = 'http://localhost/easyappointments/';
$config['db_hostname'] = 'localhost';
$config['db_username'] = 'easyappointments';
$config['db_password'] = 'senha_segura';
$config['db_database'] = 'easyappointments';
```

### 5. Instalar Dependências PHP com Composer
```bash
# Instalar dependências PHP
composer install

# Para produção (sem dependências de desenvolvimento)
composer install --no-dev --optimize-autoloader
```

### 6. Configurar Servidor Web

#### Opção A: Apache
```apache
# /etc/apache2/sites-available/easyappointments.conf
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /path/to/easyappointments
    
    <Directory /path/to/easyappointments>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/easyappointments_error.log
    CustomLog ${APACHE_LOG_DIR}/easyappointments_access.log combined
</VirtualHost>
```

```bash
# Habilitar site e mod_rewrite
sudo a2ensite easyappointments
sudo a2enmod rewrite
sudo systemctl restart apache2
```

#### Opção B: Nginx
```nginx
# /etc/nginx/sites-available/easyappointments
server {
    listen 80;
    server_name localhost;
    root /path/to/easyappointments;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

```bash
# Habilitar site
sudo ln -s /etc/nginx/sites-available/easyappointments /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Configurar Permissões
```bash
# Definir permissões corretas
sudo chown -R www-data:www-data storage/
sudo chmod -R 755 storage/
sudo chmod -R 644 storage/sessions/* storage/cache/* storage/uploads/* 2>/dev/null || true
sudo chmod g+w storage/sessions storage/cache storage/uploads
```

## 🚀 Execução

### 1. Iniciar Serviços
```bash
# Iniciar MySQL
sudo systemctl start mysql

# Iniciar Apache/Nginx
sudo systemctl start apache2  # ou nginx
```

### 2. Acessar Instalação
1. Abra o navegador em: `http://localhost/easyappointments/`
2. Siga o assistente de instalação
3. Use as credenciais do banco configuradas no `config.php`

### 3. Configuração Inicial
- **Nome da Empresa**: Seu nome
- **Email**: admin@exemplo.com
- **Senha**: Senha segura
- **Timezone**: America/Sao_Paulo

## 🔧 Comandos Úteis

### Desenvolvimento
```bash
# Watch mode para desenvolvimento
npm start

# Build específico
npx gulp scripts    # Apenas JavaScript
npx gulp styles     # Apenas CSS
npx gulp clean      # Limpar arquivos

# Verificar vulnerabilidades
npm audit
npm audit fix
```

### Manutenção
```bash
# Atualizar dependências
npm update
composer update

# Limpar cache
npm cache clean --force
composer clear-cache

# Verificar logs
tail -f storage/logs/easyappointments.log
```

## 🐛 Solução de Problemas

### Problemas Comuns

#### 1. Erro de Permissão NPM
```bash
# Sintoma: EACCES: permission denied, mkdir 'node_modules/fsevents'
# Solução 1: Configurar prefix do npm
npm config set prefix ~/.npm-global

# Solução 2: Usar yarn como alternativa
yarn install

# Solução 3: Executar com sudo (não recomendado)
sudo npm install
```

#### 2. Erro de Permissão de Arquivos
```bash
# Sintoma: Permission denied em assets/
# Solução:
sudo chown -R $USER:$USER assets/
sudo chmod -R 755 assets/
sudo chmod -R 644 assets/js/* assets/css/*
```

#### 3. Erro de Permissão Storage
```bash
# Sintoma: Permission denied em storage/
# Solução:
sudo chown -R www-data:www-data storage/
sudo chmod -R 755 storage/
```

#### 4. Erro de Banco de Dados
```bash
# Sintoma: Database connection failed
# Solução: Verificar config.php e credenciais MySQL
mysql -u root -p -e "SHOW DATABASES;"
```

#### 5. Assets Não Carregam
```bash
# Sintoma: CSS/JS não carregam
# Solução: Rebuild dos assets
npm run build
```

#### 6. Mod_rewrite Não Funciona
```bash
# Apache: Habilitar mod_rewrite
sudo a2enmod rewrite
sudo systemctl restart apache2

# Nginx: Verificar configuração de try_files
```

### Logs Importantes
```bash
# Logs da aplicação
tail -f storage/logs/easyappointments.log

# Logs do servidor web
sudo tail -f /var/log/apache2/error.log
sudo tail -f /var/log/nginx/error.log

# Logs do MySQL
sudo tail -f /var/log/mysql/error.log
```

## 📁 Estrutura do Projeto

```
easyappointments/
├── assets/                 # Assets compilados
│   ├── css/               # CSS compilado
│   ├── js/                # JavaScript minificado
│   └── vendor/            # Dependências vendor
├── application/           # Código da aplicação
├── storage/               # Arquivos de sessão, cache, uploads
├── node_modules/          # Dependências NPM
├── package.json           # Configuração NPM
├── gulpfile.js           # Configuração Gulp
├── composer.json         # Configuração Composer
├── config.php            # Configuração da aplicação
└── index.php             # Ponto de entrada
```

## 🔄 Workflow de Desenvolvimento

### 1. Desenvolvimento Diário
```bash
# 1. Iniciar watch mode
npm start

# 2. Fazer alterações nos arquivos
# 3. Assets são compilados automaticamente
# 4. Testar no navegador
```

### 2. Deploy para Produção
```bash
# 1. Build otimizado
npm run build

# 2. Instalar dependências PHP sem dev
composer install --no-dev --optimize-autoloader

# 3. Configurar permissões
sudo chown -R www-data:www-data storage/
sudo chmod -R 755 storage/

# 4. Configurar servidor web
# 5. Testar aplicação
```

## 📚 Recursos Adicionais

### Documentação Oficial
- [Easy!Appointments Docs](https://easyappointments.org/docs/)
- [CodeIgniter 3.x User Guide](https://codeigniter.com/userguide3/)

### Ferramentas de Desenvolvimento
- **Gulp**: Build system para assets
- **Composer**: Gerenciador de dependências PHP
- **npm**: Gerenciador de dependências JavaScript

### Extensões Úteis
- **PHP Extensions**: mysqli, mbstring, curl, gd, zip
- **Apache Modules**: mod_rewrite, mod_ssl
- **Nginx Modules**: fastcgi, rewrite

---

## ✅ Checklist de Instalação

- [ ] Node.js e npm instalados
- [ ] PHP e Composer instalados
- [ ] MySQL configurado
- [ ] Servidor web configurado
- [ ] Dependências NPM instaladas (`npm install`)
- [ ] Assets compilados (`npm run build`)
- [ ] Dependências PHP instaladas (`composer install`)
- [ ] Banco de dados criado
- [ ] `config.php` configurado
- [ ] Permissões corretas
- [ ] Aplicação acessível via navegador
- [ ] Instalação concluída via interface web

---

**🎉 Parabéns! Seu ambiente Easy!Appointments está pronto para desenvolvimento!**
