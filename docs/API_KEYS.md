# Keys, accounts and settings to add later

Everything KaamNow needs from outside services, in one place. The app runs without any of them.
Each one switches a feature on. Nothing here needs code changes; you only paste values in.

Values go in three places:

- **Server `.env`**: `deploy/.env` on the server (created by `deploy/new-env.sh`). After editing,
  run `docker compose up -d`.
- **GitHub variables**: repository **Settings → Secrets and variables → Actions → Variables**.
  Used when GitHub builds the Android and iPhone apps.
- **GitHub secrets**: same page, **Secrets** tab. For passwords that must stay hidden.

## 1. Already done for you (no action)

`deploy/new-env.sh kaamnow.pk you@example.com` fills these with fresh random values:

| `.env` | What it is |
|---|---|
| `DJANGO_SECRET_KEY` | Signs logins and sessions |
| `POSTGRES_PASSWORD` | Database password |
| `WEBPUSH_VAPID_PUBLIC_KEY`, `WEBPUSH_VAPID_PRIVATE_KEY` | Browser notifications on the website (free, no account) |

## 2. Needed to go live

| What | Cost | Where it goes | Values |
|---|---|---|---|
| **Domain and server** | Paid (domain about Rs 3,000 a year; a small VPS about Rs 1,500 to 3,000 a month) | Server `.env` | `DOMAIN` (e.g. `kaamnow.pk`), `ACME_EMAIL` (your email, for the free HTTPS certificate), `SITE_ADDRESS` (leave empty; set only to serve several names such as `kaamnow.pk, www.kaamnow.pk`) |
| **Email (SMTP)** for password-reset emails | Free tier (Brevo 300 a day, Zoho Mail, Mailgun) or Amazon SES (very cheap) | Server `.env` | `EMAIL_HOST`, `EMAIL_PORT` (587), `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `EMAIL_USE_TLS=true`, `DEFAULT_FROM_EMAIL` |
| **Support contact** shown in the app | Free | Server `.env` | `SUPPORT_EMAIL`, `SUPPORT_PHONE` |

## 3. Features that need an account

| Feature | Service | Cost | Where it goes | Values | Without it |
|---|---|---|---|---|---|
| **Online payments: JazzCash** | JazzCash merchant account (apply as a business) | Free to open; a fee per transaction (about 1.5 to 2.5%) | Server `.env` | `JAZZCASH_MERCHANT_ID`, `JAZZCASH_PASSWORD`, `JAZZCASH_INTEGRITY_SALT`; at go-live also `JAZZCASH_CHECKOUT_URL` (live URL from JazzCash) | Customers pay cash only; the JazzCash button is disabled |
| **Online payments: Easypaisa** | Easypaisa merchant account | Free to open; a fee per transaction | Server `.env` | `EASYPAISA_STORE_ID`, `EASYPAISA_HASH_KEY`, `EASYPAISA_USERNAME`, `EASYPAISA_PASSWORD`, `EASYPAISA_ACCOUNT_NUM`; at go-live also `EASYPAISA_CHECKOUT_URL` and `EASYPAISA_INQUIRY_URL` (live URLs) | Same, for Easypaisa |
| **SMS codes** (confirm phone numbers, "Forgot password" by SMS) | Twilio | **Paid** per SMS (about US$0.10 to 0.30 each to Pakistan); a free trial only texts your own number | Server `.env` | `SMS_BACKEND=twilio`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_FROM` (a Twilio number, or an approved sender ID like `KaamNow`) | No phone confirmation; password reset by email only |
| **Push notifications in the Android and iPhone apps** | Firebase (Google) | Free | Server `.env` and file | `FCM_PROJECT_ID`, `FCM_CREDENTIALS_FILE=/run/secrets/firebase.json`, plus the service-account key file at `deploy/secrets/firebase.json` | Phone apps show alerts only while open |
| | | | GitHub variables | `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`, `FIREBASE_SENDER_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID` | |
| **Google Maps** | Google Cloud (Maps JavaScript API, Maps SDK for Android, Maps SDK for iOS) | Free monthly allowance (enough for a small app); billing must be turned on | Server `.env` | `GOOGLE_MAPS_BROWSER_KEY` (website key, restricted to your domain) | OpenStreetMap is used instead (free, works fine) |
| | | | GitHub variable | `GOOGLE_MAPS_API_KEY` (app key, restricted to `pk.kaamnow.app`) | |
| **Play Store** (publish the Android app) | Google Play Console | **Paid**: US$25 once | GitHub secrets | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (your upload key, see `app/README.md`) | The APK still installs directly on phones |
| **App Store** (publish the iPhone app, and iPhone push) | Apple Developer Program | **Paid**: US$99 a year | Xcode on a Mac; APNs key uploaded to Firebase | Team ID, an APNs `.p8` key (for push) | The iPhone app can't be installed on phones |

## 4. GitHub settings for builds and deploying

| Name | Type | What it is | Needed? |
|---|---|---|---|
| `ANDROID_API_URL` | Variable | Server the Android app talks to, e.g. `https://kaamnow.pk` | Yes, once the server is live (default `https://kaamnow.pk`) |
| `IOS_API_URL` | Variable | Same for the iPhone app (defaults to `ANDROID_API_URL`) | Optional |
| `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_PATH` | Variables | Server address, SSH user and folder, for automatic deploys after each merge | Optional (you can deploy by hand) |
| `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS` | Secrets | SSH private key and the server's host key for automatic deploys | Optional, with the three above |
| Firebase, Google Maps, Android signing | | See section 3 | Optional |

## 5. Optional server settings (defaults are fine)

You can change these in the server `.env` if you need to. Admins change commission, the emergency fee,
minimum payout, commission debt limit, invite rewards and the discount cap from the admin dashboard instead.

| `.env` | Default | What it does |
|---|---|---|
| `PHONE_VERIFICATION_REQUIRED` | On when real SMS is set up | Users confirm their number before posting jobs or sending offers |
| `DEFAULT_COMMISSION_PERCENT` | `10.00` | Starting commission (then changed in admin settings) |
| `MIN_OFFER_PRICE`, `MAX_OFFER_PRICE` | `100`, `1000000` | Allowed offer range in rupees |
| `ONLINE_PAYMENT_TTL_MINUTES` | `30` | How long an online checkout stays open |
| `INVITE_URL` | `https://<DOMAIN>/#/register?ref={code}` (set by Docker Compose) | The invite link people share; `{code}` is replaced with their invite code |
| `MIN_ANDROID_VERSION`, `MIN_IOS_VERSION`, `MIN_WEB_VERSION` | `1.0.0` | Older apps are asked to update |
| `BACKUP_KEEP_DAYS` | `14` | Days of daily database backups to keep |
| `LOG_LEVEL` | `INFO` | Server log detail |
| `THROTTLE_*` | See `.env.example` | Request rate limits |

## Summary: what costs money

- **Required:** domain and server.
- **Pay as you go:** Twilio SMS (per message), and JazzCash and Easypaisa (per transaction fee).
- **One-time or yearly:** Play Store US$25 once, Apple US$99 a year.
- **Free:** Firebase push, browser push, email (free tiers), Google Maps (within the free allowance), OpenStreetMap.
