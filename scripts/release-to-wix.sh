#!/usr/bin/env bash
# Build and release the Wix Headless project using @wix/cli on an authenticated runner.
# Mirrors dev.wix.com/skills/wix-headless/scripts/release.sh
set -euo pipefail

WIX_PROJECT_DIR="${WIX_PROJECT_DIR:-site}"
PROJECT_DIR="${PROJECT_DIR:-$WIX_PROJECT_DIR}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
RUN_JSON="${RUN_JSON:-$REPO_ROOT/.wix/run.json}"

# Fall back to factory default when caller left PROJECT_DIR at repo root.
if [[ ! -f "$PROJECT_DIR/wix.config.json" ]] && [[ "$PROJECT_DIR" == "." ]] && [[ -f "${WIX_PROJECT_DIR}/wix.config.json" ]]; then
  PROJECT_DIR="$WIX_PROJECT_DIR"
fi

if [[ ! -f "$PROJECT_DIR/wix.config.json" ]]; then
  echo "release-to-wix.sh: wix.config.json not found in $PROJECT_DIR" >&2
  echo "release-to-wix.sh: factory scaffold writes ./${WIX_PROJECT_DIR}/wix.config.json — try PROJECT_DIR=${WIX_PROJECT_DIR}" >&2
  exit 1
fi

cd "$PROJECT_DIR"

bash "$SCRIPTS_DIR/verify-wix-auth.sh"
bash "$SCRIPTS_DIR/ensure-wix-env.sh"

echo "Building…" >&2
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

export RELEASE_URL RUN_JSON
if [[ -f "$RUN_JSON" ]]; then
  node --input-type=module - <<'EOF' >&2
import { readFileSync, writeFileSync } from 'node:fs';

const runPath = process.env.RUN_JSON;
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
console.error(`Updated ${runPath} with releaseUrl`);
EOF
fi

echo "$RELEASE_URL"
