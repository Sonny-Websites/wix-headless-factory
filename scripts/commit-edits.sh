#!/usr/bin/env bash
# Commit Codex site edits, push branch, and merge to main via PR.
set -euo pipefail

EDIT_SUMMARY="${EDIT_SUMMARY:-Site edit}"
RUN_ID="${RUN_ID:-unknown}"
MERGE_TO_MAIN="${MERGE_TO_MAIN:-true}"

if [[ -z "$(git status --porcelain)" ]]; then
  echo "commit-edits.sh: no changes to commit"
  exit 0
fi

git config user.name "${GIT_USER_NAME:-github-actions[bot]}"
git config user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

git add -A
git reset -q .github/codex/.bootstrap-context.json 2>/dev/null || true
git reset -q .github/codex/.edit-context.json 2>/dev/null || true
git reset -q .github/codex/config.toml 2>/dev/null || true
git reset -q .github/codex/*.json 2>/dev/null || true
git reset -q .skills/ 2>/dev/null || true
git reset -q .github/codex/prompts/bootstrap.rendered.md 2>/dev/null || true
git reset -q .github/codex/prompts/edit.rendered.md 2>/dev/null || true
git reset -q .github/codex/bootstrap-output.md 2>/dev/null || true
git reset -q .github/codex/edit-output.md 2>/dev/null || true

if [[ -z "$(git diff --cached --name-only)" ]]; then
  echo "commit-edits.sh: only ephemeral files changed; nothing to commit"
  exit 0
fi

BRANCH="$(git branch --show-current)"
git commit -m "$(cat <<EOF
${EDIT_SUMMARY}

Automated site edit via wix-headless-factory (run ${RUN_ID}).
EOF
)"

git push -u origin "$BRANCH"

if [[ "$MERGE_TO_MAIN" != "true" ]]; then
  echo "commit-edits.sh: pushed to $BRANCH (merge skipped)"
  exit 0
fi

if [[ "$BRANCH" == "main" ]]; then
  echo "commit-edits.sh: pushed directly to main"
  exit 0
fi

if ! PR_URL="$(gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "${EDIT_SUMMARY}" \
  --body "Automated site edit from workflow run ${RUN_ID}." 2>&1)"; then
  if echo "$PR_URL" | grep -qi 'already exists'; then
    PR_NUMBER="$(gh pr list --head "$BRANCH" --base main --json number --jq '.[0].number')"
  else
    echo "commit-edits.sh: failed to create PR: $PR_URL" >&2
    exit 1
  fi
else
  PR_NUMBER="$(echo "$PR_URL" | grep -oE '[0-9]+$' || true)"
fi

if [[ -z "$PR_NUMBER" ]]; then
  echo "commit-edits.sh: could not create or find PR for branch $BRANCH" >&2
  exit 1
fi

gh pr merge "$PR_NUMBER" --merge --delete-branch
echo "commit-edits.sh: merged PR #$PR_NUMBER to main"
