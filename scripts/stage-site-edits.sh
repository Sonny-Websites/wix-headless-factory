#!/usr/bin/env bash
# Stage Codex site edits for peter-evans/create-pull-request (excludes ephemeral paths).
set -euo pipefail

if [[ -z "$(git status --porcelain)" ]]; then
  echo "stage-site-edits.sh: no changes to stage"
  exit 0
fi

git add -A
git reset -q .github/codex/.bootstrap-context.json 2>/dev/null || true
git reset -q .github/codex/.edit-context.json 2>/dev/null || true
git reset -q .github/codex/config.toml 2>/dev/null || true
git reset -q .github/codex/*.json 2>/dev/null || true
git reset -q .github/codex/sessions/ 2>/dev/null || true
git reset -q .skills/ 2>/dev/null || true
git reset -q .github/codex/prompts/bootstrap.rendered.md 2>/dev/null || true
git reset -q .github/codex/prompts/edit.rendered.md 2>/dev/null || true
git reset -q .github/codex/bootstrap-output.md 2>/dev/null || true
git reset -q .github/codex/edit-output.md 2>/dev/null || true

if [[ -z "$(git diff --cached --name-only)" ]]; then
  echo "stage-site-edits.sh: only ephemeral files changed; nothing staged"
  exit 0
fi

echo "stage-site-edits.sh: staged $(git diff --cached --name-only | wc -l | tr -d ' ') path(s)"
