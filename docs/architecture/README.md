# Arquitetura do Projeto - Modernização Easy!Appointments

## Visão Geral

Este documento descreve a arquitetura da modernização do Easy!Appointments, incluindo melhorias no backend e desenvolvimento do aplicativo móvel.

## Diagrama de Alto Nível

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENTES                                     │
├─────────────────┬─────────────────┬─────────────────────────────────┤
│   Web App       │   Mobile App    │   Integrações Externas          │
│   (Existente)   │   (Flutter)     │   (Webhooks)                    │
└────────┬────────┴────────┬────────┴─────────────┬───────────────────┘
         │                 │                       │
         │    HTTPS/WSS    │                       │
         ▼                 ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         NGINX (Proxy Reverso)                        │
│   - SSL Termination                                                  │
│   - Load Balancing                                                   │
│   - Static Files                                                     │
└────────┬────────────────────────────────────────┬───────────────────┘
         │                                         │
         ▼                                         ▼
┌─────────────────────────┐       ┌─────────────────────────────────┐
│     PHP-FPM             │       │     WebSocket Server            │
│     (CodeIgniter 3)     │       │     (Ratchet)                   │
│                         │       │                                 │
│  ┌──────────────────┐   │       │  ┌────────────────────────┐    │
│  │   API REST v1    │   │       │  │   Real-time Events     │    │
│  │   + JWT Auth     │   │       │  │   - appointment_create │    │
│  │   + Swagger      │   │       │  │   - appointment_update │    │
│  └──────────────────┘   │       │  │   - appointment_delete │    │
│                         │       │  └────────────────────────┘    │
│  ┌──────────────────┐   │       │                                 │
│  │   Controllers    │   │       └─────────────┬───────────────────┘
│  │   Models         │   │                     │
│  │   Libraries      │   │                     │
│  └──────────────────┘   │                     │
└────────┬────────────────┘                     │
         │                                       │
         ▼                                       │
┌─────────────────────────┐                     │
│     MySQL 8.x           │◄────────────────────┘
│                         │
│  - Appointments         │
│  - Users                │
│  - Services             │
│  - Refresh Tokens       │
│  - Push Subscriptions   │
└─────────────────────────┘
```

## Componentes

### 1. Backend (PHP/CodeIgniter 3)

#### API REST v1
- **Localização:** `application/controllers/api/v1/`
- **Autenticação:** JWT + Basic Auth (backward compatible)
- **Documentação:** OpenAPI 3.0 (Swagger)

#### Novos Endpoints
```
POST   /api/v1/auth/login      # Login e geração de tokens
POST   /api/v1/auth/refresh    # Renovação de access token
POST   /api/v1/auth/logout     # Revogação de tokens
GET    /api/v1/docs            # Swagger UI
POST   /api/v1/push/subscribe  # Inscrição push notifications
```

### 2. WebSocket Server

- **Tecnologia:** Ratchet (PHP)
- **Porta:** 8080
- **Eventos:**
  - `appointment_created`
  - `appointment_updated`
  - `appointment_deleted`
  - `provider_status_changed`

### 3. Mobile App (Flutter)

#### Arquitetura: Clean Architecture
```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  ┌─────────────────────────────────┐   │
│  │  Pages │ Widgets │ BLoC/Cubit   │   │
│  └─────────────────────────────────┘   │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│             Domain Layer                │
│  ┌─────────────────────────────────┐   │
│  │ Entities │ Use Cases │ Repos*   │   │
│  └─────────────────────────────────┘   │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│              Data Layer                 │
│  ┌─────────────────────────────────┐   │
│  │ Models │ Repos Impl │ Sources   │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘

* Repos = Repository Interfaces
```

## Fluxo de Autenticação

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Mobile  │     │   API    │     │   MySQL  │
│   App    │     │  Server  │     │    DB    │
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                 │
     │ POST /auth/login               │
     │ {username, password}            │
     │───────────────►│                 │
     │                │  Verify creds   │
     │                │────────────────►│
     │                │◄────────────────│
     │                │                 │
     │                │ Generate JWT    │
     │                │ Store refresh   │
     │                │────────────────►│
     │                │                 │
     │ {access_token, │                 │
     │  refresh_token}│                 │
     │◄───────────────│                 │
     │                │                 │
     │ GET /appointments               │
     │ Authorization: Bearer <token>   │
     │───────────────►│                 │
     │                │ Validate JWT    │
     │                │ Fetch data      │
     │                │────────────────►│
     │                │◄────────────────│
     │ [appointments] │                 │
     │◄───────────────│                 │
     │                │                 │
     │ POST /auth/refresh              │
     │ {refresh_token}│                 │
     │───────────────►│                 │
     │                │ Validate token  │
     │                │────────────────►│
     │                │◄────────────────│
     │ {new_access_token}              │
     │◄───────────────│                 │
```

## Fluxo Real-time (WebSocket)

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Mobile  │     │    WS    │     │   API    │
│   App    │     │  Server  │     │  Server  │
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                 │
     │ WS Connect     │                 │
     │───────────────►│                 │
     │                │                 │
     │ Subscribe      │                 │
     │ {room: "prov_1"}                │
     │───────────────►│                 │
     │                │                 │
     │                │                 │ User creates
     │                │                 │ appointment
     │                │◄────────────────│
     │                │ Publish event   │
     │ Event:         │                 │
     │ appointment_created             │
     │◄───────────────│                 │
     │                │                 │
     │ Update UI      │                 │
```

## Segurança

### JWT Tokens
- **Access Token:** 15 minutos de validade
- **Refresh Token:** 7 dias de validade
- **Algoritmo:** HS256
- **Storage:** Secure Storage (mobile) / HttpOnly Cookie (web)

### Rate Limiting
- API: 100 requests/2min por IP
- Auth endpoints: 10 requests/min por IP
- WebSocket: 50 messages/min por conexão

### Headers de Segurança
```
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'self'
```

## Banco de Dados - Novas Tabelas

### refresh_tokens
```sql
CREATE TABLE refresh_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_users INT NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at DATETIME NOT NULL,
    device_info TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_users) REFERENCES users(id) ON DELETE CASCADE
);
```

### push_subscriptions
```sql
CREATE TABLE push_subscriptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_users INT NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh VARCHAR(255),
    auth VARCHAR(255),
    platform ENUM('web', 'android', 'ios') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_users) REFERENCES users(id) ON DELETE CASCADE
);
```

## Environments

| Ambiente | URL | Descrição |
|----------|-----|-----------|
| Development | http://localhost:8000 | Desenvolvimento local |
| Staging | https://staging.example.com | Testes pré-produção |
| Production | https://app.example.com | Ambiente produtivo |

## Monitoramento

- **Logs:** Monolog (PHP) + storage/logs/
- **Métricas:** Configurável via Matomo/Google Analytics
- **Erros:** Tratamento centralizado com logging
