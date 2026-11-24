# KaamNow app (Flutter)

The customer and worker app for KaamNow. It runs on the **web** today; the same code will build
the Android and iOS apps later (the `android/` and `ios/` folders are already generated). It
talks to the Django backend in the repository root through `/api/v1/` and the booking WebSocket.

## What works

| Customers | Workers |
|---|---|
| Sign up / log in (JWT, refreshed automatically) | Sign up with CNIC |
| Browse services, post a job: map pin or GPS, photos, preferred time, budget, emergency | Verification: upload CNIC front/back, add services with starting prices, set base location and radius |
| Compare offers (sort by price, rating, distance, arrival time, jobs, experience) | Go online/offline; job feed (emergencies first) |
| Counter offer, reject, or book at the current price | Send an offer, agree to or counter the customer's price, withdraw |
| Live tracking of the worker (distance and ETA) | Status updates (on the way, arrived, started) with automatic location sharing |
| Completion code to give the worker, or confirm in-app | Complete the job with the customer's code |
| Pay cash (online gateways appear once configured on the server), rate the worker | Confirm cash received; earnings and commission; subscription plans |
| Chat, alerts, complaints, account | Chat, alerts, complaints, account |

### Admin dashboard

An admin who logs in gets the admin dashboard at `/admin` instead (sidebar on wide screens, a menu on phones):

| Page | What admins can do |
|---|---|
| Overview | Pending verifications, open complaints, bookings today, gross value, commission, a 30-day chart, bookings by service, top workers |
| Verification | Search the queue, open a worker, view their CNIC images and PDFs (each view is audit-logged), verify, or reject with a reason |
| Users | Search and filter customers, workers, admins and suspended accounts; suspend with a reason (signs them out everywhere) or reactivate |
| Jobs | All bookings and requests with status filters, search, and each booking's status timeline |
| Revenue | Revenue for any date range, monthly commission, payments by method, commissions due and collected |
| Plans | Create and edit subscription and featured plans, activate a subscription paid offline, cancel a featured listing |
| Complaints | Move complaints through open, in review, resolved or rejected, with a note for the customer |
| Settings | Commission %, emergency fee, emergency jobs on or off (a commission change asks for confirmation) |
| Audit log | Every sensitive admin action, filterable by type |

### Urdu

The app always opens in English. A language menu (🌐 English ▾) in the top bar of every screen,
including login and sign-up, switches to اردو. Urdu turns the whole app right to left and uses the bundled Noto Nastaliq Urdu font
(`assets/fonts/`, SIL Open Font License). The choice is remembered in the browser, sent to the
server with every request (`Accept-Language`) and saved on the account, so server messages and
alerts arrive in the same language. Amounts read "1,800 روپے"; numbers stay in Western digits.
The admin dashboard is always English. Strings are in `lib/l10n/app_en.arb` and `app_ur.arb`
(`flutter gen-l10n` regenerates `lib/l10n/gen/`).

Customers and workers who open an `/admin` link are sent back to their own home screen, and the
server checks the admin role on every admin endpoint regardless.

## Run it

```bash
# backend (repo root), DJANGO_DEBUG=true lets any localhost port through CORS
daphne -b 127.0.0.1 -p 8000 config.asgi:application

# app
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Build options (`--dart-define`):

| Name | Default | Meaning |
|---|---|---|
| `API_BASE_URL` | `http://localhost:8000` | Backend origin. The WebSocket URL is derived from it (`ws`/`wss`). |
| `APP_VERSION` | `1.0.0` | Shown in Account; compare with `min_supported_version` from `GET /app/config/`. |
| `MAP_TILE_URL` | OpenStreetMap | Map tiles. Swap for a Google Maps or other provider once you have a key. |

## Deploy the web app

The normal way is the production stack in [`deploy/`](../deploy/README.md). `app/Dockerfile` builds
this app into a Caddy image that also proxies the API on the same domain. Built with an empty
`API_BASE_URL`, the app calls whichever server it was loaded from, so the same image works on any domain.

To host the web app separately from the API instead:

```bash
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://api.kaamnow.pk
```

Serve `build/web/` from any static host (Nginx, Netlify, Firebase Hosting, S3 + CloudFront).
On the backend, add the app's origin to `CORS_ALLOWED_ORIGINS` (for example
`https://app.kaamnow.pk`). The same setting allows its WebSocket connections.

## Tests

```bash
flutter analyze
flutter test          # 52 unit and widget tests (API client, models, routing, key screens, admin dashboard, Urdu)
```

`e2e/` drives the real web build against a running backend in Chromium, through the whole job
from sign-up to payment, review and earnings, plus an admin walk-through and an Urdu walk-through. See `e2e/README.md`.

## Structure

```
lib/
  config.dart            build-time settings
  core/                  API client, token storage, session, booking WebSocket, GPS, checkout, formatting
  models/                typed models for every API payload
  api/kaamnow_api.dart   one method per endpoint
  ui/                    screens: auth, customer, worker, bookings, account, shared widgets
  app.dart               routes and role-based redirects
test/                    unit and widget tests with a scripted fake backend
e2e/                     Playwright browser run against the real backend
```

## Known limits

- **Maps** use OpenStreetMap tiles; the spec's Google Maps needs an API key. Swap `MAP_TILE_URL`
  (or `google_maps_flutter`) when you have one.
- **Push notifications**: the web app polls the unread count every 30 seconds. Firebase push is
  wired on the server and will be added to the mobile builds.
- **Online payments** open the gateway's hosted checkout in a new tab. The buttons stay disabled
  until JazzCash or Easypaisa credentials are configured on the server.
- **Live location** is shared while the worker has the booking page open (browsers do not allow
  background GPS). The mobile apps can share it in the background.
- Tokens are stored in browser local storage. Serve the app over HTTPS only.
