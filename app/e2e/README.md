# Browser end-to-end check

Drives the real Flutter web build against a running backend with Playwright, through the whole
job: a customer signs up and posts a job, a worker signs up, uploads CNIC images, adds a service,
is verified (through the Django shell, standing in for an admin), goes online and sends an offer,
the customer books, the worker sets off (live location reaches the customer over WebSocket), both
chat, the customer issues the completion code, the worker completes with it, the customer pays
cash, the worker confirms, the customer leaves a review and the worker sees their earnings.

```bash
# 1. backend on :8000 with DJANGO_DEBUG=true (lets localhost origins through CORS)
daphne -b 127.0.0.1 -p 8000 config.asgi:application
# 2. web build served on :8080
cd app && flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:8000
python3 -m http.server 8080 --directory build/web
# 3. run (needs `npm i playwright` or a global Playwright with Chromium)
cd app/e2e && node step1.js && node step2.js && node step3.js
```

`admin.js` logs in as an admin (set `ADMIN_PHONE` and `ADMIN_PASSWORD`, created with
`python manage.py createsuperuser`), opens a pending worker's CNIC image, visits every admin page
and reloads to check the page survives:

```bash
cd app/e2e && ADMIN_PHONE=03009999999 ADMIN_PASSWORD=... node admin.js
```

`urdu.js` checks that a browser set to Urdu still opens in English, picks Urdu from the language menu and visits the customer's and worker's main screens
(run it after step1-3, which create the users it signs in as), then switches back to English:

```bash
cd app/e2e && node urdu.js
```

`pwa.js` checks the installable app: the manifest and icons, that the service worker controls
the page, Chrome's installability audit, that no API response is cached, and the offline page:

```bash
cd app/e2e && node pwa.js
```

`push.js` checks browser notifications (start the backend with VAPID keys set): the home card turns
them on, a push message is shown with the server's title, and tapping it opens the right screen.
Without internet the browser cannot reach Google's push service, so the script then registers a
stand-in subscription and delivers the message straight to the service worker, and says so:

```bash
cd app/e2e && node push.js
```

Against the production Docker stack running locally (see `deploy/README.md`):

```bash
cd app/e2e && export APP_URL=https://localhost:8443/ IGNORE_HTTPS_ERRORS=1 \
  MANAGE='docker compose -f ../../deploy/docker-compose.yml exec -T api python manage.py'
node step1.js && node step2.js && node step3.js
```

Each step prints `OK ...` or `FAIL at <step>` and saves screenshots to `shots/`.
It creates real users and bookings, so only run it against a development database.
