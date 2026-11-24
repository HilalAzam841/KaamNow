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

Admins use the backend's admin API and Django admin; an admin who logs in here gets a notice.

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

```bash
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://api.kaamnow.pk
```

Serve `build/web/` from any static host (Nginx, Netlify, Firebase Hosting, S3 + CloudFront).
On the backend, add the app's origin to `CORS_ALLOWED_ORIGINS` (for example
`https://app.kaamnow.pk`). The same setting allows its WebSocket connections.

## Tests

```bash
flutter analyze
flutter test          # 31 unit and widget tests (API client, models, routing, key screens)
```

`e2e/` drives the real web build against a running backend in Chromium, through the whole job
from sign-up to payment, review and earnings. See `e2e/README.md`.

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
