/**
 * Easy!Appointments WebSocket Client
 *
 * Provides real-time communication with the WebSocket server for
 * instant updates on appointments and calendar changes.
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 */

/**
 * WebSocket Client class for Easy!Appointments.
 */
class EAWebSocketClient {
    /**
     * Create a new WebSocket client instance.
     *
     * @param {Object} options Configuration options.
     * @param {string} options.url WebSocket server URL.
     * @param {string} options.token JWT authentication token.
     * @param {boolean} options.autoReconnect Enable auto-reconnect (default: true).
     * @param {number} options.reconnectInterval Reconnect interval in ms (default: 3000).
     * @param {number} options.maxReconnectAttempts Max reconnect attempts (default: 10).
     * @param {number} options.heartbeatInterval Heartbeat interval in ms (default: 30000).
     */
    constructor(options = {}) {
        this.url = options.url || this._getDefaultUrl();
        this.token = options.token || null;
        this.autoReconnect = options.autoReconnect !== false;
        this.reconnectInterval = options.reconnectInterval || 3000;
        this.maxReconnectAttempts = options.maxReconnectAttempts || 10;
        this.heartbeatInterval = options.heartbeatInterval || 30000;

        this.socket = null;
        this.connectionId = null;
        this.reconnectAttempts = 0;
        this.reconnectTimeout = null;
        this.heartbeatTimer = null;
        this.subscribedRooms = new Set();

        // Event handlers
        this.eventHandlers = {
            'connect': [],
            'disconnect': [],
            'error': [],
            'message': [],
            // Appointment events
            'appointment_created': [],
            'appointment_updated': [],
            'appointment_deleted': [],
            // Availability events
            'provider_availability_changed': [],
            'unavailability_created': [],
            'unavailability_deleted': [],
            // Room events
            'subscribed': [],
            'unsubscribed': [],
        };

        // Bind methods
        this._onOpen = this._onOpen.bind(this);
        this._onMessage = this._onMessage.bind(this);
        this._onClose = this._onClose.bind(this);
        this._onError = this._onError.bind(this);
    }

