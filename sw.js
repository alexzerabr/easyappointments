/**
 * Easy!Appointments Service Worker
 *
 * Provides offline support, caching, and push notification handling.
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 */

const CACHE_NAME = 'ea-cache-v1';
const OFFLINE_URL = '/offline.html';

// Assets to cache immediately on install
const PRECACHE_ASSETS = [
    '/',
    '/offline.html',
    '/assets/css/general.min.css',
    '/assets/css/layouts/booking_layout.min.css',
    '/assets/js/general_functions.min.js',
    '/assets/img/logo.png',
    '/manifest.json'
];

// API routes that should not be cached
const API_ROUTES = [
    '/api/v1/',
    '/index.php/api/'
];

// Dynamic caching routes (cache on first access)
const DYNAMIC_CACHE_ROUTES = [
    '/assets/',
    '/vendor/'
];

/**
 * Install event - precache essential assets
 */
self.addEventListener('install', (event) => {
    console.log('[ServiceWorker] Install');

    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('[ServiceWorker] Precaching assets');
                // Don't fail install if some assets fail to cache
                return Promise.allSettled(
                    PRECACHE_ASSETS.map(url =>
                        cache.add(url).catch(err =>
                            console.warn(`[ServiceWorker] Failed to cache: ${url}`, err)
                        )
                    )
                );
            })
            .then(() => {
                // Skip waiting to activate immediately
                return self.skipWaiting();
            })
    );
});

/**
 * Activate event - clean up old caches
 */
self.addEventListener('activate', (event) => {
    console.log('[ServiceWorker] Activate');

    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames
                        .filter((cacheName) => cacheName !== CACHE_NAME)
                        .map((cacheName) => {
                            console.log('[ServiceWorker] Deleting old cache:', cacheName);
                            return caches.delete(cacheName);
                        })
                );
            })
            .then(() => {
                // Claim all clients immediately
                return self.clients.claim();
            })
    );
});

/**
 * Fetch event - serve from cache, fallback to network
 */
self.addEventListener('fetch', (event) => {
    const url = new URL(event.request.url);

    // Skip non-GET requests
    if (event.request.method !== 'GET') {
        return;
    }

    // Skip cross-origin requests
    if (url.origin !== self.location.origin) {
        return;
    }

    // Skip API routes - always go to network
    if (isApiRoute(url.pathname)) {
        event.respondWith(
            fetch(event.request)
                .catch(() => {
                    return new Response(
                        JSON.stringify({ error: 'Network error', offline: true }),
                        { headers: { 'Content-Type': 'application/json' } }
                    );
                })
        );
        return;
    }

    // For navigation requests (HTML pages)
    if (event.request.mode === 'navigate') {
        event.respondWith(
            fetch(event.request)
                .catch(() => {
                    return caches.match(OFFLINE_URL);
                })
        );
        return;
    }

    // For assets - cache first, then network
    if (isDynamicCacheRoute(url.pathname)) {
        event.respondWith(
            caches.match(event.request)
                .then((cachedResponse) => {
                    if (cachedResponse) {
                        // Return cached, but also update cache in background
                        fetchAndCache(event.request);
                        return cachedResponse;
                    }

                    return fetchAndCache(event.request);
                })
        );
        return;
    }

    // Default strategy - network first, fallback to cache
    event.respondWith(
        fetch(event.request)
            .then((response) => {
                // Clone and cache successful responses
                if (response.ok) {
                    const responseClone = response.clone();
                    caches.open(CACHE_NAME)
                        .then((cache) => cache.put(event.request, responseClone));
                }
                return response;
            })
            .catch(() => {
                return caches.match(event.request);
            })
    );
});

/**
 * Push notification event
 */
self.addEventListener('push', (event) => {
    console.log('[ServiceWorker] Push received');

    let data = {
        title: 'Easy!Appointments',
        body: 'You have a new notification',
        icon: '/assets/img/pwa/icon-192x192.png',
        badge: '/assets/img/pwa/badge-72x72.png',
        tag: 'ea-notification',
        data: {}
    };

    if (event.data) {
        try {
            const payload = event.data.json();
            data = { ...data, ...payload };
        } catch (e) {
            data.body = event.data.text();
        }
    }

    const options = {
        body: data.body,
        icon: data.icon,
        badge: data.badge,
        tag: data.tag,
        data: data.data,
        vibrate: [200, 100, 200],
        requireInteraction: data.requireInteraction || false,
        actions: data.actions || []
    };

    event.waitUntil(
        self.registration.showNotification(data.title, options)
    );
});

/**
 * Notification click event
 */
self.addEventListener('notificationclick', (event) => {
    console.log('[ServiceWorker] Notification click:', event.notification.tag);

    event.notification.close();

    const notificationData = event.notification.data || {};
    let urlToOpen = '/';

    // Handle action clicks
    if (event.action) {
        switch (event.action) {
            case 'view':
                urlToOpen = notificationData.url || '/';
                break;
            case 'dismiss':
                return;
            default:
                urlToOpen = notificationData.url || '/';
        }
    } else if (notificationData.url) {
        urlToOpen = notificationData.url;
    }

    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true })
            .then((clientList) => {
                // Focus existing window if open
                for (const client of clientList) {
                    if (client.url === urlToOpen && 'focus' in client) {
                        return client.focus();
                    }
                }
                // Open new window
                if (clients.openWindow) {
                    return clients.openWindow(urlToOpen);
                }
            })
    );
});

/**
 * Background sync event
 */
self.addEventListener('sync', (event) => {
    console.log('[ServiceWorker] Sync:', event.tag);

    if (event.tag === 'sync-appointments') {
        event.waitUntil(syncAppointments());
    }
});

/**
 * Check if URL is an API route
 */
function isApiRoute(pathname) {
    return API_ROUTES.some(route => pathname.includes(route));
}

/**
 * Check if URL should be dynamically cached
 */
function isDynamicCacheRoute(pathname) {
    return DYNAMIC_CACHE_ROUTES.some(route => pathname.startsWith(route));
}

/**
 * Fetch and cache a request
 */
async function fetchAndCache(request) {
    try {
        const response = await fetch(request);

        if (response.ok) {
            const cache = await caches.open(CACHE_NAME);
            cache.put(request, response.clone());
        }

        return response;
    } catch (error) {
        const cachedResponse = await caches.match(request);
        if (cachedResponse) {
            return cachedResponse;
        }
        throw error;
    }
}

/**
 * Sync offline appointments
 */
async function syncAppointments() {
    // Get pending appointments from IndexedDB
    // This is a placeholder for future implementation
    console.log('[ServiceWorker] Syncing appointments...');

    try {
        // Implementation would:
        // 1. Open IndexedDB
        // 2. Get pending offline appointments
        // 3. Send to server
        // 4. Clear synced items

        return Promise.resolve();
    } catch (error) {
        console.error('[ServiceWorker] Sync failed:', error);
        throw error;
    }
}

/**
 * Message handler for communication with main thread
 */
self.addEventListener('message', (event) => {
    console.log('[ServiceWorker] Message received:', event.data);

    if (event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }

    if (event.data.type === 'CACHE_URLS') {
        event.waitUntil(
            caches.open(CACHE_NAME)
                .then((cache) => cache.addAll(event.data.urls))
        );
    }

    if (event.data.type === 'CLEAR_CACHE') {
        event.waitUntil(
            caches.delete(CACHE_NAME)
        );
    }
});
