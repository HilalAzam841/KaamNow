// KaamNow service worker: makes the web app installable and shows a friendly page offline.
//
// Rules:
// - API, WebSocket, media and Django admin requests are never touched or cached. Bookings,
//   prices, chats and personal data always come fresh from the server.
// - App files are fetched from the network first (so a new release shows up on the next
//   load) and kept as a copy for when the network is slow or briefly gone.
// - Opening the app with no connection at all shows offline.html.
'use strict';

const CACHE = 'kaamnow-app-v1';
const PRECACHE = ['offline.html', 'icons/Icon-192.png', 'manifest.json', 'favicon.png'];
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
