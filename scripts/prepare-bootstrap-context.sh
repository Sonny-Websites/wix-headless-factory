#!/usr/bin/env bash
# Write .github/codex/.bootstrap-context.json from workflow inputs / env.
set -euo pipefail

SITE_NAME="${SITE_NAME:?SITE_NAME is required}"
SITE_PROMPT="${SITE_PROMPT:?SITE_PROMPT is required}"
TRIGGERED_BY="${TRIGGERED_BY:-github-actions}"
RUN_ID="${RUN_ID:-local}"
PROJECT_DIR="${WIX_PROJECT_DIR:-site}"

# Derive slug from site name (matches wix-headless DISCOVERY.md)
SLUG="$(echo "$SITE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9' | cut -c1-20)"

if [[ ! "$SLUG" =~ ^[a-z0-9]{3,20}$ ]]; then
  echo "prepare-bootstrap-context.sh: invalid slug '$SLUG' derived from site name (need 3-20 lowercase alnum)" >&2
  exit 1
fi

mkdir -p .github/codex

export SITE_NAME SITE_PROMPT SLUG TRIGGERED_BY RUN_ID PROJECT_DIR

node --input-type=module - <<'EOF'
import { writeFileSync } from 'node:fs';

const context = {
  siteName: process.env.SITE_NAME,
  sitePrompt: process.env.SITE_PROMPT,
  slug: process.env.SLUG,
  projectDir: process.env.PROJECT_DIR,
  ci: true,
  triggeredBy: process.env.TRIGGERED_BY,
  runId: process.env.RUN_ID,
  skillRoot: '.skills/wix-headless',
  skillEntry: '.skills/wix-headless/SKILL.md',
};

writeFileSync('.github/codex/.bootstrap-context.json', JSON.stringify(context, null, 2) + '\n');
console.log('Wrote .github/codex/.bootstrap-context.json');
console.log(JSON.stringify(context, null, 2));
EOF

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "PROJECT_DIR=$PROJECT_DIR" >> "$GITHUB_ENV"
  echo "WIX_PROJECT_DIR=$PROJECT_DIR" >> "$GITHUB_ENV"
fi
