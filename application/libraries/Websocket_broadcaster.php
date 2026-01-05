<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * WebSocket Broadcaster library.
 *
 * Handles broadcasting events to the WebSocket server for real-time notifications.
 *
 * @package Libraries
 */
class Websocket_broadcaster
{
    /**
     * @var EA_Controller|CI_Controller
     */
    protected EA_Controller|CI_Controller $CI;

    /**
     * WebSocket server internal endpoint.
     *
     * @var string
     */
    protected string $websocket_url;

    /**
     * Whether WebSocket broadcasting is enabled.
     *
     * @var bool
     */
    protected bool $enabled;

    /**
     * Connection timeout in seconds.
     *
     * @var int
     */
    protected int $timeout = 5;

    /**
     * Websocket_broadcaster constructor.
     */
    public function __construct()
    {
        $this->CI = &get_instance();

        // Get WebSocket configuration from environment or config
        $websocket_host = getenv('WEBSOCKET_INTERNAL_HOST') ?: 'easyappointments-dev-websocket';
        $websocket_port = (int)(getenv('WEBSOCKET_INTERNAL_PORT') ?: 8081); // Internal broadcast port

        $this->websocket_url = "http://{$websocket_host}:{$websocket_port}/broadcast";

        // Check if WebSocket is enabled
        $this->enabled = (bool)(getenv('WEBSOCKET_ENABLED') ?: true);
    }

    /**
     * Broadcast an event to specified rooms.
     *
     * @param string $event Event name (e.g., 'appointment_created').
     * @param mixed $data Event payload data.
     * @param array $rooms Target rooms to broadcast to.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function broadcast(string $event, $data, array $rooms = []): bool
    {
        if (!$this->enabled) {
            return false;
        }

        $payload = [
            'event' => $event,
            'data' => $data,
            'rooms' => $rooms,
        ];

        return $this->send_to_websocket($payload);
    }

    /**
     * Broadcast an event to a specific user.
     *
     * @param string $event Event name.
     * @param mixed $data Event payload data.
     * @param int $user_id Target user ID.
     * @param string|null $role User role for room targeting.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function broadcast_to_user(string $event, $data, int $user_id, ?string $role = null): bool
    {
        $rooms = [];

        // Determine room based on role
        if ($role) {
            switch ($role) {
                case DB_SLUG_ADMIN:
                    $rooms[] = 'admin';
                    break;
                case DB_SLUG_PROVIDER:
                    $rooms[] = "provider_{$user_id}";
                    break;
                case DB_SLUG_SECRETARY:
                    $rooms[] = "secretary_{$user_id}";
                    break;
                case DB_SLUG_CUSTOMER:
                    $rooms[] = "customer_{$user_id}";
                    break;
            }
        }

        return $this->broadcast($event, $data, $rooms);
    }

    /**
     * Broadcast appointment created event.
     *
     * @param array $appointment Appointment data.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function appointment_created(array $appointment): bool
    {
        $rooms = $this->get_appointment_rooms($appointment);

        return $this->broadcast('appointment_created', $appointment, $rooms);
    }

    /**
     * Broadcast appointment updated event.
     *
     * @param array $appointment Appointment data.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function appointment_updated(array $appointment): bool
    {
        $rooms = $this->get_appointment_rooms($appointment);

        return $this->broadcast('appointment_updated', $appointment, $rooms);
    }

    /**
     * Broadcast appointment deleted event.
     *
     * @param array $appointment Appointment data.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function appointment_deleted(array $appointment): bool
    {
        $rooms = $this->get_appointment_rooms($appointment);

        return $this->broadcast('appointment_deleted', $appointment, $rooms);
    }

    /**
     * Broadcast provider availability changed event.
     *
     * @param int $provider_id Provider ID.
     * @param array $availability Availability data.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function provider_availability_changed(int $provider_id, array $availability): bool
    {
        $rooms = [
            "provider_{$provider_id}",
            'calendar',
            'admin',
        ];

        return $this->broadcast('provider_availability_changed', [
            'provider_id' => $provider_id,
            'availability' => $availability,
        ], $rooms);
    }

    /**
     * Broadcast unavailability created event.
     *
     * @param array $unavailability Unavailability data.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function unavailability_created(array $unavailability): bool
    {
        $provider_id = $unavailability['id_users_provider'] ?? null;

        $rooms = ['calendar', 'admin'];

        if ($provider_id) {
            $rooms[] = "provider_{$provider_id}";
        }

        return $this->broadcast('unavailability_created', $unavailability, $rooms);
    }

    /**
     * Broadcast unavailability deleted event.
     *
     * @param array $unavailability Unavailability data.
     *
     * @return bool Returns true if broadcast was successful.
     */
    public function unavailability_deleted(array $unavailability): bool
    {
        $provider_id = $unavailability['id_users_provider'] ?? null;

        $rooms = ['calendar', 'admin'];

        if ($provider_id) {
            $rooms[] = "provider_{$provider_id}";
        }

        return $this->broadcast('unavailability_deleted', $unavailability, $rooms);
    }

    /**
     * Get rooms for an appointment event.
     *
     * @param array $appointment Appointment data.
     *
     * @return array Room names.
     */
    protected function get_appointment_rooms(array $appointment): array
    {
        $rooms = ['calendar', 'admin'];

        // Add provider room
        if (!empty($appointment['id_users_provider'])) {
            $rooms[] = "provider_{$appointment['id_users_provider']}";
        }

        // Add customer room
        if (!empty($appointment['id_users_customer'])) {
            $rooms[] = "customer_{$appointment['id_users_customer']}";
        }

        return $rooms;
    }

    /**
     * Send payload to WebSocket server.
     *
     * @param array $payload Payload data.
     *
     * @return bool Returns true if successful.
     */
    protected function send_to_websocket(array $payload): bool
    {
        try {
            $json = json_encode($payload);

            $context = stream_context_create([
                'http' => [
                    'method' => 'POST',
                    'header' => "Content-Type: application/json\r\n" .
                               "Content-Length: " . strlen($json) . "\r\n",
                    'content' => $json,
                    'timeout' => $this->timeout,
                    'ignore_errors' => true,
                ],
            ]);

            $result = @file_get_contents($this->websocket_url, false, $context);

            if ($result === false) {
                // WebSocket server might not be running - log but don't fail
                log_message('debug', 'WebSocket broadcast failed: Could not connect to server');
                return false;
            }

            $response = json_decode($result, true);

            return ($response['success'] ?? false) === true;
        } catch (Throwable $e) {
            log_message('error', 'WebSocket broadcast error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Check if WebSocket server is healthy.
     *
     * @return array|null Health status or null if unavailable.
     */
    public function health_check(): ?array
    {
        try {
            $health_url = str_replace('/broadcast', '/health', $this->websocket_url);

            $context = stream_context_create([
                'http' => [
                    'method' => 'GET',
                    'timeout' => $this->timeout,
                    'ignore_errors' => true,
                ],
            ]);

            $result = @file_get_contents($health_url, false, $context);

            if ($result === false) {
                return null;
            }

            return json_decode($result, true);
        } catch (Throwable $e) {
            return null;
        }
    }

    /**
     * Enable or disable WebSocket broadcasting.
     *
     * @param bool $enabled Whether to enable broadcasting.
     */
    public function set_enabled(bool $enabled): void
    {
        $this->enabled = $enabled;
    }

    /**
     * Check if WebSocket broadcasting is enabled.
     *
     * @return bool
     */
    public function is_enabled(): bool
    {
        return $this->enabled;
    }
}
