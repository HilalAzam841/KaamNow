#!/bin/sh
# One-time setup for a fresh Ubuntu 22.04/24.04 server. Run as root:
#   curl -fsSL https://raw.githubusercontent.com/<you>/kaamnow/main/deploy/setup-server.sh | sh
# or copy this file over and run `sh setup-server.sh`.
# Installs Docker, opens only SSH/HTTP/HTTPS, adds swap on small servers, and turns on
# automatic security updates.
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo sh setup-server.sh)" >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl git ufw unattended-upgrades openssl

if ! command -v docker >/dev/null 2>&1; then
  # Docker's official convenience script (installs Docker Engine and the compose plugin).
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable

# Flutter and Docker builds need memory; give 1-2 GB servers some swap.
if [ ! -e /swapfile ] && [ "$(awk '/MemTotal/ {print $2}' /proc/meminfo)" -lt 3000000 ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

dpkg-reconfigure -f noninteractive unattended-upgrades
mkdir -p /opt/kaamnow
echo "Server ready. Next: put the repository (or just the deploy/ folder) in /opt/kaamnow."
