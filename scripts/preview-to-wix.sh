#!/usr/bin/env bash
# Build and create a Wix preview URL for the headless project.
# See https://dev.wix.com/docs/wix-cli/command-reference/project-commands/preview
set -euo pipefail

WIX_PROJECT_DIR="${WIX_PROJECT_DIR:-site}"
PROJECT_DIR="${PROJECT_DIR:-$WIX_PROJECT_DIR}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
RUN_JSON="${RUN_JSON:-$REPO_ROOT/.wix/run.json}"

if [[ ! -f "$PROJECT_DIR/wix.config.json" ]] && [[ "$PROJECT_DIR" == "." ]] && [[ -f "${WIX_PROJECT_DIR}/wix.config.json" ]]; then
  PROJECT_DIR="$WIX_PROJECT_DIR"
fi

if [[ ! -f "$PROJECT_DIR/wix.config.json" ]]; then
  echo "preview-to-wix.sh: wix.config.json not found in $PROJECT_DIR" >&2
  exit 1
fi

cd "$PROJECT_DIR"

bash "$SCRIPTS_DIR/verify-wix-auth.sh"
bash "$SCRIPTS_DIR/ensure-wix-env.sh"

echo "Building…" >&2
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

# Strip ANSI and join wrapped lines (dashboard URL can break across lines).
PREVIEW_TEXT="$(sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$PREVIEW_OUTPUT" | tr '\n' ' ')"

# Wix CLI: "› Site (https://….wix-host.com)"
PREVIEW_URL="$(grep -oE 'Site \(https://[^)]+\)' <<<"$PREVIEW_TEXT" \
  | head -n 1 \
  | sed -E 's/^Site \((.*)\)$/\1/' || true)"

if [[ -z "$PREVIEW_URL" ]]; then
  PREVIEW_URL="$(grep -oE 'https://[A-Za-z0-9.-]+\.wix(-site)?-host\.com[^[:space:)]<>]*' <<<"$PREVIEW_TEXT" | head -n 1 || true)"
fi

if [[ -z "$PREVIEW_URL" ]]; then
  PREVIEW_URL="$(grep -oE 'https://[^[:space:])<>]+' <<<"$PREVIEW_TEXT" | grep -iE 'wix-host|preview\.' | head -n 1 || true)"
fi

if [[ -z "$PREVIEW_URL" ]]; then
  echo "preview-to-wix.sh: could not extract preview URL from CLI output" >&2
  sed -n '1,80p' "$PREVIEW_OUTPUT" >&2 || true
  exit 1
fi

export PREVIEW_URL RUN_JSON
if [[ -f "$RUN_JSON" ]]; then
  node --input-type=module - <<'EOF' >&2
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
console.error(`Updated ${runPath} with previewUrl`);
EOF
fi

# Stdout is only the URL (captured by CI for GITHUB_OUTPUT).
echo "$PREVIEW_URL"
