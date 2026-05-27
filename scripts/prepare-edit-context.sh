#!/usr/bin/env bash
# Write .github/codex/.edit-context.json from workflow inputs / env.
set -euo pipefail

EDIT_PROMPT="${EDIT_PROMPT:?EDIT_PROMPT is required}"
TRIGGERED_BY="${TRIGGERED_BY:-github-actions}"
RUN_ID="${RUN_ID:-local}"
PROJECT_DIR="${WIX_PROJECT_DIR:-site}"

if [[ ! -f "${PROJECT_DIR}/wix.config.json" ]]; then
  echo "prepare-edit-context.sh: ${PROJECT_DIR}/wix.config.json not found — bootstrap the site first." >&2
  exit 1
fi

mkdir -p .github/codex

export EDIT_PROMPT TRIGGERED_BY RUN_ID PROJECT_DIR

node --input-type=module - <<'EOF'
import { writeFileSync } from 'node:fs';

const context = {
  editPrompt: process.env.EDIT_PROMPT,
  projectDir: process.env.PROJECT_DIR,
  ci: true,
  triggeredBy: process.env.TRIGGERED_BY,
  runId: process.env.RUN_ID,
  skillRoot: '.skills/wix-headless',
  skillEntry: '.skills/wix-headless/SKILL.md',
};

writeFileSync('.github/codex/.edit-context.json', JSON.stringify(context, null, 2) + '\n');
console.log('Wrote .github/codex/.edit-context.json');
console.log(JSON.stringify(context, null, 2));
EOF

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "PROJECT_DIR=$PROJECT_DIR" >> "$GITHUB_ENV"
  echo "WIX_PROJECT_DIR=$PROJECT_DIR" >> "$GITHUB_ENV"
fi
