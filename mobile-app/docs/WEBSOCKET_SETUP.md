# WebSocket Configuration for Mobile App

This document describes how to configure the WebSocket server for real-time notifications in the Easy!Appointments mobile app.

## Overview

The WebSocket server enables real-time communication between the Easy!Appointments backend and the mobile app, providing:
- Instant appointment notifications
- Calendar updates in real-time
- Push notifications for new bookings

## Server Requirements

### 1. Environment Variables

Add the following variables to your `.env-prod` file:

```bash
# WebSocket port (default: 8080)
WEBSOCKET_PORT=8080

# JWT secret for WebSocket authentication (REQUIRED)
# Generate with: openssl rand -hex 32
JWT_SECRET=your_64_character_hex_secret_here
```

### 2. Docker Compose

The WebSocket service is included in `docker-compose.yml`. Ensure it's running:

```bash
docker compose ps websocket
```

### 3. Firewall Configuration

If using a firewall, open the WebSocket port:

```bash
# UFW
sudo ufw allow 8080/tcp

# iptables
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

### 4. Reverse Proxy (Optional but Recommended)

For production, configure Nginx to proxy WebSocket connections:

```nginx
# Add to your server block
location /ws {
    proxy_pass http://websocket:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 86400;
}
```

## Mobile App Configuration

### Server Setup

When first launching the app, users are prompted to enter the server URL. The WebSocket URL is automatically derived:

| Server URL | WebSocket URL |
|------------|--------------|
| `http://example.com` | `ws://example.com/ws` |
| `https://example.com` | `wss://example.com/ws` |

### Manual Configuration

Users can also manually set the WebSocket URL in Settings if needed.

## JWT Authentication

The WebSocket server uses JWT tokens for authentication. The same JWT secret must be:

1. Configured in the backend API (`JWT_SECRET` environment variable)
2. Configured in the WebSocket server (same `JWT_SECRET`)

### Token Flow

1. Mobile app authenticates via REST API
2. API returns JWT access token
3. App connects to WebSocket with token
4. WebSocket validates token using shared secret

## Room Subscriptions

Users are automatically subscribed to rooms based on their role:

| Role | Rooms |
|------|-------|
| Admin | `admin`, `calendar` |
| Provider | `provider_{id}`, `calendar` |
| Secretary | `secretary_{id}`, `calendar` |
| Customer | `customer_{id}` |

## Events

The WebSocket broadcasts the following events:

| Event | Description |
|-------|-------------|
| `appointment.created` | New appointment created |
| `appointment.updated` | Appointment modified |
| `appointment.cancelled` | Appointment cancelled |
| `calendar.sync` | Calendar sync required |

## Troubleshooting

### Connection Issues

1. **Check WebSocket service is running:**
   ```bash
   docker compose logs websocket
   ```

2. **Verify port is accessible:**
   ```bash
   curl -v http://localhost:8080
   ```

3. **Check health endpoint:**
   ```bash
   curl http://localhost:8081/health
   ```

### Authentication Errors

- Ensure `JWT_SECRET` matches between API and WebSocket
- Verify token is not expired
- Check token format is correct

### Mobile App Not Receiving Events

1. Check WebSocket connection state in app logs
2. Verify user is subscribed to correct rooms
3. Check server broadcast logs

## Health Monitoring

The WebSocket server exposes a health endpoint:

```bash
curl http://localhost:8081/health
```

Response:
```json
{
  "status": "healthy",
  "stats": {
    "active_connections": 5,
    "active_rooms": 3,
    "total_connections": 150,
    "total_messages": 1200,
    "uptime_seconds": 86400
  }
}
```
