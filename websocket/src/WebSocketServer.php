<?php
/**
 * Easy!Appointments WebSocket Server
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 */

namespace EasyAppointments\WebSocket;

use Ratchet\MessageComponentInterface;
use Ratchet\ConnectionInterface;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;
use SplObjectStorage;
use Exception;

/**
 * WebSocket Server implementation using Ratchet.
 *
 * Handles WebSocket connections, JWT authentication, room subscriptions,
 * and event broadcasting for real-time notifications.
 */
class WebSocketServer implements MessageComponentInterface
{
    /**
     * Connected clients storage.
     *
     * @var SplObjectStorage
     */
    protected SplObjectStorage $clients;

    /**
     * Room subscriptions.
     * Format: ['room_name' => [connection_id => ConnectionInterface, ...], ...]
     *
     * @var array
     */
    protected array $rooms = [];

    /**
     * Connection metadata.
     * Format: [resource_id => ['user_id' => int, 'role' => string, 'rooms' => array], ...]
     *
     * @var array
     */
    protected array $connectionMeta = [];

    /**
     * JWT secret key for authentication.
     *
     * @var string
     */
    protected string $jwtSecret;

    /**
     * JWT algorithm.
     *
     * @var string
     */
    protected string $jwtAlgorithm = 'HS256';

    /**
     * Message rate limit per minute.
     *
     * @var int
     */
    protected int $rateLimit = 50;

    /**
     * Rate limit tracking.
     *
     * @var array
     */
    protected array $rateLimitTracker = [];

    /**
     * Heartbeat timeout in seconds.
     *
     * @var int
     */
    protected int $heartbeatTimeout = 60;

    /**
     * Last activity timestamps.
     *
     * @var array
     */
    protected array $lastActivity = [];

    /**
     * Statistics counters.
     *
     * @var array
     */
    protected array $stats = [
        'total_connections' => 0,
        'total_messages' => 0,
        'total_broadcasts' => 0,
        'started_at' => null,
    ];

    /**
     * Constructor.
     *
     * @param string $jwtSecret JWT secret key for authentication.
     */
    public function __construct(string $jwtSecret = '')
    {
        $this->clients = new SplObjectStorage();
        $this->jwtSecret = $jwtSecret;
        $this->stats['started_at'] = date('c');

        echo "[INFO] WebSocket server initialized\n";
    }

    /**
     * Called when a new connection is opened.
     *
     * @param ConnectionInterface $conn The connection that just connected.
     */
    public function onOpen(ConnectionInterface $conn): void
    {
        $resourceId = $conn->resourceId;

        // Parse query string for JWT token
        $queryString = $conn->httpRequest->getUri()->getQuery();
        parse_str($queryString, $queryParams);

        $token = $queryParams['token'] ?? null;

        // Validate JWT token
        if (!empty($this->jwtSecret) && !$this->authenticateConnection($conn, $token)) {
            return;
        }

        // Add to clients
        $this->clients->attach($conn);
        $this->lastActivity[$resourceId] = time();
        $this->stats['total_connections']++;

        // Send welcome message
        $this->sendToConnection($conn, [
            'type' => 'connected',
            'message' => 'Welcome to Easy!Appointments WebSocket server',
            'connection_id' => $resourceId,
        ]);

        $userId = $this->connectionMeta[$resourceId]['user_id'] ?? 'anonymous';
        echo "[CONNECT] Client #{$resourceId} connected (user: {$userId})\n";
    }

    /**
     * Authenticate a connection using JWT token.
     *
     * @param ConnectionInterface $conn The connection.
     * @param string|null $token JWT token.
     *
     * @return bool True if authenticated, false otherwise.
     */
    protected function authenticateConnection(ConnectionInterface $conn, ?string $token): bool
    {
        $resourceId = $conn->resourceId;

        if (empty($token)) {
            $this->sendToConnection($conn, [
                'type' => 'error',
                'code' => 'AUTH_REQUIRED',
                'message' => 'Authentication token required',
            ]);
            $conn->close();
            return false;
        }

        try {
            $decoded = JWT::decode($token, new Key($this->jwtSecret, $this->jwtAlgorithm));

            // Store user metadata
            $this->connectionMeta[$resourceId] = [
                'user_id' => $decoded->data->user_id ?? null,
                'email' => $decoded->data->email ?? null,
                'role' => $decoded->data->role ?? null,
                'rooms' => [],
                'authenticated_at' => time(),
            ];

            // Auto-subscribe to user-specific room based on role
            $this->autoSubscribeUserRooms($conn, $decoded->data);

            return true;
        } catch (ExpiredException $e) {
            $this->sendToConnection($conn, [
                'type' => 'error',
                'code' => 'TOKEN_EXPIRED',
                'message' => 'Authentication token has expired',
            ]);
            $conn->close();
            return false;
        } catch (Exception $e) {
            $this->sendToConnection($conn, [
                'type' => 'error',
                'code' => 'AUTH_FAILED',
                'message' => 'Invalid authentication token',
            ]);
            $conn->close();
            return false;
        }
    }

