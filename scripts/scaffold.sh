#!/usr/bin/env bash
# Factory override for .skills/wix-headless/scripts/scaffold.sh
# Uses --site-template blank and --skip-git per Wix CLI create-headless docs.
# Always scaffolds into ./site/ (WIX_PROJECT_DIR) for a deterministic layout.
#
# Usage: bash scripts/scaffold.sh "<brand-name>"
set -euo pipefail

PROJECT_DIR="${WIX_PROJECT_DIR:-site}"

if [[ $# -ne 1 || -z "${1:-}" ]]; then
  echo "scaffold.sh: brand name required." >&2
  echo "Usage: bash scripts/scaffold.sh \"<brand>\"" >&2
  exit 2
fi

BRAND="$1"

if [[ ! "$PROJECT_DIR" =~ ^[a-z0-9]{3,20}$ ]]; then
  echo "scaffold.sh: WIX_PROJECT_DIR='$PROJECT_DIR' is not valid (3-20 lowercase alnum)." >&2
  exit 2
fi

if ! npx @wix/cli whoami >/dev/null 2>&1; then
  echo "scaffold.sh: not logged in to Wix CLI." >&2
  echo "Run 'npx @wix/cli login' and retry." >&2
  exit 3
fi

npm create @wix/new@latest headless -- \
  --business-name "$BRAND" \
  --project-name "$PROJECT_DIR" \
  --site-template blank \
  --no-publish \
  --skip-install \
  --skip-git
