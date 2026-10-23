#!/usr/bin/env bash
# One-time server preparation for the landing: rsync, a deploy user that can only receive files
# into the site folder, nginx serving that folder instead of the stub.
# Usage, on the server from a copy of deploy/server with the deploy public key next to it:
#   sudo bash setup-landing.sh deploy-key.pub
# Safe to re-run; re-running with a new public key replaces the old one.
set -euo pipefail

PUBKEY_FILE="${1:?usage: sudo bash setup-landing.sh <deploy-key.pub>}"
DOMAIN="chigabugadaga.ru"
DEPLOY_USER="landing"
SITE_DIR="/var/www/landing"
HERE="$(cd "$(dirname "$0")" && pwd)"
LOG=/var/log/landing-setup.log

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo" >&2; exit 1; }

# The log is world-readable so the result can be checked without sudo.
touch "$LOG" && chmod 644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
trap 'echo "FAILED at line $LINENO" >&2' ERR

export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l
step() { printf '\n=== %s ===\n' "$*"; }

step "rsync"
if ! command -v rsync >/dev/null; then
  apt-get update -q
  apt-get install -y -q rsync
fi
# sed, not head: head exits early and pipefail would count rsync's broken pipe as a failure.
rsync --version | sed -n 1p
RRSYNC="$(command -v rrsync)" || { echo "rrsync not found" >&2; exit 1; }
echo "$RRSYNC"

step "Deploy user $DEPLOY_USER"
# No sudo, no docker: its only job is receiving the built site.
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "/home/$DEPLOY_USER" --shell /bin/bash "$DEPLOY_USER"
fi
# "*": no password to log in with, but not "locked", so SSH keys still work.
usermod -p '*' "$DEPLOY_USER"
id "$DEPLOY_USER"

step "Deploy key"
ssh-keygen -lf "$PUBKEY_FILE"
[ "$(grep -c . "$PUBKEY_FILE")" -eq 1 ] || { echo "Expected exactly one public key" >&2; exit 1; }
# The key can only run rrsync, which writes into the site folder and nothing else.
# root owns the key file, so the deploy user cannot change it.
install -d -m 755 -o root -g root "/home/$DEPLOY_USER/.ssh"
printf 'restrict,command="%s -wo %s" %s\n' "$RRSYNC" "$SITE_DIR" "$(cat "$PUBKEY_FILE")" \
  > "/home/$DEPLOY_USER/.ssh/authorized_keys"
chown root:root "/home/$DEPLOY_USER/.ssh/authorized_keys"
chmod 644 "/home/$DEPLOY_USER/.ssh/authorized_keys"

step "Site folder $SITE_DIR"
install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$SITE_DIR"
# Until the first deploy the folder shows a copy of the stub; /var/www/stub itself is left as is.
if [ -z "$(ls -A "$SITE_DIR")" ]; then
  install -m 644 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /var/www/stub/index.html "$SITE_DIR/index.html"
fi
ls -la "$SITE_DIR"

step "nginx serves $SITE_DIR for $DOMAIN"
conf="/etc/nginx/sites-available/$DOMAIN.conf"
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

step "Check"
curl -sS -o /dev/null -w "https://$DOMAIN/ -> %{http_code}\n" "https://$DOMAIN/"
echo
echo "DONE. Log: $LOG"