    /**
     * Auto-subscribe user to their relevant rooms based on role.
     *
     * @param ConnectionInterface $conn The connection.
     * @param object $userData Decoded JWT user data.
     */
    protected function autoSubscribeUserRooms(ConnectionInterface $conn, object $userData): void
    {
        $userId = $userData->user_id ?? null;
        $role = $userData->role ?? null;

        if (!$userId || !$role) {
            return;
        }

        // Subscribe to user-specific room
        switch ($role) {
            case 'admin':
                $this->subscribeToRoom($conn, 'admin');
                $this->subscribeToRoom($conn, 'calendar');
                break;

            case 'provider':
                $this->subscribeToRoom($conn, "provider_{$userId}");
                $this->subscribeToRoom($conn, 'calendar');
                break;

            case 'secretary':
                $this->subscribeToRoom($conn, "secretary_{$userId}");
                $this->subscribeToRoom($conn, 'calendar');
                break;

            case 'customer':
                $this->subscribeToRoom($conn, "customer_{$userId}");
                break;
        }
    }

    /**
     * Called when a message is received from a client.
     *
     * @param ConnectionInterface $from The connection that sent the message.
     * @param string $msg The message content.
     */
    public function onMessage(ConnectionInterface $from, $msg): void
    {
        $resourceId = $from->resourceId;
        $this->lastActivity[$resourceId] = time();
        $this->stats['total_messages']++;

        // Rate limiting
        if (!$this->checkRateLimit($resourceId)) {
            $this->sendToConnection($from, [
                'type' => 'error',
                'code' => 'RATE_LIMITED',
                'message' => 'Too many messages. Please slow down.',
            ]);
            return;
        }

        // Parse message
        $data = json_decode($msg, true);

        if (!$data || !isset($data['action'])) {
            $this->sendToConnection($from, [
                'type' => 'error',
                'code' => 'INVALID_MESSAGE',
                'message' => 'Invalid message format. Expected JSON with "action" field.',
            ]);
            return;
        }

        // Handle action
        switch ($data['action']) {
            case 'ping':
                $this->handlePing($from);
                break;

            case 'subscribe':
                $this->handleSubscribe($from, $data['room'] ?? null);
                break;

            case 'unsubscribe':
                $this->handleUnsubscribe($from, $data['room'] ?? null);
                break;

            case 'list_rooms':
                $this->handleListRooms($from);
                break;

            default:
                $this->sendToConnection($from, [
                    'type' => 'error',
                    'code' => 'UNKNOWN_ACTION',
                    'message' => "Unknown action: {$data['action']}",
                ]);
        }
    }

    /**
     * Handle ping action (heartbeat).
     *
     * @param ConnectionInterface $conn The connection.
     */
    protected function handlePing(ConnectionInterface $conn): void
    {
        $this->sendToConnection($conn, [
            'type' => 'pong',
            'timestamp' => date('c'),
        ]);
    }

    /**
     * Handle subscribe action.
     *
     * @param ConnectionInterface $conn The connection.
     * @param string|null $room Room name.
     */
    protected function handleSubscribe(ConnectionInterface $conn, ?string $room): void
    {
        if (empty($room)) {
            $this->sendToConnection($conn, [
                'type' => 'error',
                'code' => 'INVALID_ROOM',
                'message' => 'Room name is required',
            ]);
            return;
        }

        // Validate room access based on user role
        if (!$this->canAccessRoom($conn, $room)) {
            $this->sendToConnection($conn, [
                'type' => 'error',
                'code' => 'ACCESS_DENIED',
                'message' => "You don't have access to room: {$room}",
            ]);
            return;
        }

        $this->subscribeToRoom($conn, $room);
    }

    /**
     * Handle unsubscribe action.
     *
     * @param ConnectionInterface $conn The connection.
     * @param string|null $room Room name.
     */
    protected function handleUnsubscribe(ConnectionInterface $conn, ?string $room): void
    {
        if (empty($room)) {
            $this->sendToConnection($conn, [
                'type' => 'error',
                'code' => 'INVALID_ROOM',
                'message' => 'Room name is required',
            ]);
            return;
        }

        $this->unsubscribeFromRoom($conn, $room);
    }

