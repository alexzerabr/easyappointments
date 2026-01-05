#!/usr/bin/env php
<?php
/**
 * Easy!Appointments WebSocket Server
 *
 * Entry point for the Ratchet WebSocket server.
 * Handles real-time notifications for appointments and calendar updates.
 *
 * Usage: php server.php [--port=8080] [--host=0.0.0.0]
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 */

require __DIR__ . '/vendor/autoload.php';

use EasyAppointments\WebSocket\WebSocketServer;
use Ratchet\Server\IoServer;
use Ratchet\Http\HttpServer;
use Ratchet\WebSocket\WsServer;
use React\EventLoop\Loop;
use React\Socket\SocketServer;

// Parse command line arguments
$options = getopt('', ['port::', 'host::', 'jwt-secret::']);

$port = $options['port'] ?? getenv('WEBSOCKET_PORT') ?: 8080;
$host = $options['host'] ?? getenv('WEBSOCKET_HOST') ?: '0.0.0.0';
$jwtSecret = $options['jwt-secret'] ?? getenv('JWT_SECRET') ?: '';

// Validate JWT secret
if (empty($jwtSecret)) {
    // Try to load from Easy!Appointments config if available
    $configPath = __DIR__ . '/../application/config/config.php';
    if (file_exists($configPath)) {
        // Load CodeIgniter config to get api_token for deriving JWT secret
        $config = [];
        @include $configPath;

        // Try to get api_token from database settings
        // For now, use a derived secret or require JWT_SECRET env var
        echo "[WARNING] JWT_SECRET environment variable not set. Using derived secret.\n";
        $jwtSecret = hash('sha256', 'easyappointments_jwt_default_secret_change_me');
    }
}

echo "============================================\n";
echo "  Easy!Appointments WebSocket Server\n";
echo "============================================\n";
echo "Host: {$host}\n";
echo "Port: {$port}\n";
echo "JWT Secret: " . (empty($jwtSecret) ? "[NOT SET - AUTH DISABLED]" : "[CONFIGURED]") . "\n";
echo "============================================\n";
echo "Starting server...\n\n";

// Create event loop
$loop = Loop::get();

// Create WebSocket server instance
$wsServer = new WebSocketServer($jwtSecret);

// Create the socket server
$socket = new SocketServer("{$host}:{$port}", [], $loop);

// Create HTTP server with WebSocket handler
$httpServer = new HttpServer(
    new WsServer($wsServer)
);

// Create IO server
$ioServer = new IoServer($httpServer, $socket, $loop);

// Setup internal HTTP endpoint for broadcasting from API
// This allows the PHP API to send events to the WebSocket server
$internalPort = (int)$port + 1;
$internalSocket = new SocketServer("127.0.0.1:{$internalPort}", [], $loop);

$internalSocket->on('connection', function ($conn) use ($wsServer) {
    $buffer = '';

    $conn->on('data', function ($data) use ($conn, $wsServer, &$buffer) {
        $buffer .= $data;

        // Check if we have a complete HTTP request
        if (strpos($buffer, "\r\n\r\n") === false) {
            return;
        }

        // Parse HTTP request
        $lines = explode("\r\n", $buffer);
        $firstLine = $lines[0];

        // Get body (JSON payload)
        $bodyStart = strpos($buffer, "\r\n\r\n") + 4;
        $body = substr($buffer, $bodyStart);

        if (preg_match('/POST \/broadcast HTTP/', $firstLine)) {
            $payload = json_decode($body, true);

            if ($payload && isset($payload['event']) && isset($payload['data'])) {
                $rooms = $payload['rooms'] ?? [];
                $wsServer->broadcastEvent($payload['event'], $payload['data'], $rooms);

                $response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" .
                           json_encode(['success' => true, 'message' => 'Event broadcast']);
            } else {
                $response = "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\n\r\n" .
                           json_encode(['success' => false, 'message' => 'Invalid payload']);
            }
        } elseif (preg_match('/GET \/health HTTP/', $firstLine)) {
            $stats = $wsServer->getStats();
            $response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" .
                       json_encode(['status' => 'healthy', 'stats' => $stats]);
        } else {
            $response = "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\n\r\n" .
                       json_encode(['error' => 'Not found']);
        }

        $conn->write($response);
        $conn->end();
        $buffer = '';
    });
});

echo "[OK] WebSocket server listening on ws://{$host}:{$port}\n";
echo "[OK] Internal broadcast endpoint on http://127.0.0.1:{$internalPort}/broadcast\n";
echo "[OK] Health check endpoint on http://127.0.0.1:{$internalPort}/health\n";
echo "\nPress Ctrl+C to stop the server.\n\n";

// Run the event loop
$loop->run();
