# KaamNow Backend

On-demand local services marketplace for Lahore, Pakistan, using an inDrive-style bidding model.
A customer posts a job, nearby verified workers send prices, the two sides negotiate, and the
customer books the worker they prefer.

This repository holds the **Django REST backend**. The Android app (Kotlin + Jetpack Compose) is
planned for Stage 3 and will talk to this backend only through the REST API.

---

## 1. Current status

**Stage 1 (Backend MVP): done.** Every feature below has its business logic, REST endpoint(s),
validation and automated tests, and the tests pass against PostgreSQL 16.

| Feature | Status | Where |
|---|---|---|
| JWT authentication (register, login, refresh with rotation, logout with blacklist, password reset/change) | ✅ | `apps/accounts` |
| Roles (customer, worker, admin) and role-based permissions | ✅ | `apps/common/permissions.py` |
| Customer and worker profiles | ✅ | `apps/accounts` |
| Worker verification (private CNIC upload, admin approve/reject, audit log) | ✅ | `apps/accounts`, `apps/dashboard` |
| Service categories (13 seeded, admin can add, update, activate, deactivate) | ✅ | `apps/catalog` |
| Worker service listings | ✅ | `apps/catalog` |
| Service requests with images, GPS and preferred time | ✅ | `apps/jobs` |
| Nearby worker discovery (Haversine, PostGIS-ready interface) | ✅ | `apps/common/geo.py`, `apps/jobs/services.py` |
| Price offers and offer comparison (price, rating, jobs, distance, experience, verification) | ✅ | `apps/offers` |
| Price negotiation with full history | ✅ | `apps/offers/services.py` |
| Booking with row locking and DB unique constraints (no double booking) | ✅ | `apps/offers/services.py::accept_offer` |
| Booking status flow (confirmed, on the way, arrived, work started, completed, cancelled) | ✅ | `apps/jobs` |
| Completion OTP (hashed, expiry, attempt limit, resend cooldown, rate limited) | ✅ | `apps/jobs/services.py` |
| Commission calculation (default 10%, admin-configurable) | ✅ | `apps/billing` |
| Cash payment records and a balanced payment ledger | ✅ | `apps/billing` |
| Ratings and reviews | ✅ | `apps/reviews` |
| In-app notification history | ✅ | `apps/notifications` |
| Admin API: dashboard, pending workers, bookings, revenue, commissions, reports, suspensions, audit log | ✅ | `apps/dashboard` |
| Swagger / ReDoc / OpenAPI schema, Postman collection | ✅ | `/api/docs/`, `docs/` |

**Stage 2 (not started).** Nothing in this list has been built yet, and there are no models or
endpoints for it:

- Real-time chat (`/bookings/{id}/messages/`, Django Channels)
- Live location tracking (`/bookings/{id}/location/`)
- Firebase push notifications (the `notifications.services.get_push_sender()` hook is ready; today it is a no-op)
- JazzCash / Easypaisa gateway integration with signed callbacks (today the API refuses these methods)
- Worker subscriptions (`/subscriptions/...`)
- Featured listings
- Emergency service fees
- Complaints and disputes
- Redis and Celery (scheduled jobs such as expiring old requests)

---

## 2. Tech stack

Python 3.12+ (tested on 3.13) · Django 5.2 · Django REST Framework 3.18 · PostgreSQL 16 ·
SimpleJWT · drf-spectacular (OpenAPI 3) · django-filter · Pillow · Argon2 password hashing ·
pytest + pytest-django · Gunicorn + WhiteNoise for production.

## 3. Project layout

```
config/                 settings, URLs, WSGI/ASGI
apps/
  common/               envelope renderer, error handler, pagination, permissions,
                        geo (Haversine), validators, private file storage
  accounts/             User, WorkerProfile, WorkerDocument, auth + worker endpoints
  catalog/              ServiceCategory, WorkerService
  jobs/                 ServiceRequest, ServiceRequestImage, Booking, BookingStatusLog
  offers/               WorkerOffer, Negotiation (bidding, negotiation, accept)
  billing/              PlatformSettings, Commission, Payment, LedgerEntry
  reviews/              Review
  notifications/        Notification (in-app history, push hook)
  dashboard/            AuditLog, admin reporting endpoints
docs/                   openapi.yaml, Postman collection
scripts/                generate_postman.py
```

