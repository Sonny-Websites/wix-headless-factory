#!/usr/bin/env bash
# Build and create a Wix preview URL for the headless project.
# See https://dev.wix.com/docs/wix-cli/command-reference/project-commands/preview
set -euo pipefail

WIX_PROJECT_DIR="${WIX_PROJECT_DIR:-site}"
PROJECT_DIR="${PROJECT_DIR:-$WIX_PROJECT_DIR}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_JSON="${RUN_JSON:-$REPO_ROOT/.wix/run.json}"

if [[ ! -f "$PROJECT_DIR/wix.config.json" ]] && [[ "$PROJECT_DIR" == "." ]] && [[ -f "${WIX_PROJECT_DIR}/wix.config.json" ]]; then
  PROJECT_DIR="$WIX_PROJECT_DIR"
fi

if [[ ! -f "$PROJECT_DIR/wix.config.json" ]]; then
  echo "preview-to-wix.sh: wix.config.json not found in $PROJECT_DIR" >&2
  exit 1
fi

cd "$PROJECT_DIR"

bash "$(dirname "$0")/verify-wix-auth.sh"

echo "Building…"
npx @wix/cli build 1>&2

PREVIEW_OUTPUT="$(mktemp)"
trap 'rm -f "$PREVIEW_OUTPUT"' EXIT

set +e
npx @wix/cli preview 2>&1 | tee "$PREVIEW_OUTPUT" 1>&2
PREVIEW_STATUS=${PIPESTATUS[0]}
set -e

if [[ "$PREVIEW_STATUS" -ne 0 ]]; then
  exit "$PREVIEW_STATUS"
fi

PREVIEW_URL="$(grep -oE 'https://[A-Za-z0-9._~:/?#\[\]@!$&'"'"'()*+,;=%-]+' "$PREVIEW_OUTPUT" | grep -E 'wix|preview' | head -n 1 || true)"

if [[ -z "$PREVIEW_URL" ]]; then
  PREVIEW_URL="$(grep -oE 'https://[A-Za-z0-9._~:/?#\[\]@!$&'"'"'()*+,;=%-]+' "$PREVIEW_OUTPUT" | head -n 1 || true)"
fi

if [[ -z "$PREVIEW_URL" ]]; then
  echo "preview-to-wix.sh: could not extract preview URL from CLI output" >&2
  exit 1
fi

echo "$PREVIEW_URL"

export PREVIEW_URL RUN_JSON
if [[ -f "$RUN_JSON" ]]; then
  node --input-type=module - <<'EOF'
import { readFileSync, writeFileSync } from 'node:fs';

const runPath = process.env.RUN_JSON;
const previewUrl = process.env.PREVIEW_URL;
let run;
try {
  run = JSON.parse(readFileSync(runPath, 'utf8'));
} catch {
  run = { version: '1.0', run: {}, outcome: {}, phases: [] };
}
run.outcome = run.outcome || {};
run.outcome.previewUrl = previewUrl;
run.outcome.previewAt = new Date().toISOString();
writeFileSync(runPath, JSON.stringify(run, null, 2) + '\n');
console.log(`Updated ${runPath} with previewUrl`);
EOF
fi