    /**
     * Get default WebSocket URL based on current location.
     *
     * @returns {string} WebSocket URL.
     * @private
     */
    _getDefaultUrl() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const host = window.location.host;
        return `${protocol}//${host}/ws`;
    }

    /**
     * Connect to the WebSocket server.
     *
     * @param {string} token Optional JWT token (overrides constructor token).
     * @returns {Promise<void>} Resolves when connected.
     */
    connect(token = null) {
        return new Promise((resolve, reject) => {
            if (token) {
                this.token = token;
            }

            if (!this.token) {
                reject(new Error('JWT token is required'));
                return;
            }

            if (this.socket && this.socket.readyState === WebSocket.OPEN) {
                resolve();
                return;
            }

            // Clear any existing reconnect timeout
            if (this.reconnectTimeout) {
                clearTimeout(this.reconnectTimeout);
                this.reconnectTimeout = null;
            }

            const url = `${this.url}?token=${encodeURIComponent(this.token)}`;

            try {
                this.socket = new WebSocket(url);

                const onOpenOnce = () => {
                    this.socket.removeEventListener('open', onOpenOnce);
                    this.socket.removeEventListener('error', onErrorOnce);
                    resolve();
                };

                const onErrorOnce = (error) => {
                    this.socket.removeEventListener('open', onOpenOnce);
                    this.socket.removeEventListener('error', onErrorOnce);
                    reject(error);
                };

                this.socket.addEventListener('open', onOpenOnce);
                this.socket.addEventListener('error', onErrorOnce);

                this.socket.addEventListener('open', this._onOpen);
                this.socket.addEventListener('message', this._onMessage);
                this.socket.addEventListener('close', this._onClose);
                this.socket.addEventListener('error', this._onError);
            } catch (error) {
                reject(error);
            }
        });
    }

    /**
     * Disconnect from the WebSocket server.
     */
    disconnect() {
        this.autoReconnect = false;

        if (this.reconnectTimeout) {
            clearTimeout(this.reconnectTimeout);
            this.reconnectTimeout = null;
        }

        if (this.heartbeatTimer) {
            clearInterval(this.heartbeatTimer);
            this.heartbeatTimer = null;
        }

        if (this.socket) {
            this.socket.close(1000, 'Client disconnect');
            this.socket = null;
        }

        this.subscribedRooms.clear();
        this.connectionId = null;
    }

    /**
     * Subscribe to a room.
     *
     * @param {string} room Room name to subscribe to.
     */
    subscribe(room) {
        if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
            console.warn('WebSocket not connected. Cannot subscribe to room:', room);
            return;
        }

        this._send({
            action: 'subscribe',
            room: room,
        });
    }

    /**
     * Unsubscribe from a room.
     *
     * @param {string} room Room name to unsubscribe from.
     */
    unsubscribe(room) {
        if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
            return;
        }

        this._send({
            action: 'unsubscribe',
            room: room,
        });

        this.subscribedRooms.delete(room);
    }

    /**
     * Get list of subscribed rooms.
     *
     * @returns {Array<string>} List of room names.
     */
    getSubscribedRooms() {
        return Array.from(this.subscribedRooms);
    }

    /**
     * Check if connected.
     *
     * @returns {boolean} True if connected.
     */
    isConnected() {
        return this.socket && this.socket.readyState === WebSocket.OPEN;
    }

    /**
     * Register an event handler.
     *
     * @param {string} event Event name.
     * @param {Function} handler Event handler function.
     * @returns {EAWebSocketClient} This instance for chaining.
     */
    on(event, handler) {
        if (!this.eventHandlers[event]) {
            this.eventHandlers[event] = [];
        }

        this.eventHandlers[event].push(handler);
        return this;
    }

    /**
     * Remove an event handler.
     *
     * @param {string} event Event name.
     * @param {Function} handler Handler to remove.
     * @returns {EAWebSocketClient} This instance for chaining.
     */
    off(event, handler) {
        if (this.eventHandlers[event]) {
            this.eventHandlers[event] = this.eventHandlers[event].filter(h => h !== handler);
        }
        return this;
    }

    /**
     * Emit an event to registered handlers.
     *
     * @param {string} event Event name.
     * @param {*} data Event data.
     * @private
     */
    _emit(event, data) {
        const handlers = this.eventHandlers[event] || [];

        handlers.forEach(handler => {
            try {
                handler(data);
            } catch (error) {
                console.error('WebSocket event handler error:', error);
            }
        });

        // Also emit to generic 'message' handlers for any server event
        if (event !== 'message' && event !== 'connect' && event !== 'disconnect' && event !== 'error') {
            this._emit('message', { event, data });
        }
    }

    /**
     * Send data to the server.
     *
     * @param {Object} data Data to send.
     * @private
     */
    _send(data) {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
            this.socket.send(JSON.stringify(data));
        }
    }

    /**
     * Handle WebSocket open event.
     *
     * @param {Event} event Open event.
     * @private
     */
    _onOpen(event) {
        console.log('WebSocket connected');
        this.reconnectAttempts = 0;
        this._startHeartbeat();
        this._emit('connect', { event });
    }

    /**
     * Handle WebSocket message event.
     *
     * @param {MessageEvent} event Message event.
     * @private
     */
    _onMessage(event) {
        try {
            const message = JSON.parse(event.data);

            // Handle system messages
            switch (message.type) {
                case 'connected':
                    this.connectionId = message.connection_id;
                    console.log('WebSocket connection established, ID:', this.connectionId);
                    break;

                case 'pong':
                    // Heartbeat response received
                    break;

                case 'subscribed':
                    this.subscribedRooms.add(message.room);
                    this._emit('subscribed', { room: message.room });
                    break;

                case 'unsubscribed':
                    this.subscribedRooms.delete(message.room);
                    this._emit('unsubscribed', { room: message.room });
                    break;

                case 'error':
                    console.error('WebSocket error:', message.message);
                    this._emit('error', { code: message.code, message: message.message });
                    break;

                case 'rooms_list':
                    this.subscribedRooms = new Set(message.rooms);
                    break;

                default:
                    // Handle broadcast events
                    if (message.event) {
                        this._emit(message.event, message.data);
                    }
            }
        } catch (error) {
            console.error('WebSocket message parse error:', error);
        }
    }

    /**
     * Handle WebSocket close event.
     *
     * @param {CloseEvent} event Close event.
     * @private
     */
    _onClose(event) {
        console.log('WebSocket disconnected. Code:', event.code, 'Reason:', event.reason);

        this._stopHeartbeat();
        this.connectionId = null;

        this._emit('disconnect', {
            code: event.code,
            reason: event.reason,
            wasClean: event.wasClean,
        });

        // Auto-reconnect if enabled and not a clean close
        if (this.autoReconnect && event.code !== 1000) {
            this._scheduleReconnect();
        }
    }

    /**
     * Handle WebSocket error event.
     *
     * @param {Event} event Error event.
     * @private
     */
    _onError(event) {
        console.error('WebSocket error:', event);
        this._emit('error', { event });
    }

    /**
     * Schedule a reconnection attempt.
     *
     * @private
     */
    _scheduleReconnect() {
        if (this.reconnectAttempts >= this.maxReconnectAttempts) {
            console.error('WebSocket max reconnect attempts reached');
            this._emit('error', { message: 'Max reconnect attempts reached' });
            return;
        }

        this.reconnectAttempts++;
        const delay = this.reconnectInterval * Math.min(this.reconnectAttempts, 5);

        console.log(`WebSocket reconnecting in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

        this.reconnectTimeout = setTimeout(() => {
            this.connect().catch(error => {
                console.error('WebSocket reconnect failed:', error);
            });
        }, delay);
    }

    /**
     * Start heartbeat timer.
     *
     * @private
     */
    _startHeartbeat() {
        this._stopHeartbeat();

        this.heartbeatTimer = setInterval(() => {
            if (this.socket && this.socket.readyState === WebSocket.OPEN) {
                this._send({ action: 'ping' });
            }
        }, this.heartbeatInterval);
    }

    /**
     * Stop heartbeat timer.
     *
     * @private
     */
    _stopHeartbeat() {
        if (this.heartbeatTimer) {
            clearInterval(this.heartbeatTimer);
            this.heartbeatTimer = null;
        }
    }

    /**
     * Update the JWT token and reconnect if needed.
     *
     * @param {string} token New JWT token.
     * @returns {Promise<void>} Resolves when reconnected.
     */
    async updateToken(token) {
        this.token = token;

        if (this.isConnected()) {
            this.disconnect();
            await this.connect(token);

            // Re-subscribe to previous rooms
            for (const room of this.subscribedRooms) {
                this.subscribe(room);
            }
        }
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = EAWebSocketClient;
}

// Attach to window for direct script usage
if (typeof window !== 'undefined') {
    window.EAWebSocketClient = EAWebSocketClient;
}
