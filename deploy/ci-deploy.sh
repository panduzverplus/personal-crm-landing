#!/usr/bin/env bash
# Runs on the GitHub Actions runner after the build: uploads dist/ to the server,
# then checks that the home page answers 200 and is exactly the page just built.
set -euo pipefail

: "${DEPLOY_HOST:?}" "${DEPLOY_USER:?}" "${DEPLOY_KNOWN_HOSTS:?}" "${DEPLOY_SSH_KEY:?}" "${SITE_URL:?}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

(
  umask 077
  printf '%s\n' "$DEPLOY_SSH_KEY" > "$tmp/key"
  printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > "$tmp/known_hosts"
)
ssh_cmd="ssh -i $tmp/key -o IdentitiesOnly=yes -o BatchMode=yes"
ssh_cmd+=" -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$tmp/known_hosts"

# The key only runs rrsync locked to /var/www/landing, so the empty target path means that folder.
# --delay-updates and --delete-after: new files show up together at the end, old ones are removed last.
rsync -rlpt --chmod=D755,F644 --delete-after --delay-updates --stats \
  -e "$ssh_cmd" dist/ "$DEPLOY_USER@$DEPLOY_HOST:"

code="$(curl -sS --retry 3 -o "$tmp/index.html" -w '%{http_code}' "$SITE_URL")"
echo "$SITE_URL -> $code"
[ "$code" = 200 ] || { echo "The home page did not answer 200" >&2; exit 1; }
cmp -s "$tmp/index.html" dist/index.html || { echo "The home page is not this build" >&2; exit 1; }
echo "The home page is this build (dist/index.html)"