    /**
     * Handle list rooms action.
     *
     * @param ConnectionInterface $conn The connection.
     */
    protected function handleListRooms(ConnectionInterface $conn): void
    {
        $resourceId = $conn->resourceId;
        $rooms = $this->connectionMeta[$resourceId]['rooms'] ?? [];

        $this->sendToConnection($conn, [
            'type' => 'rooms_list',
            'rooms' => $rooms,
        ]);
    }

    /**
     * Check if a connection can access a room.
     *
     * @param ConnectionInterface $conn The connection.
     * @param string $room Room name.
     *
     * @return bool True if access is allowed.
     */
    protected function canAccessRoom(ConnectionInterface $conn, string $room): bool
    {
        $resourceId = $conn->resourceId;
        $meta = $this->connectionMeta[$resourceId] ?? [];
        $role = $meta['role'] ?? null;
        $userId = $meta['user_id'] ?? null;

        // Admins can access any room
        if ($role === 'admin') {
            return true;
        }

        // Check room-specific access
        if (preg_match('/^provider_(\d+)$/', $room, $matches)) {
            // Providers can only access their own room
            return $role === 'provider' && (int)$matches[1] === (int)$userId;
        }

        if (preg_match('/^customer_(\d+)$/', $room, $matches)) {
            // Customers can only access their own room
            return $role === 'customer' && (int)$matches[1] === (int)$userId;
        }

        if (preg_match('/^secretary_(\d+)$/', $room, $matches)) {
            // Secretaries can only access their own room
            return $role === 'secretary' && (int)$matches[1] === (int)$userId;
        }

        if ($room === 'calendar') {
            // Calendar room for providers, secretaries, and admins
            return in_array($role, ['provider', 'secretary', 'admin']);
        }

        if ($room === 'admin') {
            // Admin room only for admins
            return $role === 'admin';
        }

        // Unknown room - deny by default
        return false;
    }

    /**
     * Subscribe a connection to a room.
     *
     * @param ConnectionInterface $conn The connection.
     * @param string $room Room name.
     */
    protected function subscribeToRoom(ConnectionInterface $conn, string $room): void
    {
        $resourceId = $conn->resourceId;

        // Initialize room if not exists
        if (!isset($this->rooms[$room])) {
            $this->rooms[$room] = [];
        }

        // Add connection to room
        $this->rooms[$room][$resourceId] = $conn;

        // Track in connection metadata
        if (!isset($this->connectionMeta[$resourceId]['rooms'])) {
            $this->connectionMeta[$resourceId]['rooms'] = [];
        }

        if (!in_array($room, $this->connectionMeta[$resourceId]['rooms'])) {
            $this->connectionMeta[$resourceId]['rooms'][] = $room;
        }

        $this->sendToConnection($conn, [
            'type' => 'subscribed',
            'room' => $room,
        ]);

        echo "[SUBSCRIBE] Client #{$resourceId} subscribed to room: {$room}\n";
    }

    /**
     * Unsubscribe a connection from a room.
     *
     * @param ConnectionInterface $conn The connection.
     * @param string $room Room name.
     */
    protected function unsubscribeFromRoom(ConnectionInterface $conn, string $room): void
    {
        $resourceId = $conn->resourceId;

        // Remove from room
        if (isset($this->rooms[$room][$resourceId])) {
            unset($this->rooms[$room][$resourceId]);
        }

        // Remove from connection metadata
        if (isset($this->connectionMeta[$resourceId]['rooms'])) {
            $this->connectionMeta[$resourceId]['rooms'] = array_values(
                array_diff($this->connectionMeta[$resourceId]['rooms'], [$room])
            );
        }

        // Clean up empty rooms
        if (empty($this->rooms[$room])) {
            unset($this->rooms[$room]);
        }

        $this->sendToConnection($conn, [
            'type' => 'unsubscribed',
            'room' => $room,
        ]);

        echo "[UNSUBSCRIBE] Client #{$resourceId} unsubscribed from room: {$room}\n";
    }

