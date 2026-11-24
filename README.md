# KaamNow

On-demand local services marketplace for Lahore, Pakistan, using an inDrive-style bidding model.
A customer posts a job, nearby verified workers send prices, the two sides negotiate, and the
customer books the worker they prefer.

This repository holds the **Django REST backend** and, in [`app/`](app/), the **Flutter client**.
The client runs on the web today. The same Flutter code base will build the Android and iOS apps
later, and talks to the backend only through the REST API and the booking WebSocket.

---

## 1. Current status

**Stage 1 (Backend MVP) and Stage 2 (Advanced features) are done, and Stage 3 has its Flutter web
client.** Every backend feature below has its business logic, REST endpoint(s), validation and
automated tests. All 335 backend tests pass against PostgreSQL 16, and the Flutter app has 31
unit and widget tests plus a browser end-to-end run (see `app/README.md`).

### Stage 1: Backend MVP

| Feature | Where |
|---|---|
| JWT authentication (register, login, refresh with rotation, logout with blacklist, password reset/change) | `apps/accounts` |
| Roles (customer, worker, admin) and role-based permissions | `apps/common/permissions.py` |
| Customer and worker profiles | `apps/accounts` |
| Worker verification (private CNIC upload, admin approve/reject, audit log) | `apps/accounts`, `apps/dashboard` |
| Service categories (13 seeded, admin can add, update, activate, deactivate) | `apps/catalog` |
| Worker service listings | `apps/catalog` |
| Service requests with images, GPS and preferred time | `apps/jobs` |
| Nearby worker discovery (Haversine, PostGIS-ready interface) | `apps/common/geo.py`, `apps/jobs/services.py` |
| Price offers and comparison (price, rating, jobs, distance, experience, verification) | `apps/offers` |
| Price negotiation with full history | `apps/offers/services.py` |
| Booking with row locking and DB unique constraints (no double booking) | `apps/offers/services.py::accept_offer` |
| Booking status flow (confirmed, on the way, arrived, work started, completed, cancelled) | `apps/jobs` |
| Completion OTP (hashed, expiry, attempt limit, resend cooldown, rate limited) | `apps/jobs/services.py` |
| Commission calculation (default 10%, admin-configurable) | `apps/billing` |
| Cash payment records and a balanced payment ledger | `apps/billing` |
| Ratings and reviews | `apps/reviews` |
| In-app notification history | `apps/notifications` |
| Admin API: dashboard, pending workers, bookings, revenue, commissions, reports, suspensions, audit log | `apps/dashboard` |

### Stage 2: Advanced features

| Feature | Where |
|---|---|
| Real-time chat: REST history + WebSocket delivery, read receipts, participants only | `apps/chat` |
| Live worker location: REST + WebSocket, distance and ETA to the job, short trail, 30-day retention | `apps/tracking` |
| WebSocket booking channel (chat, location, status events) with JWT auth and origin check | `apps/chat/consumers.py`, `config/asgi.py` |
| Firebase push notifications (device tokens, FCM HTTP v1 sender in Celery, dead-token cleanup) | `apps/notifications` |
| JazzCash hosted checkout with `pp_SecureHash` request signing and callback verification | `apps/billing/gateways/jazzcash.py` |
| Easypaisa hosted checkout (AES-encrypted request) with server-to-server inquiry before settling | `apps/billing/gateways/easypaisa.py` |
| Worker subscriptions (Free, Professional, Premium) with enforced benefits: commission rate and daily offer limit | `apps/billing` |
| Featured (sponsored) listings: paid placement at the top of category search results, clearly flagged `is_sponsored` | `apps/billing`, `apps/catalog`, `apps/jobs` |
| Emergency requests with an admin-configurable fee, locked at request time and shown in the booking total | `apps/jobs`, `apps/billing` |
| Complaints and disputes (customers and workers report; admins review, resolve or reject; audited) | `apps/support` |
| Celery scheduled jobs: expire stale requests, expire unpaid online checkouts, expire plans and listings, purge old GPS points | `*/tasks.py`, `CELERY_BEAT_SCHEDULE` |
| Admin API for plans, subscriptions, featured listings, complaints, platform settings and extra revenue | `apps/dashboard` |

