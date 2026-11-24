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

Each step prints `OK ...` or `FAIL at <step>` and saves screenshots to `shots/`.
It creates real users and bookings, so only run it against a development database.