Each app follows the same pattern: `models.py`, `services.py` (all business rules and
transactions), `serializers.py` (input validation and output shape), `views.py` (thin HTTP
layer), `urls.py`, `admin.py` and `tests/`.

---

## 4. Local setup

### Prerequisites
- Python 3.12 or newer
- PostgreSQL 14 or newer

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
python manage.py runserver
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

The suite has 213 tests and needs a running PostgreSQL. It uses the database settings from your
`.env` and creates a separate `test_kaamnow` database. Coverage includes:

- **Authentication**: registration validation, login, suspended accounts, token refresh rotation, logout blacklisting, password reset (single-use token, no account enumeration), throttling.
- **Permissions**: every admin endpoint against anonymous, customer and worker; ownership checks on requests, offers, bookings, payments, notifications and documents.
- **Discovery**: Haversine distances, radius, category, verified, online and suspended filters, sorting by distance.
- **Negotiation**: the spec example (1000, then 800, then 900, then confirm 900), turn-taking, max rounds, outsiders blocked, history.
- **Booking concurrency**: real threads on real PostgreSQL transactions. Five simultaneous accepts produce one booking; a double accept of the same offer produces one booking; concurrent duplicate offers produce one offer; an accept racing a cancel has exactly one winner.
- **OTP**: hashed storage, never present in responses, expiry, attempt limit and burn, resend cooldown, rate limiting, customer in-app confirmation.
- **Payments**: amount always taken from the locked booking price, online methods refused, duplicates refused, worker confirmation, ledger balances, commission rate changes apply only to new completions.
- **Reviews, notifications and admin reports.**

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
| Auth | `POST auth/register/` · `POST auth/login/` · `POST auth/token/refresh/` · `POST auth/logout/` · `GET/PATCH auth/me/` · `POST auth/password-reset/` · `POST auth/password-reset/confirm/` · `POST auth/password-change/` |
| Workers | `GET/PATCH workers/me/` · `GET/POST workers/documents/` · `GET workers/nearby/?category=&latitude=&longitude=` · `POST workers/availability/` · `GET workers/{id}/` · `GET workers/{id}/reviews/` |
| Services | `GET services/categories/` · `GET services/categories/{id}/` · admin `POST`/`PATCH` on categories · `GET/POST services/workers/` · `PATCH/DELETE services/workers/{id}/` |
| Requests | `POST requests/` · `GET requests/` · `GET/PATCH requests/{id}/` · `POST requests/{id}/cancel/` · `GET requests/{id}/nearby-workers/` |
| Offers | `GET/POST requests/{id}/offers/` · `GET/PATCH offers/{id}/` · `POST offers/{id}/accept/` · `POST offers/{id}/reject/` · `POST offers/{id}/negotiate/` · `GET offers/{id}/negotiations/` |
| Bookings | `GET bookings/` · `GET bookings/{id}/` · `POST bookings/{id}/status/` · `POST bookings/{id}/completion-otp/` · `POST bookings/{id}/complete/` · `POST bookings/{id}/cancel/` |
| Payments | `POST payments/` · `GET payments/` · `GET payments/{id}/` · `POST payments/{id}/confirm/` · `GET payments/earnings/` |
| Reviews | `POST reviews/` · `GET workers/{id}/reviews/` |
| Notifications | `GET notifications/` · `POST notifications/{id}/read/` · `POST notifications/read-all/` · `GET notifications/unread-count/` |
| Admin | `GET admin/dashboard/` · `GET admin/workers/pending/` · `GET admin/workers/{id}/` · `POST admin/workers/{id}/verify/` · `POST admin/workers/{id}/reject/` · `GET admin/documents/{id}/file/` · `GET admin/users/` · `POST admin/users/{id}/suspend/` · `POST admin/users/{id}/reactivate/` · `GET admin/requests/` · `GET admin/bookings/` · `GET admin/revenue/` · `GET admin/commissions/` · `GET/PATCH admin/settings/commission/` · `GET admin/reports/` · `GET admin/audit-logs/` |

