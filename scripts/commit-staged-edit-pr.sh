#!/usr/bin/env bash
# Commit only staged site edits, push branch, open and merge PR (requires GH_TOKEN).
set -euo pipefail

EDIT_SUMMARY="${EDIT_SUMMARY:-Site edit}"
RUN_ID="${RUN_ID:-unknown}"

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "commit-staged-edit-pr.sh: GH_TOKEN secret is required" >&2
  exit 1
fi
export GH_TOKEN

if [[ -z "$(git diff --cached --name-only)" ]]; then
  echo "commit-staged-edit-pr.sh: nothing staged to commit"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    bash "$(dirname "$0")/ci-set-output.sh" pr_number ""
  fi
  exit 0
fi

git config user.name "${GIT_USER_NAME:-github-actions[bot]}"
git config user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"

BRANCH="edit/${RUN_ID}"
git checkout -B "$BRANCH"

git commit -m "$(cat <<EOF
${EDIT_SUMMARY}

Automated site edit via wix-headless-factory (run ${RUN_ID}).
EOF
)"

git push -u origin "$BRANCH"

if ! PR_URL="$(gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "${EDIT_SUMMARY}" \
  --body "Automated site edit from workflow run ${RUN_ID}." 2>&1)"; then
  if echo "$PR_URL" | grep -qi 'already exists'; then
    PR_NUMBER="$(gh pr list --head "$BRANCH" --base main --json number --jq '.[0].number')"
  else
    echo "commit-staged-edit-pr.sh: failed to create PR: $PR_URL" >&2
    exit 1
  fi
else
  PR_NUMBER="$(echo "$PR_URL" | grep -oE '[0-9]+$' || true)"
fi

if [[ -z "$PR_NUMBER" ]]; then
  echo "commit-staged-edit-pr.sh: could not determine PR number" >&2
  exit 1
fi

gh pr merge "$PR_NUMBER" --merge --delete-branch
echo "commit-staged-edit-pr.sh: merged PR #${PR_NUMBER} to main"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  bash "$(dirname "$0")/ci-set-output.sh" pr_number "$PR_NUMBER"
fi
