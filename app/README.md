# KaamNow app (Flutter)

The customer and worker app for KaamNow. The same code runs on the **web**, as an **Android
app** and as an **iPhone app**. It
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

### Install on the home screen

KaamNow is an installable web app (PWA). On Android and in desktop Chrome or Edge, an
"Install KaamNow" card on the home screen (and an Install app row on the account screen) installs
it with one tap; on iPhone it explains Safari's Share, then "Add to Home Screen". The installed
app opens full screen with its own icon. `web/sw.js` keeps a copy of the app files for poor
connections and shows `web/offline.html` with no connection; it never stores API, WebSocket or
media responses. Installing needs HTTPS (or `localhost` while developing).

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

## Android app

GitHub builds the APK on every pull request and push to `main` (workflow `android`). Open the run
under **Actions**, then download **kaamnow-android** from its Artifacts and install the `.apk` on
a phone (Android 7 or newer; allow installing from your browser or file manager when asked).

The APK talks to the server in the repository variable `ANDROID_API_URL` (default
`https://kaamnow.pk`). Release builds only use https.

To build it yourself you need the Android SDK (Android Studio installs it):

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://kaamnow.pk
# app at build/app/outputs/flutter-apk/app-release.apk
```

**Signing for the Play Store.** Without a key the APK is signed with a test key, which is fine for
installing directly but not for the Play Store. Create a key once and keep it safe (losing it
means you cannot update the app):

```bash
keytool -genkey -v -keystore kaamnow.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kaamnow
```

Then either put `storeFile`, `storePassword`, `keyAlias` and `keyPassword` in `android/key.properties`
(never committed), or add the GitHub secrets `ANDROID_KEYSTORE_BASE64` (`base64 -w0 kaamnow.jks`),
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. For the Play Store,
build an app bundle with `flutter build appbundle` instead of an APK.

What differs from the web app: online payments open the gateway page inside the app, the
"Install" and browser-notification options are hidden, and sign-in tokens are kept out of phone
backups. Package name: `pk.kaamnow.app`.

`integration_test/app_test.dart` runs the real app on an emulator against a real backend with the
demo accounts (GitHub does this on every pull request and saves screenshots as
**android-screenshots**):

```bash
python manage.py seed_demo_data && daphne -b 0.0.0.0 -p 8000 config.asgi:application  # repo root, DJANGO_ALLOWED_HOSTS including 10.0.2.2
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## iPhone app

GitHub builds the iPhone app on a Mac on every pull request and push to `main` (workflow `ios`) and
runs it on an iPhone simulator against a real backend with the demo accounts (screenshots under
**iphone-screenshots**). Bundle id `pk.kaamnow.app`, iOS 15 or newer, portrait only. It talks to the
server in the repository variable `IOS_API_URL` (or `ANDROID_API_URL`, default `https://kaamnow.pk`).

Unlike Android, an iPhone app cannot be installed from a downloaded file. To put it on phones:

1. Join the [Apple Developer Program](https://developer.apple.com/programs/) (99 USD a year).
2. On a Mac with Xcode: `flutter build ipa --release --dart-define=API_BASE_URL=https://kaamnow.pk`,
   then open `ios/Runner.xcworkspace`, choose your team under Signing & Capabilities, and upload the
   build from Xcode's Organizer (or with Apple's Transporter app).
3. Testers install it through **TestFlight**; after Apple's review it can go on the App Store.

Same as Android: payments open the gateway page inside the app, the browser-only options are hidden,
and push notifications come with Firebase (which also delivers to iPhones through Apple's service).
The location, camera and photo permission prompts explain why the app asks.

## Tests

```bash
flutter analyze
flutter test          # 71 unit and widget tests (API client, models, routing, key screens, admin dashboard, Urdu, install, notifications, Android checkout, phone confirmation)
```

`e2e/` drives the real web build against a running backend in Chromium, through the whole job
from sign-up to payment, review and earnings, plus an admin walk-through, an Urdu walk-through and an installable-app check (`pwa.js`). See `e2e/README.md`.

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
- **Push notifications** need the server's VAPID keys and HTTPS. On iPhone they work only after the
  app is added to the home screen (iOS 16.4+). The Android app gets push once Firebase is set up
  (the server side is ready); until then it shows alerts inside the app. The in-app alert count
  refreshes every 30 seconds.
- **Online payments** open the gateway's hosted checkout in a new tab (inside the app on Android). The buttons stay disabled
  until JazzCash or Easypaisa credentials are configured on the server.
- **Live location** is shared while the worker has the booking page open, on the web and on Android.
  Background sharing would need a background-location permission and a Play Store review.
- Admins can preview worker documents (PDF) on the web dashboard only.
- On the web, tokens are stored in browser local storage. Serve the app over HTTPS only.