    /**
     * Called when a connection is closed.
     *
     * @param ConnectionInterface $conn The connection that was closed.
     */
    public function onClose(ConnectionInterface $conn): void
    {
        $resourceId = $conn->resourceId;

        // Remove from all rooms
        foreach ($this->rooms as $room => $connections) {
            if (isset($connections[$resourceId])) {
                unset($this->rooms[$room][$resourceId]);

                if (empty($this->rooms[$room])) {
                    unset($this->rooms[$room]);
                }
            }
        }

        // Clean up metadata
        unset($this->connectionMeta[$resourceId]);
        unset($this->lastActivity[$resourceId]);
        unset($this->rateLimitTracker[$resourceId]);

        // Remove from clients
        $this->clients->detach($conn);

        echo "[DISCONNECT] Client #{$resourceId} disconnected\n";
    }

    /**
     * Called when an error occurs.
     *
     * @param ConnectionInterface $conn The connection where the error occurred.
     * @param Exception $e The exception.
     */
    public function onError(ConnectionInterface $conn, Exception $e): void
    {
        $resourceId = $conn->resourceId;
        echo "[ERROR] Client #{$resourceId}: {$e->getMessage()}\n";
        $conn->close();
    }

    /**
     * Check rate limit for a connection.
     *
     * @param int $resourceId Connection resource ID.
     *
     * @return bool True if within rate limit.
     */
    protected function checkRateLimit(int $resourceId): bool
    {
        $now = time();
        $minute = (int)($now / 60);

        if (!isset($this->rateLimitTracker[$resourceId])) {
            $this->rateLimitTracker[$resourceId] = ['minute' => $minute, 'count' => 0];
        }

        if ($this->rateLimitTracker[$resourceId]['minute'] !== $minute) {
            $this->rateLimitTracker[$resourceId] = ['minute' => $minute, 'count' => 0];
        }

        $this->rateLimitTracker[$resourceId]['count']++;

        return $this->rateLimitTracker[$resourceId]['count'] <= $this->rateLimit;
    }

    /**
     * Send a message to a specific connection.
     *
     * @param ConnectionInterface $conn The connection.
     * @param array $data Data to send.
     */
    protected function sendToConnection(ConnectionInterface $conn, array $data): void
    {
        $conn->send(json_encode($data));
    }

    /**
     * Broadcast an event to specific rooms.
     *
     * @param string $event Event name.
     * @param mixed $data Event data.
     * @param array $rooms Target rooms (empty = all clients).
     */
    public function broadcastEvent(string $event, $data, array $rooms = []): void
    {
        $this->stats['total_broadcasts']++;

        $message = json_encode([
            'event' => $event,
            'data' => $data,
            'timestamp' => date('c'),
        ]);

        $sentCount = 0;

        if (empty($rooms)) {
            // Broadcast to all clients
            foreach ($this->clients as $client) {
                $client->send($message);
                $sentCount++;
            }
        } else {
            // Broadcast to specific rooms
            $sentConnections = [];

            foreach ($rooms as $room) {
                if (!isset($this->rooms[$room])) {
                    continue;
                }

                foreach ($this->rooms[$room] as $resourceId => $conn) {
                    // Avoid sending duplicate messages to same connection
                    if (!isset($sentConnections[$resourceId])) {
                        $conn->send($message);
                        $sentConnections[$resourceId] = true;
                        $sentCount++;
                    }
                }
            }
        }

        $roomsStr = empty($rooms) ? 'all' : implode(', ', $rooms);
        echo "[BROADCAST] Event '{$event}' to rooms [{$roomsStr}] - sent to {$sentCount} clients\n";
    }

    /**
     * Broadcast to a specific user by ID.
     *
     * @param string $event Event name.
     * @param mixed $data Event data.
     * @param int $userId Target user ID.
     */
    public function broadcastToUser(string $event, $data, int $userId): void
    {
        $message = json_encode([
            'event' => $event,
            'data' => $data,
            'timestamp' => date('c'),
        ]);

        foreach ($this->connectionMeta as $resourceId => $meta) {
            if (($meta['user_id'] ?? null) === $userId) {
                if (isset($this->rooms)) {
                    foreach ($this->clients as $client) {
                        if ($client->resourceId === $resourceId) {
                            $client->send($message);
                            break;
                        }
                    }
                }
            }
        }
    }

    /**
     * Get server statistics.
     *
     * @return array Server statistics.
     */
    public function getStats(): array
    {
        return [
            'active_connections' => count($this->clients),
            'active_rooms' => count($this->rooms),
            'room_details' => array_map(fn($r) => count($r), $this->rooms),
            'total_connections' => $this->stats['total_connections'],
            'total_messages' => $this->stats['total_messages'],
            'total_broadcasts' => $this->stats['total_broadcasts'],
            'started_at' => $this->stats['started_at'],
            'uptime_seconds' => time() - strtotime($this->stats['started_at']),
        ];
    }
}
