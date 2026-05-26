#!/usr/bin/env bash
# Factory override for .skills/wix-headless/scripts/scaffold.sh
# Uses --site-template blank and --skip-git per Wix CLI create-headless docs.
#
# Usage: bash scripts/scaffold.sh "<project-slug>" "<brand-name>"
set -euo pipefail

if [[ $# -lt 2 || -z "${1:-}" || -z "${2:-}" ]]; then
  echo "scaffold.sh: both args required. Got project-slug='${1:-}' brand-name='${2:-}'." >&2
  echo "Usage: bash scripts/scaffold.sh \"<slug>\" \"<brand>\" — slug first, brand quoted." >&2
  exit 2
fi

if [[ ! "$1" =~ ^[a-z0-9]{3,20}$ ]]; then
  echo "scaffold.sh: project-slug='$1' is not valid." >&2
  echo "Slug must be 3-20 lowercase alphanumeric chars (no hyphens, no spaces)." >&2
  exit 2
fi

if ! npx @wix/cli whoami >/dev/null 2>&1; then
  echo "scaffold.sh: not logged in to Wix CLI." >&2
  echo "Run 'npx @wix/cli login' and retry." >&2
  exit 3
fi

npm create @wix/new@latest headless -- \
  --business-name "$2" \
  --project-name "$1" \
  --site-template blank \
  --no-publish \
  --skip-install \
  --skip-git
