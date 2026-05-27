#!/usr/bin/env bash
# Deprecated: edit workflow uses stage-site-edits.sh + commit-staged-edit-pr.sh in CI.
# Kept for local use — stages, commits, and pushes the current branch only.
set -euo pipefail

EDIT_SUMMARY="${EDIT_SUMMARY:-Site edit}"
RUN_ID="${RUN_ID:-unknown}"

bash "$(dirname "$0")/stage-site-edits.sh"

if [[ -z "$(git diff --cached --name-only)" ]]; then
  exit 0
fi

git config user.name "${GIT_USER_NAME:-github-actions[bot]}"
git config user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

git commit -m "$(cat <<EOF
${EDIT_SUMMARY}

Automated site edit via wix-headless-factory (run ${RUN_ID}).
EOF
)"

BRANCH="$(git branch --show-current)"
git push -u origin "$BRANCH"
echo "commit-edits.sh: pushed to $BRANCH (open a PR manually or use the edit workflow)"
