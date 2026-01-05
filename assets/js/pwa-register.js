/**
 * Easy!Appointments PWA Registration
 *
 * Handles service worker registration, update notifications,
 * and push notification subscriptions.
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 */

(function() {
    'use strict';

    const PWA = {
        /**
         * Service worker registration
         */
        registration: null,

        /**
         * Push subscription
         */
        pushSubscription: null,

        /**
         * VAPID public key (should be set from server config)
         */
        vapidPublicKey: null,

        /**
         * Initialize PWA features
         */
        init: function() {
            if (!('serviceWorker' in navigator)) {
                console.log('[PWA] Service Worker not supported');
                return;
            }

            this.registerServiceWorker();
            this.setupInstallPrompt();
            this.setupOnlineOfflineEvents();
        },

        /**
         * Register the service worker
         */
        registerServiceWorker: async function() {
            try {
                this.registration = await navigator.serviceWorker.register('/sw.js', {
                    scope: '/'
                });

                console.log('[PWA] Service Worker registered:', this.registration.scope);

                // Check for updates
                this.registration.addEventListener('updatefound', () => {
                    this.onUpdateFound();
                });

                // Handle controller change (new SW activated)
                navigator.serviceWorker.addEventListener('controllerchange', () => {
                    console.log('[PWA] New service worker activated');
                });

                // Check if there's an update waiting
                if (this.registration.waiting) {
                    this.showUpdateNotification();
                }

            } catch (error) {
                console.error('[PWA] Service Worker registration failed:', error);
            }
        },

        /**
         * Handle service worker update found
         */
        onUpdateFound: function() {
            const newWorker = this.registration.installing;

            newWorker.addEventListener('statechange', () => {
                if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                    // New SW installed but waiting
                    this.showUpdateNotification();
                }
            });
        },

        /**
         * Show update notification to user
         */
        showUpdateNotification: function() {
            // Create update notification element
            const notification = document.createElement('div');
            notification.id = 'pwa-update-notification';
            notification.innerHTML = `
                <div class="pwa-update-content">
                    <span>A new version is available!</span>
                    <button id="pwa-update-btn">Update Now</button>
                    <button id="pwa-dismiss-btn">Later</button>
                </div>
            `;
            notification.style.cssText = `
                position: fixed;
                bottom: 20px;
                left: 50%;
                transform: translateX(-50%);
                background: #333;
                color: white;
                padding: 16px 24px;
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3);
                z-index: 10000;
                display: flex;
                align-items: center;
                gap: 16px;
            `;

            document.body.appendChild(notification);

            // Handle update button
            document.getElementById('pwa-update-btn').addEventListener('click', () => {
                this.applyUpdate();
                notification.remove();
            });

            // Handle dismiss button
            document.getElementById('pwa-dismiss-btn').addEventListener('click', () => {
                notification.remove();
            });
        },

        /**
         * Apply pending update
         */
        applyUpdate: function() {
            if (this.registration && this.registration.waiting) {
                // Tell the waiting SW to activate
                this.registration.waiting.postMessage({ type: 'SKIP_WAITING' });
                // Reload the page
                window.location.reload();
            }
        },

        /**
         * Setup install prompt (Add to Home Screen)
         */
        setupInstallPrompt: function() {
            let deferredPrompt;

            window.addEventListener('beforeinstallprompt', (e) => {
                // Prevent Chrome 67+ from automatically showing the prompt
                e.preventDefault();
                deferredPrompt = e;

                // Show install button
                this.showInstallButton(deferredPrompt);
            });

            // Listen for successful installation
            window.addEventListener('appinstalled', () => {
                console.log('[PWA] App installed');
                deferredPrompt = null;
                this.hideInstallButton();
            });
        },

        /**
         * Show install button
         */
        showInstallButton: function(deferredPrompt) {
            // Check if install button container exists
            let container = document.getElementById('pwa-install-container');

            if (!container) {
                container = document.createElement('div');
                container.id = 'pwa-install-container';
                container.innerHTML = `
                    <button id="pwa-install-btn" title="Install App">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
                            <polyline points="7 10 12 15 17 10"/>
                            <line x1="12" y1="15" x2="12" y2="3"/>
                        </svg>
                        <span>Install App</span>
                    </button>
                `;
                container.style.cssText = `
                    position: fixed;
                    bottom: 20px;
                    right: 20px;
                    z-index: 9999;
                `;

                const btn = container.querySelector('#pwa-install-btn');
                btn.style.cssText = `
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    background: #4285f4;
                    color: white;
                    border: none;
                    padding: 12px 20px;
                    border-radius: 24px;
                    cursor: pointer;
                    font-size: 14px;
                    font-weight: 500;
                    box-shadow: 0 4px 12px rgba(66, 133, 244, 0.4);
                    transition: transform 0.2s, box-shadow 0.2s;
                `;

                document.body.appendChild(container);
            }

            const installBtn = document.getElementById('pwa-install-btn');
            installBtn.addEventListener('click', async () => {
                if (deferredPrompt) {
                    deferredPrompt.prompt();
                    const { outcome } = await deferredPrompt.userChoice;
                    console.log('[PWA] Install prompt outcome:', outcome);
                    deferredPrompt = null;
                    this.hideInstallButton();
                }
            });
        },

        /**
         * Hide install button
         */
        hideInstallButton: function() {
            const container = document.getElementById('pwa-install-container');
            if (container) {
                container.remove();
            }
        },

        /**
         * Setup online/offline events
         */
        setupOnlineOfflineEvents: function() {
            const updateOnlineStatus = () => {
                const isOnline = navigator.onLine;
                document.body.classList.toggle('offline', !isOnline);

                if (isOnline) {
                    this.hideOfflineIndicator();
                    // Trigger background sync if supported
                    this.triggerBackgroundSync();
                } else {
                    this.showOfflineIndicator();
                }
            };

            window.addEventListener('online', updateOnlineStatus);
            window.addEventListener('offline', updateOnlineStatus);

            // Initial check
            updateOnlineStatus();
        },

        /**
         * Show offline indicator
         */
        showOfflineIndicator: function() {
            if (document.getElementById('pwa-offline-indicator')) return;

            const indicator = document.createElement('div');
            indicator.id = 'pwa-offline-indicator';
            indicator.innerHTML = `
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="1" y1="1" x2="23" y2="23"/>
                    <path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"/>
                    <path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"/>
                    <path d="M10.71 5.05A16 16 0 0 1 22.58 9"/>
                    <path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"/>
                    <path d="M8.53 16.11a6 6 0 0 1 6.95 0"/>
                    <line x1="12" y1="20" x2="12.01" y2="20"/>
                </svg>
                <span>You're offline</span>
            `;
            indicator.style.cssText = `
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                background: #f44336;
                color: white;
                padding: 8px 16px;
                text-align: center;
                font-size: 14px;
                z-index: 10001;
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
            `;

            document.body.appendChild(indicator);
        },

        /**
         * Hide offline indicator
         */
        hideOfflineIndicator: function() {
            const indicator = document.getElementById('pwa-offline-indicator');
            if (indicator) {
                indicator.remove();
            }
        },

        /**
         * Trigger background sync
         */
        triggerBackgroundSync: async function() {
            if (!this.registration || !('sync' in this.registration)) {
                return;
            }

            try {
                await this.registration.sync.register('sync-appointments');
                console.log('[PWA] Background sync registered');
            } catch (error) {
                console.log('[PWA] Background sync failed:', error);
            }
        },

        /**
         * Request push notification permission
         */
        requestNotificationPermission: async function() {
            if (!('Notification' in window)) {
                console.log('[PWA] Notifications not supported');
                return false;
            }

            const permission = await Notification.requestPermission();
            return permission === 'granted';
        },

        /**
         * Subscribe to push notifications
         */
        subscribeToPush: async function(vapidPublicKey) {
            if (!this.registration) {
                console.log('[PWA] No service worker registration');
                return null;
            }

            try {
                const subscription = await this.registration.pushManager.subscribe({
                    userVisibleOnly: true,
                    applicationServerKey: this.urlBase64ToUint8Array(vapidPublicKey)
                });

                this.pushSubscription = subscription;
                console.log('[PWA] Push subscription:', subscription);

                return subscription;
            } catch (error) {
                console.error('[PWA] Push subscription failed:', error);
                return null;
            }
        },

        /**
         * Unsubscribe from push notifications
         */
        unsubscribeFromPush: async function() {
            if (!this.pushSubscription) {
                return true;
            }

            try {
                await this.pushSubscription.unsubscribe();
                this.pushSubscription = null;
                console.log('[PWA] Push unsubscribed');
                return true;
            } catch (error) {
                console.error('[PWA] Push unsubscribe failed:', error);
                return false;
            }
        },

        /**
         * Convert VAPID key to Uint8Array
         */
        urlBase64ToUint8Array: function(base64String) {
            const padding = '='.repeat((4 - base64String.length % 4) % 4);
            const base64 = (base64String + padding)
                .replace(/-/g, '+')
                .replace(/_/g, '/');

            const rawData = window.atob(base64);
            const outputArray = new Uint8Array(rawData.length);

            for (let i = 0; i < rawData.length; ++i) {
                outputArray[i] = rawData.charCodeAt(i);
            }

            return outputArray;
        }
    };

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => PWA.init());
    } else {
        PWA.init();
    }

    // Export to window for external access
    window.EasyAppointmentsPWA = PWA;
})();
