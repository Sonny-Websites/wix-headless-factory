#!/usr/bin/env bash
# Ensure WIX_CLIENT_ID is available before @wix/cli build.
# .env.local is gitignored; CI must pull project env vars from Wix after login.
set -euo pipefail

wix_client_id_present() {
  if [[ -n "${WIX_CLIENT_ID:-}" ]]; then
    return 0
  fi
  if [[ -f .env.local ]] && grep -qE '^[[:space:]]*WIX_CLIENT_ID[[:space:]]*=' .env.local 2>/dev/null; then
    return 0
  fi
  return 1
}

if wix_client_id_present; then
  echo "ensure-wix-env.sh: WIX_CLIENT_ID already available" >&2
  exit 0
fi

echo "ensure-wix-env.sh: pulling environment variables from Wix…" >&2
npx @wix/cli env pull >&2

if wix_client_id_present; then
  echo "ensure-wix-env.sh: WIX_CLIENT_ID ready" >&2
  exit 0
fi

echo "ensure-wix-env.sh: WIX_CLIENT_ID still missing after env pull" >&2
echo "Ensure the Wix Headless project is linked (wix.config.json) and env vars exist on the site." >&2
exit 1
