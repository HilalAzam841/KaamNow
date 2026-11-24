// KaamNow service worker: makes the web app installable, shows a friendly page offline and
// shows push notifications.
//
// Rules:
// - API, WebSocket, media and Django admin requests are never touched or cached. Bookings,
//   prices, chats and personal data always come fresh from the server.
// - App files are fetched from the network first (so a new release shows up on the next
//   load) and kept as a copy for when the network is slow or briefly gone.
// - Opening the app with no connection at all shows offline.html.
'use strict';

const CACHE = 'kaamnow-app-v2';
const PRECACHE = ['offline.html', 'icons/Icon-192.png', 'icons/badge-72.png', 'manifest.json', 'favicon.png'];
const NEVER_CACHE = /^\/(api|ws|media|django-admin|static)\//;

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('kaamnow-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin || NEVER_CACHE.test(url.pathname)) {
    return; // straight to the network, untouched
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(async () => (await caches.match('offline.html')) || Response.error()),
    );
    return;
  }

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok && response.type === 'basic') {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, copy));
        }
        return response;
      })
      .catch(async () => (await caches.match(request)) || Response.error()),
  );
});

// --- Push notifications -------------------------------------------------------------------
// The server sends {title, body, url, tag, type}, already in the user's language.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = { body: event.data ? event.data.text() : '' };
  }
  const title = data.title || 'KaamNow';
  const options = {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/badge-72.png',
    data: { url: data.url || '/#/notifications' },
    lang: /[؀-ۿ]/.test(title + (data.body || '')) ? 'ur' : 'en',
    dir: 'auto',
  };
  if (data.tag) {
    options.tag = data.tag; // e.g. one notification per chat, updated as messages arrive
    options.renotify = true;
  }
  event.waitUntil(self.registration.showNotification(title, options));
});

// Tapping a notification focuses an open KaamNow window on the right screen, or opens one.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data && event.notification.data.url || '/#/notifications', self.location.origin).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if (new URL(client.url).origin === self.location.origin) {
        // The page moves itself to the screen (see index.html); this works whether or not
        // the window is controlled by this worker yet, unlike client.navigate().
        client.postMessage({ type: 'open', url: target });
        if ('focus' in client) await client.focus().catch(() => {});
        return;
      }
    }
    await self.clients.openWindow(target);
  })());
});

// The browser replaced the subscription (keys rotated): tell open windows to register again.
self.addEventListener('pushsubscriptionchange', (event) => {
  event.waitUntil(self.clients.matchAll({ type: 'window' }).then((windows) =>
    windows.forEach((w) => w.postMessage({ type: 'resubscribe' }))));
});