### Stage 3: Flutter client (web first)

| Feature | Where |
|---|---|
| Flutter app for customers and workers, built for the web; Android and iOS later from the same code | `app/` |
| API client: response envelope, JWT refresh with one shared refresh call, readable errors | `app/lib/core/api_client.dart` |
| Customer: browse services, post a job (map pin or GPS, photos, emergency), compare offers and sort them, counter, book | `app/lib/ui/customer/` |
| Worker: verification (CNIC upload, services, base location), go online, job feed, send offers, negotiate | `app/lib/ui/worker/` |
| Both: bookings, live tracking over WebSocket, chat, completion code, cash payment, reviews, alerts, complaints | `app/lib/ui/bookings/`, `app/lib/ui/account/` |
| Backend APIs added for client apps: `GET app/config/` (public bootstrap) and `GET offers/` (worker's own offers) | `apps/common/views.py`, `apps/offers/views.py` |
| WebSocket origin check that accepts CORS-allowed web origins and native apps (no Origin header) | `apps/chat/origin.py` |

**Before going live with online payments:** the JazzCash and Easypaisa adapters follow each
gateway's published integration scheme and are covered by tests with simulated gateway responses.
They have **not** been run against the real sandboxes yet, because that needs your merchant
credentials. Run one sandbox payment per gateway before launch (see section 8).

---

## 2. Tech stack

Python 3.12+ (tested on 3.13) · Django 5.2 · Django REST Framework 3.18 · PostgreSQL 16 ·
SimpleJWT · Django Channels 4 + Daphne (WebSockets) · Redis · Celery 5 · Firebase Cloud Messaging
(HTTP v1) · drf-spectacular (OpenAPI 3) · django-filter · Pillow · Argon2 password hashing ·
pytest + pytest-django + pytest-asyncio · WhiteNoise for static files.

## 3. Project layout

```
config/                 settings, URLs, ASGI (HTTP + WebSockets), Celery app
apps/
  common/               envelope renderer, error handler, pagination, permissions,
                        geo (Haversine), validators, private file storage
  accounts/             User, WorkerProfile, WorkerDocument, auth + worker endpoints
  catalog/              ServiceCategory, WorkerService
  jobs/                 ServiceRequest, ServiceRequestImage, Booking, BookingStatusLog
  offers/               WorkerOffer, Negotiation (bidding, negotiation, accept)
  billing/              PlatformSettings, Commission, Payment, LedgerEntry, SubscriptionPlan,
                        WorkerSubscription, FeaturedPlan, FeaturedListing, gateways/ (JazzCash, Easypaisa)
  reviews/              Review
  notifications/        Notification, DeviceToken, FCM sender
  dashboard/            AuditLog, admin reporting endpoints
  chat/                 ChatMessage, WebSocket consumer + JWT middleware
  tracking/             BookingLocation (live GPS)
  support/              Complaint
docs/                   openapi.yaml, Postman collection
scripts/                generate_postman.py
app/                    Flutter client (web now, Android/iOS later): lib/, test/, e2e/
```

Each app follows the same pattern: `models.py`, `services.py` (all business rules and
transactions), `serializers.py` (input validation and output shape), `views.py` (thin HTTP
layer), `urls.py`, `admin.py` and `tests/`.

---

## 4. Local setup

### Prerequisites
- Python 3.12 or newer
- PostgreSQL 14 or newer
- Redis 6 or newer (optional locally: without `REDIS_URL` the app uses an in-memory channel layer and
  runs Celery tasks inline, which is fine for development on a single process)

### Steps

```bash
git clone <repo-url> kaamnow && cd kaamnow
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

# Database
sudo -u postgres psql -c "CREATE USER kaamnow WITH PASSWORD 'kaamnow' CREATEDB;"
sudo -u postgres createdb -O kaamnow kaamnow

# Configuration
cp .env.example .env
# For local development set at least:
#   DJANGO_DEBUG=true
#   DJANGO_SECRET_KEY=<any long random string>
#   POSTGRES_PASSWORD=kaamnow
#   EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend

python manage.py migrate           # creates tables, seeds 13 categories and the 10% commission
python manage.py seed_demo_data    # optional: demo admin, customer and 4 verified workers in Lahore
python manage.py runserver          # serves HTTP and WebSockets (Daphne is installed)

# With Redis, in two more terminals:
celery -A config worker -l info
celery -A config beat -l info
```

Open:
- Swagger UI: http://localhost:8000/api/docs/
- ReDoc: http://localhost:8000/api/redoc/
- OpenAPI schema: http://localhost:8000/api/schema/
- Django admin: http://localhost:8000/django-admin/
- Health check: http://localhost:8000/api/v1/health/

`seed_demo_data` uses the password `KaamNow-Demo-2026` for every demo account
(admin `03000000001`, customer `03000000002`, workers `03001000001` to `03001000004`).
It refuses to run when `DEBUG=False` unless you pass `--force`.

To create a real admin instead: `python manage.py createsuperuser` (log in with the phone number).

### Running with Docker

```bash
cp .env.example .env   # set DJANGO_SECRET_KEY, POSTGRES_PASSWORD, DJANGO_ALLOWED_HOSTS
docker compose up --build
```

---

## 5. Tests

```bash
pytest -q
```

The suite has 323 tests and needs a running PostgreSQL (Redis is not needed for tests). It uses the database settings from your
`.env` and creates a separate `test_kaamnow` database. Coverage includes:

- **Authentication**: registration validation, login, suspended accounts, token refresh rotation, logout blacklisting, password reset (single-use token, no account enumeration), throttling.
- **Permissions**: every admin endpoint against anonymous, customer and worker; ownership checks on requests, offers, bookings, payments, notifications and documents.
- **Discovery**: Haversine distances, radius, category, verified, online and suspended filters, sorting by distance.
- **Negotiation**: the spec example (1000, then 800, then 900, then confirm 900), turn-taking, max rounds, outsiders blocked, history.
- **Booking concurrency**: real threads on real PostgreSQL transactions. Five simultaneous accepts produce one booking; a double accept of the same offer produces one booking; concurrent duplicate offers produce one offer; an accept racing a cancel has exactly one winner.
- **OTP**: hashed storage, never present in responses, expiry, attempt limit and burn, resend cooldown, rate limiting, customer in-app confirmation.
- **Payments**: amount always taken from the locked booking price, online methods refused, duplicates refused, worker confirmation, ledger balances, commission rate changes apply only to new completions.
- **Reviews, notifications and admin reports.**
- **Online payments**: JazzCash hash matches an independent implementation of the documented algorithm; forged or tampered callbacks rejected; amount mismatches flagged as disputed; replayed callbacks are idempotent; late success after expiry is flagged; a "success" redirect is ignored when the Easypaisa inquiry says otherwise; gateway outages leave payments pending.
- **Subscriptions and featured listings**: activation only after verified payment, renewals extend, plan commission applied at job completion, daily offer limit enforced, sponsored ordering and labelling, slot limits, expiry.
- **Emergency fee**: locked at request time, included in the payment, separate ledger entry, commission only on the negotiated price.
- **Chat and tracking over WebSockets** (real ASGI app): token, suspension, origin and participant checks; chat and read receipts in both directions; REST messages pushed to sockets; location and status events; customers cannot send fake locations; events isolated per booking.
- **Push**: message format, only active devices, dead tokens deactivated, retries on transient errors.
- **Complaints** and **scheduled tasks** (including a check that every beat entry points to a registered task).

CI (`.github/workflows/tests.yml`) runs lint, checks for missing migrations, validates the
OpenAPI schema with warnings treated as failures, runs the migrations and runs the full test
suite on PostgreSQL 16.

---

## 6. API overview

Base URL: `/api/v1/`. Authenticate with `Authorization: Bearer <access token>`.

### Response format

Success:
```json
{ "success": true, "data": { ... }, "message": null }
```
Error:
```json
{ "success": false, "error": { "code": "validation_error", "message": "phone: Enter a valid Pakistani mobile number, e.g. 03001234567.", "details": { "phone": ["..."] } } }
```
List responses are paginated: `data = {count, page, total_pages, next, previous, results}`.
Use `?page=` and `?page_size=` (maximum 100). Money is always returned as a decimal string, for example `"1800.00"`.

Common status codes: `400` validation or business rule, `401` not authenticated,
`403` wrong role, `404` not found **or not yours** (private resources return 404 so ids cannot
be probed), `409` state conflict (already booked, wrong turn, and so on), `429` throttled.

### Endpoints

| Area | Endpoints |
|---|---|
| App | `GET app/config/` (public: minimum app versions, emergency fee, offer price limits, which payment methods are configured, WebSocket path) |
| Auth | `POST auth/register/` · `POST auth/login/` · `POST auth/token/refresh/` · `POST auth/logout/` · `GET/PATCH auth/me/` · `POST auth/password-reset/` · `POST auth/password-reset/confirm/` · `POST auth/password-change/` |
| Workers | `GET/PATCH workers/me/` · `GET/POST workers/documents/` · `GET workers/nearby/?category=&latitude=&longitude=` · `POST workers/availability/` · `GET workers/{id}/` · `GET workers/{id}/reviews/` |
| Services | `GET services/categories/` · `GET services/categories/{id}/` · admin `POST`/`PATCH` on categories · `GET/POST services/workers/` · `PATCH/DELETE services/workers/{id}/` |
| Requests | `POST requests/` · `GET requests/` · `GET/PATCH requests/{id}/` · `POST requests/{id}/cancel/` · `GET requests/{id}/nearby-workers/` |
| Offers | `GET/POST requests/{id}/offers/` · `GET offers/` (worker's own, `?status=`) · `GET/PATCH offers/{id}/` · `POST offers/{id}/accept/` · `POST offers/{id}/reject/` · `POST offers/{id}/negotiate/` · `GET offers/{id}/negotiations/` |
| Bookings | `GET bookings/` · `GET bookings/{id}/` · `POST bookings/{id}/status/` · `POST bookings/{id}/completion-otp/` · `POST bookings/{id}/complete/` · `POST bookings/{id}/cancel/` |
| Chat | `GET/POST bookings/{id}/messages/` · `POST bookings/{id}/messages/read/` |
| Tracking | `POST bookings/{id}/location/` (worker) · `GET bookings/{id}/location/` |
| Payments | `POST payments/` (cash, jazzcash, easypaisa) · `GET payments/` · `GET payments/{id}/` · `POST payments/{id}/confirm/` · `GET payments/earnings/` · `POST/GET payments/callbacks/jazzcash/` · `POST/GET payments/callbacks/easypaisa/` |
| Subscriptions | `GET subscriptions/plans/` · `POST subscriptions/` · `GET subscriptions/my-subscription/` · `GET subscriptions/history/` |
| Featured | `GET featured/plans/` · `GET/POST featured/` |
| Complaints | `POST complaints/` · `GET complaints/` · `GET complaints/{id}/` |
| Reviews | `POST reviews/` · `GET workers/{id}/reviews/` |
| Notifications | `GET notifications/` · `POST notifications/{id}/read/` · `POST notifications/read-all/` · `GET notifications/unread-count/` · `POST/DELETE notifications/devices/` |
| Admin | `GET admin/dashboard/` · `GET admin/workers/pending/` · `GET admin/workers/{id}/` · `POST admin/workers/{id}/verify/` · `POST admin/workers/{id}/reject/` · `GET admin/documents/{id}/file/` · `GET admin/users/` · `POST admin/users/{id}/suspend/` · `POST admin/users/{id}/reactivate/` · `GET admin/requests/` · `GET admin/bookings/` · `GET admin/revenue/` · `GET admin/commissions/` · `GET/PATCH admin/settings/commission/` · `GET admin/reports/` · `GET admin/audit-logs/` · `GET/PATCH admin/settings/` · `GET admin/revenue/other/` · `admin/subscription-plans/` (list, create, update) · `admin/featured-plans/` (list, create, update) · `GET admin/subscriptions/` · `POST admin/subscriptions/{id}/activate/` · `GET admin/featured-listings/` · `POST admin/featured-listings/{id}/cancel/` · `GET admin/complaints/` · `POST admin/complaints/{id}/status/` |

Endpoints added beyond the original list, because the flow needs them: `password-reset/confirm`,
`password-change`, `workers/{id}/` (public card), `offers/{id}/negotiations/`,
`bookings/{id}/completion-otp/`, `payments/{id}/confirm/`, `payments/earnings/`,
the notification helpers, and the admin users, suspension, requests, commission settings and audit log endpoints.

Postman: import `docs/KaamNow.postman_collection.json` (96 requests in 12 folders that follow the
full flow; test scripts store tokens and ids automatically). Regenerate it with
`python scripts/generate_postman.py`.

### End-to-end flow

1. **Customer** `POST /requests/` with category, title, description, coordinates, address, preferred time and optional images. Matching workers get a `new_request` notification.
2. **Worker** `GET /requests/` returns the feed: open requests in the worker's categories and inside the worker's radius. Workers see the area, approximate coordinates (about 1 km precision) and distance, but never the address or phone number.
3. **Worker** `POST /requests/{id}/offers/` with `price`, `estimated_arrival_minutes`, `message` and `additional_info`. One offer per worker per request.
4. **Customer** `GET /requests/{id}/offers/?ordering=price|rating|distance|experience|completed_jobs|eta`.
5. **Negotiation**: `POST /offers/{id}/negotiate/` with `{"action":"counter","amount":"800"}` or `{"action":"agree"}`. The parties take turns (`awaiting` shows whose turn it is). A customer cannot accept a price they proposed themselves; the worker must counter or agree first.
6. **Customer** `POST /offers/{id}/accept/` creates the booking at the current price, closes the other offers and notifies everyone.
7. **Worker** `POST /bookings/{id}/status/` moves through `on_the_way`, then `arrived`, then `in_progress`. While the booking is active, each side can see the other's phone number, and the worker can see the exact address.
8. **Customer** `POST /bookings/{id}/completion-otp/` returns a 6-digit code to the customer only. The customer tells it to the worker, who calls `POST /bookings/{id}/complete/` with `{"otp": "123456"}`. Alternatively the customer confirms in the app with `{"confirm": true}`.
9. On completion the commission is recorded (for example Rs. 2,000 gives Rs. 200 commission and Rs. 1,800 to the worker).
10. **Customer** `POST /payments/` with `{"booking": id, "method": "cash"}`. **Worker** `POST /payments/{id}/confirm/` writes the ledger entries.
11. **Customer** `POST /reviews/` updates the worker's average rating.

Stage 2 additions to the flow:

- Steps 7 and 8: both sides open the booking WebSocket to chat and to watch the worker's live location and status changes.
- Step 1 with `"is_emergency": true` adds the current emergency fee, which is locked on the request. Matching workers get an "URGENT" notification, and emergency requests appear first in their feed.
- Step 10 with `"method": "jazzcash"` or `"easypaisa"` returns a `checkout` object `{url, method, fields}`. The app POSTs `fields` to `url` in a WebView. The gateway then calls our callback URL, the server verifies it, and the payment becomes `completed` (or `failed` / `disputed`). The app polls `GET /payments/{id}/` or listens for the `payment` push. Watching for the callback page (`#kaamnow-payment[data-status]`) is also possible.

### WebSocket protocol

Connect to `wss://<host>/ws/bookings/<booking_id>/?token=<access token>`. The `Authorization: Bearer`
header also works. Only the booking's customer and worker can connect. Close codes: `4401` (not
authenticated or suspended) and `4404` (not a participant).

Client to server:

```json
{"type": "chat.message", "body": "Gate code is 1234"}
{"type": "chat.read"}
{"type": "location.update", "latitude": 31.52, "longitude": 74.34, "speed_kmh": 28, "heading": 90, "accuracy_m": 8}
{"type": "ping"}
```

Server to client: `chat.message`, `chat.read`, `location.update` (with `distance_to_customer_km`
and `eta_minutes`), `booking.status`, `error`, `pong`. Each event is `{"type": ..., "data": {...}}`.
Every event is also available over REST, so the socket is a convenience rather than the only
source of data: an app that reconnects can always catch up with `GET /bookings/{id}/messages/` and
`GET /bookings/{id}/location/`.

---

## 7. Security design

- **Passwords** are hashed with Argon2 and checked by Django's password validators.
- **JWT**: 30-minute access tokens and 14-day refresh tokens, with rotation and blacklisting. Logout blacklists the refresh token. Suspending a user blacklists all their refresh tokens, and the authentication class rejects their access tokens immediately.
- **Role permissions** live in `apps/common/permissions.py`. Ownership is checked in querysets and again in the service layer.
- **Privacy**: public worker cards never contain the phone number, CNIC or home coordinates. Workers who are not booked never see the customer's address or phone. Reviews show only the customer's first name. Negotiations are visible only to their two participants and admins.
- **CNIC documents** are stored under `PRIVATE_MEDIA_ROOT` with random file names and no URL. Admins download them through `GET /admin/documents/{id}/file/` (sent with `Cache-Control: no-store`), and each download is written to the audit log.
- **Uploads**: extension allow-list, size limits, and content verification (images are opened with Pillow, PDFs must start with `%PDF-`). A file renamed to `.jpg` is rejected.
- **No duplicate bookings**: `SELECT ... FOR UPDATE` on the request row, a re-check inside the lock, and `OneToOne` unique constraints on `Booking.request` and `Booking.offer` as a database-level backstop. Locks are always taken in the same order (request, then offer) to avoid deadlocks.
- **No duplicate offers**: a unique `(request, worker)` constraint, plus the request lock.
- **OTP**: generated with `secrets`, stored as an HMAC-SHA256 hash, never serialised, 15-minute expiry, 5 attempts and then the code is burned, 60-second resend cooldown, and a throttled endpoint. Failed attempts are committed even though the request returns an error.
- **Payments**: the amount always comes from the server (booking total, plan price or featured price), never from the client. Cash payments need the worker's confirmation. Online payments settle only from a verified gateway callback: JazzCash by HMAC-SHA256 `pp_SecureHash` with the merchant integrity salt (constant-time compare, merchant id checked); Easypaisa by a server-to-server inquiry, ignoring whatever the redirect claims. The callback amount must equal the payment amount, otherwise the payment is marked `disputed` and nothing is settled. Callbacks are idempotent. A success that arrives after a checkout expired is flagged as disputed rather than settled automatically. Gateway passwords and hashes are stripped before the callback data is stored. There is at most one live payment per booking (partial unique constraint).
- **WebSockets**: JWT required (suspended users rejected). Browser origins must be in `ALLOWED_HOSTS` or the CORS allow-list (`CORS_ALLOWED_ORIGINS`, `CORS_ALLOWED_ORIGIN_REGEXES`), so the web app can connect from its own domain and other sites cannot; native apps send no Origin and are accepted, and only booking participants can join. Events are scoped to one booking group. Only the assigned worker can publish locations. Chat, location and payment callbacks have their own throttles.
- **Private conversations**: chat is readable only by the two participants (admins cannot read it through the API; staff can view it read-only in Django admin for disputes). Customers see live location only while the booking is active. Old GPS points are purged after 30 days.
- **Throttling**: separate scopes for anonymous users, users, auth, password reset, OTP and offers. All limits are configurable through environment variables.
- **Audit log**: worker verify/reject, document views, user suspend/reactivate, commission and platform-settings changes, category and plan changes, manual subscription activation, featured-listing cancellation and complaint decisions. The audit log cannot be edited in Django admin.
- **Secrets** come only from environment variables. `DEBUG=False` turns on HSTS, SSL redirect and secure cookies, and `manage.py check --deploy` passes.

---

## 8. Deployment

**The step-by-step guide is [`deploy/README.md`](deploy/README.md).** One Ubuntu server runs the whole
stack with `docker compose up -d --build`:

| Service | What it does |
|---|---|
| `web` | Caddy: automatic HTTPS for your domain; serves the Flutter web app; proxies `/api`, `/ws`, `/django-admin`, `/static` to Django; serves `/media`; never serves CNIC documents |
| `api` | Django on Daphne (HTTP and WebSockets), health-checked |
| `migrate` | Applies database migrations before the API starts |
| `worker`, `beat` | Celery background jobs and the scheduler (one beat) |
| `db`, `redis` | PostgreSQL 16 and Redis 7, not reachable from outside the server |
| `backup` | Database dump, CNIC documents and uploads every 24 hours, kept 14 days |

`deploy/setup-server.sh` prepares a fresh server (Docker, firewall, swap, security updates), and
`deploy/new-env.sh` writes the settings file with fresh secrets. The `images and deploy` GitHub
Actions workflow checks on every pull request that both images build. On `main` it publishes them to
GitHub Container Registry, and deploys over SSH once you set `DEPLOY_HOST` (see the guide).

This stack has been run end to end: the full customer and worker journey passed over HTTPS and secure
WebSockets, along with password reset, a backup, and a restore of that backup.
`manage.py check --deploy` reports no issues.

### Without Docker (VM with systemd)

```bash
pip install -r requirements.txt
export $(grep -v '^#' .env | xargs)
python manage.py migrate --noinput
python manage.py collectstatic --noinput
daphne -b 127.0.0.1 -p 8000 --proxy-headers config.asgi:application   # systemd unit 1
celery -A config worker -l info                                        # systemd unit 2
celery -A config beat -l info                                          # systemd unit 3 (run exactly one)
```

Put a TLS-terminating proxy in front that forwards `X-Forwarded-Proto` and allows WebSocket
upgrades on `/ws/`. Serve `MEDIA_ROOT` from it, and **never** serve `PRIVATE_MEDIA_ROOT`.
`deploy/Caddyfile` shows the routes.

### Payment gateway go-live

1. Get sandbox merchant credentials from JazzCash and Easypaisa, and put them in `.env`.
2. Register the callback URLs with each gateway: `https://<host>/api/v1/payments/callbacks/jazzcash/` and `https://<host>/api/v1/payments/callbacks/easypaisa/`.
3. Make one sandbox payment per gateway from the app's WebView. Check that the payment becomes `completed`, that the ledger entries are written, and that a tampered callback is rejected.
4. Switch the `*_CHECKOUT_URL` and `*_INQUIRY_URL` values to the production endpoints the gateways give you, along with the production credentials.

### Firebase push go-live

1. In the Firebase console, create a service account with the "Firebase Cloud Messaging API" enabled and download the JSON key.
2. Put the file on the server outside the repo, then set `FCM_PROJECT_ID` and `FCM_CREDENTIALS_FILE`.
3. The mobile app calls `POST /api/v1/notifications/devices/` after login and whenever FCM gives it a new token, and calls `DELETE` on logout. It should create a notification channel named `kaamnow_default`.

### Production checklist

- `python manage.py check --deploy` reports no issues
- `REDIS_URL` set (needed for shared throttling, WebSocket fan-out across processes, and Celery)
- Exactly one Celery beat process
- Database backups enabled, and `PRIVATE_MEDIA_ROOT` backed up and encrypted at rest
- A real SMTP provider is configured for password-reset emails
- Gateway sandbox test done (see above); throttle rates reviewed for expected traffic

---

## 9. Design notes and extension points

- **PostGIS**: discovery goes through `apps/common/geo.get_geo_backend()`. To switch, add a `PostGISBackend` that implements `workers_covering_point()` with `ST_DWithin` and set `GEO_BACKEND=postgis`. Callers do not change.
- **New payment gateways**: subclass `billing.gateways.base.PaymentGateway` (`build_checkout`, `verify_callback`), register it in `billing/gateways/__init__.py`, add a method choice and a callback route. Settlement, ledger and fulfilment are shared.
- **Revenue streams**: booking commission (`platform_commission` ledger entries), subscriptions (`subscription_revenue`), featured listings (`featured_revenue`) and emergency fees (`emergency_fee`). `GET /admin/revenue/` covers commission; `GET /admin/revenue/other/` covers the rest.
- **Commission collection**: with cash, commission is recorded as `pending` (the worker holds the money). With JazzCash or Easypaisa it is `collected` automatically. Settling cash commissions and paying out online earnings is a finance process that is not built yet.
- **Plans and pricing**: the seeded plan and featured prices (Free; Professional Rs. 1,500 at 8% commission; Premium Rs. 3,000 at 6%; featured 7 days Rs. 500 and 30 days Rs. 1,500; emergency fee Rs. 300) are placeholders. Admins change them through the admin API or Django admin.
- **Phone numbers** are normalised to E.164 (`+923XXXXXXXXX`). Users can log in with `0300...`, `92300...` or `+92300...`.
- **Time zone**: `Asia/Karachi`. Timestamps are returned in ISO 8601 with the offset.
