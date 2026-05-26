#!/usr/bin/env bash
# Build and release the Wix Headless project using @wix/cli on an authenticated runner.
# Mirrors dev.wix.com/skills/wix-headless/scripts/release.sh
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-.}"

if [[ ! -f "$PROJECT_DIR/wix.config.json" ]]; then
  echo "release-to-wix.sh: wix.config.json not found in $PROJECT_DIR" >&2
  exit 1
fi

cd "$PROJECT_DIR"

bash "$(dirname "$0")/verify-wix-auth.sh"

echo "Building…"
npx @wix/cli build 1>&2

RELEASE_OUTPUT="$(mktemp)"
trap 'rm -f "$RELEASE_OUTPUT"' EXIT

release_is_retryable() {
  grep -Eiq 'ECONNRESET|ETIMEDOUT|EAI_AGAIN|STATE_MISMATCH|temporary system error|temporarily unavailable|try again shortly' "$RELEASE_OUTPUT"
}

MAX_RELEASE_ATTEMPTS="${WIX_RELEASE_ATTEMPTS:-3}"
RELEASE_STATUS=1

for ((attempt = 1; attempt <= MAX_RELEASE_ATTEMPTS; attempt++)); do
  : >"$RELEASE_OUTPUT"
  set +e
  npx @wix/cli release 2>&1 | tee "$RELEASE_OUTPUT" 1>&2
  RELEASE_STATUS=${PIPESTATUS[0]}
  set -e

  if [[ "$RELEASE_STATUS" -eq 0 ]]; then
    break
  fi

  if [[ "$attempt" -lt "$MAX_RELEASE_ATTEMPTS" ]] && release_is_retryable; then
    sleep_seconds=$((attempt * 5))
    echo "release-to-wix.sh: retryable error; retrying in ${sleep_seconds}s" >&2
    sleep "$sleep_seconds"
    continue
  fi

  exit "$RELEASE_STATUS"
done

RELEASE_URL="$(sed -nE 's/.*Site published on ([^[:space:]]+).*/\1/p' "$RELEASE_OUTPUT" | head -n 1 || true)"
if [[ -z "$RELEASE_URL" ]]; then
  RELEASE_URL="$(grep -oE 'https://[A-Za-z0-9.-]+\.wix-(site-)?host\.com[^[:space:]]*' "$RELEASE_OUTPUT" | head -n 1 || true)"
fi

if [[ -z "$RELEASE_URL" ]]; then
  echo "release-to-wix.sh: could not extract release URL" >&2
  exit 1
fi

echo "$RELEASE_URL"

# Append release URL to run.json if present
export RELEASE_URL
if [[ -f .wix/run.json ]]; then
  node --input-type=module - <<'EOF'
import { readFileSync, writeFileSync } from 'node:fs';

const runPath = '.wix/run.json';
const releaseUrl = process.env.RELEASE_URL;
let run;
try {
  run = JSON.parse(readFileSync(runPath, 'utf8'));
} catch {
  run = { version: '1.0', run: {}, outcome: {}, phases: [] };
}
run.outcome = run.outcome || {};
run.outcome.releaseUrl = releaseUrl;
run.outcome.releasedAt = new Date().toISOString();
writeFileSync(runPath, JSON.stringify(run, null, 2) + '\n');
console.log('Updated .wix/run.json with releaseUrl');
EOF
fi
