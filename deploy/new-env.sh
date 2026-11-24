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

umask 077
sed -e "s|^DOMAIN=.*|DOMAIN=$1|" \
    -e "s|^ACME_EMAIL=.*|ACME_EMAIL=$2|" \
    -e "s|^DJANGO_SECRET_KEY=.*|DJANGO_SECRET_KEY=$(secret 60)|" \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(secret 32)|" \
    .env.example > .env
echo "Wrote deploy/.env for https://$1 (readable only by you). Add SMTP settings before launch."
