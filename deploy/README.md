# Deploying KaamNow

Everything (the web app, admin dashboard, API, live tracking, chat, background jobs, database and
daily backups) runs on **one Linux server** with Docker. Caddy gets a free HTTPS certificate
for your domain automatically.

```
Internet ──► Caddy :443 ──► /             Flutter web app (customers, workers, /#/admin)
             (HTTPS)    ├─► /api, /ws     Django API (Daphne: HTTP + WebSockets)
                        ├─► /django-admin Django admin
                        └─► /media        job photos, avatars (CNIC documents are never served)
             API ─► PostgreSQL 16, Redis 7, Celery worker + beat
             backup job ─► deploy/backups/ every 24 h
```

## What you need

| | Notes |
|---|---|
| A server | Ubuntu 22.04 or 24.04, **2 GB RAM** or more, 40 GB disk. DigitalOcean, Hetzner, Vultr, Linode or AWS Lightsail all work (about $6 to $12 a month). |
| A domain | e.g. `kaamnow.pk`. Create an **A record** pointing at the server's IP address. |
| An email address | For Let's Encrypt certificate notices. |
| SMTP details | Recommended, so password-reset emails reach users. Brevo, Mailgun, Amazon SES or Zoho Mail all work. |

## First deployment (about 20 minutes)

**1. Prepare the server** (as root, once):

```bash
ssh root@YOUR_SERVER_IP
apt-get update && apt-get install -y git
git clone https://github.com/<you>/kaamnow.git /opt/kaamnow   # private repo: use a GitHub token or deploy key
sh /opt/kaamnow/deploy/setup-server.sh                         # Docker, firewall (22/80/443), swap, security updates
```

**2. Create the settings file** with fresh secrets:

```bash
cd /opt/kaamnow/deploy
./new-env.sh kaamnow.pk you@example.com
nano .env          # add SMTP settings and SUPPORT_EMAIL / SUPPORT_PHONE
```

**3. Start everything:**

```bash
docker compose up -d --build     # first build takes 5 to 10 minutes (it compiles the Flutter app)
docker compose ps                # every service should be "Up"; api shows "(healthy)"
```

Open `https://kaamnow.pk`. The first visit can take a few seconds while the certificate is issued.

**4. Create your admin account:**

```bash
docker compose exec api python manage.py createsuperuser
```

Log in on the website with that phone number and password to get the admin dashboard.
`https://kaamnow.pk/django-admin/` is also available for low-level edits.

## Updating

**By hand on the server:**

```bash
cd /opt/kaamnow && git pull
cd deploy && docker compose up -d --build
```

Database migrations run automatically before the API starts.

**Automatically on every merge to `main`** (optional): GitHub Actions already builds both images
on every push to `main` and publishes them to GitHub Container Registry. To let it deploy as well:

1. On the server, in `deploy/.env`, set `IMAGE_PREFIX=ghcr.io/<your-github-user-in-lowercase>/kaamnow`.
2. If the repository is private, let the server pull the images:
   `docker login ghcr.io -u <github-user>` with a token that has the `read:packages` scope.
3. Create an SSH key just for deploys, and add its public half to `~/.ssh/authorized_keys` on the server:
   `ssh-keygen -t ed25519 -f kaamnow_deploy -N ""`.
4. In GitHub, go to **Settings → Secrets and variables → Actions**:
   - Variables: `DEPLOY_HOST` = server IP or domain. Optionally `DEPLOY_USER` (default `root`) and `DEPLOY_PATH` (default `/opt/kaamnow`).
   - Secrets: `DEPLOY_SSH_KEY` = the private key file's contents. `DEPLOY_KNOWN_HOSTS` = the output of `ssh-keyscan YOUR_SERVER_IP`.

From then on, each merge to `main` builds, deploys and checks `https://<domain>/api/v1/health/`.
Until `DEPLOY_HOST` is set, the deploy step is skipped.

**Rolling back:** set `TAG=` in `deploy/.env` to an earlier commit SHA (or `latest`), then run
`docker compose up -d`.

## Backups

The `backup` service writes three files to `/opt/kaamnow/deploy/backups/` every 24 hours: a database
dump, the CNIC documents, and the public uploads. It keeps 14 days (`BACKUP_KEEP_DAYS`). The files
are readable only by root.

- Run one now: `docker compose exec backup sh /usr/local/bin/kaamnow-backup`
- **Copy them off the server.** A backup on the same disk does not survive losing the server.
  For example, set up a nightly `rclone copy /opt/kaamnow/deploy/backups remote:kaamnow-backups` to
  Backblaze B2 or S3 with encryption turned on. The CNIC archives contain identity documents.
- Restore the database (stops the app briefly):

  ```bash
  docker compose stop api worker beat
  docker compose exec backup sh -c 'pg_restore --clean --if-exists --no-owner -d "$PGDATABASE" /backups/db-YYYYMMDD-HHMMSS.dump'
  docker compose start api worker beat
  ```

- Restore files: `docker compose run --rm --entrypoint tar -v kaamnow_private_media:/restore backup -xzf /backups/private-media-YYYYMMDD-HHMMSS.tar.gz -C /restore`
  (use `kaamnow_media` and the `media-...tar.gz` file for public uploads).

## Day-to-day commands

| Task | Command (in `/opt/kaamnow/deploy`) |
|---|---|
| Status | `docker compose ps` |
| Logs | `docker compose logs -f api` (or `web`, `worker`, `beat`, `backup`) |
| Restart | `docker compose restart api` |
| Django shell | `docker compose exec api python manage.py shell` |
| Security self-check | `docker compose exec api python manage.py check --deploy` |
| Stop everything | `docker compose down` (data stays in Docker volumes) |

## Turning on payments and push notifications later

- **JazzCash / Easypaisa:** fill in the merchant values in `deploy/.env` and run `docker compose up -d`.
  The callback URLs default to `https://<domain>/api/v1/payments/callbacks/jazzcash/` and `.../easypaisa/`.
  Register those with each gateway, and do one sandbox payment per gateway before going live
  (see the main README, section 8).
- **Firebase push:** put the service-account key at `deploy/secrets/firebase.json`, uncomment its line in
  `docker-compose.yml`, set `FCM_PROJECT_ID` and `FCM_CREDENTIALS_FILE=/run/secrets/firebase.json`, then `docker compose up -d`.

## Trying the production stack on your own computer

Use `localhost` as the domain. Caddy then uses its own local certificate (your browser will warn
about it):

```bash
cd deploy && ./new-env.sh localhost you@example.com
printf 'SITE_ADDRESS=localhost\nHTTP_PORT=8180\nHTTPS_PORT=8443\nEMAIL_BACKEND=django.core.mail.backends.console.EmailBackend\n' >> .env
docker compose up -d --build     # then open https://localhost:8443
```

## Security notes

- Only ports 22, 80 and 443 are open. PostgreSQL, Redis and the API are reachable only inside Docker's network.
- `deploy/.env` holds every secret. `new-env.sh` creates it readable only by its owner, and git ignores it.
- CNIC documents live in the `private_media` volume. Caddy never mounts it, so no URL can reach them.
  Admins download them through the API, and each view is audit-logged.
- HTTPS everywhere: HTTP redirects to HTTPS, HSTS is on, and cookies are secure-only.
- Logs rotate (5 × 10 MB per service), so they cannot fill the disk.
