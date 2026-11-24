#!/bin/sh
# Creates deploy/.env from .env.example with fresh random secrets.
# Usage: ./new-env.sh <domain> <email-for-certificates>
set -eu
cd "$(dirname "$0")"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <domain> <email>   e.g. $0 kaamnow.pk you@example.com" >&2
  exit 1
fi
if [ -e .env ]; then
  echo ".env already exists. Edit it by hand; this script never overwrites secrets." >&2
  exit 1
fi

secret() { openssl rand -base64 48 | tr -d '\n/+=' | cut -c1-"$1"; }
b64url() { base64 | tr '+/' '-_' | tr -d '=\n'; }

# VAPID key pair for browser push notifications (P-256; raw public point and private scalar).
vapid_pem=$(mktemp)
openssl ecparam -name prime256v1 -genkey -noout -out "$vapid_pem"
VAPID_PUBLIC=$(openssl ec -in "$vapid_pem" -pubout -outform DER 2>/dev/null | tail -c 65 | b64url)
VAPID_PRIVATE=$(openssl ec -in "$vapid_pem" -outform DER 2>/dev/null | head -c 39 | tail -c 32 | b64url)
rm -f "$vapid_pem"

umask 077
sed -e "s|^DOMAIN=.*|DOMAIN=$1|" \
    -e "s|^ACME_EMAIL=.*|ACME_EMAIL=$2|" \
    -e "s|^DJANGO_SECRET_KEY=.*|DJANGO_SECRET_KEY=$(secret 60)|" \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(secret 32)|" \
    -e "s|^WEBPUSH_VAPID_PUBLIC_KEY=.*|WEBPUSH_VAPID_PUBLIC_KEY=$VAPID_PUBLIC|" \
    -e "s|^WEBPUSH_VAPID_PRIVATE_KEY=.*|WEBPUSH_VAPID_PRIVATE_KEY=$VAPID_PRIVATE|" \
    .env.example > .env
echo "Wrote deploy/.env for https://$1 (readable only by you). Add SMTP settings before launch."