Endpoints added beyond the original list, because the flow needs them: `password-reset/confirm`,
`password-change`, `workers/{id}/` (public card), `offers/{id}/negotiations/`,
`bookings/{id}/completion-otp/`, `payments/{id}/confirm/`, `payments/earnings/`,
the notification helpers, and the admin users, suspension, requests, commission settings and audit log endpoints.

Postman: import `docs/KaamNow.postman_collection.json` (62 requests in 7 folders that follow the
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
- **Payments**: the amount always comes from the booking's locked price, never from the client. Cash payments need the worker's confirmation. Online methods are refused until server-side verification of signed gateway callbacks is built (Stage 2). There is at most one live payment per booking (partial unique constraint).
- **Throttling**: separate scopes for anonymous users, users, auth, password reset, OTP and offers. All limits are configurable through environment variables.
- **Audit log**: worker verify/reject, document views, user suspend/reactivate, commission changes and category changes. The audit log cannot be edited in Django admin.
- **Secrets** come only from environment variables. `DEBUG=False` turns on HSTS, SSL redirect and secure cookies, and `manage.py check --deploy` passes.

---

## 8. Deployment

### Option A: Docker (recommended)

1. Provision PostgreSQL (for example a managed database) and set the `POSTGRES_*` variables.
2. Create a `.env` from `.env.example` with `DJANGO_DEBUG=false`, a strong `DJANGO_SECRET_KEY`, `DJANGO_ALLOWED_HOSTS=api.kaamnow.pk`, SMTP settings and `CORS_ALLOWED_ORIGINS` if a web client needs it.
3. `docker compose up -d --build`. The container runs `migrate` and then starts Gunicorn on port 8000.
4. Put Nginx or a load balancer in front, terminate TLS there, and forward `X-Forwarded-Proto`.
5. Serve `MEDIA_ROOT` (request images, avatars) from Nginx or object storage. **Never** serve `PRIVATE_MEDIA_ROOT`.
6. Create the first admin: `docker compose exec api python manage.py createsuperuser`.

### Option B: VM with systemd

```bash
pip install -r requirements.txt
export $(grep -v '^#' .env | xargs)
python manage.py migrate --noinput
python manage.py collectstatic --noinput
gunicorn config.wsgi:application --bind 127.0.0.1:8000 --workers 3
```

Example Nginx configuration:

```nginx
server {
    server_name api.kaamnow.pk;
    client_max_body_size 12m;
    location /media/ { alias /var/lib/kaamnow/media/; }
    # NOTE: no location for private_media on purpose.
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Production checklist

- `python manage.py check --deploy` reports no issues
- Database backups enabled, and `PRIVATE_MEDIA_ROOT` backed up and encrypted at rest
- A real SMTP provider is configured for password-reset emails
- Throttle rates reviewed for expected traffic
- If you run several Gunicorn workers or hosts, configure a shared cache (Redis) so throttling counts are shared. The default local-memory cache counts per process.

---

## 9. Design notes and extension points

- **PostGIS**: discovery goes through `apps/common/geo.get_geo_backend()`. To switch, add a `PostGISBackend` that implements `workers_covering_point()` with `ST_DWithin` and set `GEO_BACKEND=postgis`. Callers do not change.
- **Push notifications**: implement an FCM sender and return it from `notifications.services.get_push_sender()`. Every `notify()` call already goes through it.
- **Payment gateways**: `billing.services.SUPPORTED_METHODS` controls the methods the API accepts. A gateway adapter should create a `pending` payment, redirect the customer, and mark it `completed` only from a server-verified, signature-checked callback.
- **Commission collection**: commissions are recorded as `pending` when a job completes, because with cash the worker holds the money. Settlement (marking them `collected`) is an admin or finance process for Stage 2.
- **Phone numbers** are normalised to E.164 (`+923XXXXXXXXX`). Users can log in with `0300...`, `92300...` or `+92300...`.
- **Time zone**: `Asia/Karachi`. Timestamps are returned in ISO 8601 with the offset.
