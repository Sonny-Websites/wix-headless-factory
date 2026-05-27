#!/usr/bin/env bash
# Authenticate Wix CLI for CI (API key) or verify an existing local session.
set -euo pipefail

wix_cli_authenticated() {
  npx @wix/cli whoami >/dev/null 2>&1
}

if wix_cli_authenticated; then
  echo "verify-wix-auth.sh: Wix CLI session is active" >&2
  npx @wix/cli whoami >&2
  exit 0
fi

if [[ -n "${WIX_CLI_API_KEY:-}" ]]; then
  echo "verify-wix-auth.sh: logging in with WIX_CLI_API_KEY…" >&2
  npx @wix/cli login --api-key "$WIX_CLI_API_KEY"
  if wix_cli_authenticated; then
    echo "verify-wix-auth.sh: authenticated via API key" >&2
    npx @wix/cli whoami >&2
    exit 0
  fi
  echo "verify-wix-auth.sh: login --api-key succeeded but whoami still fails" >&2
  exit 1
fi

echo "verify-wix-auth.sh: Wix CLI is not authenticated." >&2
echo "" >&2
echo "In CI, set the GitHub secret WIX_CLI_API_KEY and grant the key permissions" >&2
echo "for Wix CLI operations (start with Wix CLI - Git Integration; add Stores/CMS" >&2
echo "permissions if bootstrap installs apps or seeds content)." >&2
echo "" >&2
echo "Generate a key: https://manage.wix.com/account/api-keys" >&2
echo "Docs: https://dev.wix.com/docs/wix-cli/command-reference/global-commands/login.md" >&2
echo "" >&2
echo "Locally, either export WIX_CLI_API_KEY or run: npx @wix/cli login" >&2
exit 1
