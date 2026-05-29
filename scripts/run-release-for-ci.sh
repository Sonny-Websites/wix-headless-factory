#!/usr/bin/env bash
# Run release-to-wix.sh and set the release_url job output (deploy workflow).
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL_FILE="$(mktemp)"
trap 'rm -f "$URL_FILE"' EXIT

bash "$SCRIPTS_DIR/release-to-wix.sh" >"$URL_FILE"

RELEASE_URL="$(tail -n 1 "$URL_FILE" | tr -d '\n\r')"
if [[ ! "$RELEASE_URL" =~ ^https:// ]]; then
  echo "run-release-for-ci.sh: stdout did not end with a URL" >&2
  cat "$URL_FILE" >&2
  exit 1
fi

bash "$SCRIPTS_DIR/ci-set-output.sh" release_url "$RELEASE_URL"
echo "Released to: $RELEASE_URL" >&2
