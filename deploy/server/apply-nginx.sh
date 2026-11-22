#!/usr/bin/env bash
# Installs only the landing nginx config and reloads nginx. If the config test fails,
# the previous config is restored. Safe to re-run.
# Usage, on the server, from a copy of deploy/server:  sudo bash apply-nginx.sh
set -euo pipefail

DOMAIN="chigabugadaga.ru"
HERE="$(cd "$(dirname "$0")" && pwd)"
conf="/etc/nginx/sites-available/$DOMAIN.conf"

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo" >&2; exit 1; }

previous="$(mktemp)"
cp "$conf" "$previous"
install -m 644 "$HERE/nginx/$DOMAIN.conf" "$conf"
if ! nginx -t; then
  cp "$previous" "$conf"
  echo "nginx config test failed, the previous config is restored" >&2
  exit 1
fi
rm -f "$previous"
ln -sf "$conf" "/etc/nginx/sites-enabled/$DOMAIN.conf"
systemctl reload nginx
curl -sSI "https://$DOMAIN/" | sed -n '1,/^\r$/p'
