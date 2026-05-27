#!/usr/bin/env bash
# Commit generated Wix Headless project files after Codex bootstrap.
set -euo pipefail

if [[ -z "$(git status --porcelain)" ]]; then
  echo "commit-generated.sh: no changes to commit"
  exit 0
fi

SITE_NAME="${SITE_NAME:-Wix Headless site}"
RUN_ID="${RUN_ID:-unknown}"

git config user.name "${GIT_USER_NAME:-github-actions[bot]}"
git config user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

bash "$(dirname "$0")/discard-codex-home-artifacts.sh"

git add -A
git reset -q .github/codex/.bootstrap-context.json 2>/dev/null || true
git reset -q .github/codex/config.toml 2>/dev/null || true
git reset -q .github/codex/config.toml.template 2>/dev/null || true
git reset -q .github/codex/*.json 2>/dev/null || true
git reset -q .github/codex/*.sqlite 2>/dev/null || true
git reset -q .github/codex/*.sqlite-shm 2>/dev/null || true
git reset -q .github/codex/*.sqlite-wal 2>/dev/null || true
git reset -q .github/codex/goals_*.sqlite 2>/dev/null || true
git reset -q .github/codex/logs_*.sqlite 2>/dev/null || true
git reset -q .github/codex/state_*.sqlite 2>/dev/null || true
git reset -q .github/codex/state_*.sqlite-shm 2>/dev/null || true
git reset -q .github/codex/state_*.sqlite-wal 2>/dev/null || true
git reset -q .github/codex/sessions/ 2>/dev/null || true
git reset -q .skills/ 2>/dev/null || true

if [[ -z "$(git diff --cached --name-only)" ]]; then
  echo "commit-generated.sh: only ephemeral files changed; nothing to commit"
  exit 0
fi

git commit -m "$(cat <<EOF
Bootstrap Wix Headless site: ${SITE_NAME}

Automated bootstrap via wix-headless-factory (run ${RUN_ID}).
EOF
)"

git push origin HEAD

echo "commit-generated.sh: pushed bootstrap commit"
