#!/usr/bin/env bash
# Run preview-to-wix.sh and set the preview_url job output (bootstrap + edit workflows).
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL_FILE="$(mktemp)"
trap 'rm -f "$URL_FILE"' EXIT

bash "$SCRIPTS_DIR/preview-to-wix.sh" >"$URL_FILE"

PREVIEW_URL="$(tail -n 1 "$URL_FILE" | tr -d '\n\r')"
if [[ ! "$PREVIEW_URL" =~ ^https:// ]]; then
  echo "run-preview-for-ci.sh: stdout did not end with a URL" >&2
  cat "$URL_FILE" >&2
  exit 1
fi

bash "$SCRIPTS_DIR/ci-set-output.sh" preview_url "$PREVIEW_URL"
echo "Preview URL: $PREVIEW_URL" >&2
