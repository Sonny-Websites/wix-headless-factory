#!/usr/bin/env bash
# POST workflow completion payload to n8n webhook URLs (optional secret header).
# Set N8N_WEBHOOK_URL_TEST and/or N8N_WEBHOOK_URL_PROD (and optionally N8N_WEBHOOK_SECRET) as repo/org secrets.
set -euo pipefail

WEBHOOK_TARGETS=()
if [[ -n "${N8N_WEBHOOK_URL_TEST:-}" ]]; then
  WEBHOOK_TARGETS+=("test|${N8N_WEBHOOK_URL_TEST}")
fi
if [[ -n "${N8N_WEBHOOK_URL_PROD:-}" ]]; then
  WEBHOOK_TARGETS+=("prod|${N8N_WEBHOOK_URL_PROD}")
fi

if [[ ${#WEBHOOK_TARGETS[@]} -eq 0 ]]; then
  echo "notify-webhook.sh: no webhook URLs set (N8N_WEBHOOK_URL_TEST / N8N_WEBHOOK_URL_PROD); skipping webhook"
  exit 0
fi

WEBHOOK_EVENT="${WEBHOOK_EVENT:?WEBHOOK_EVENT is required (e.g. bootstrap.completed)}"
JOB_RESULT="${JOB_RESULT:-unknown}"
RUN_JSON_PATH="${RUN_JSON_PATH:-.wix/run.json}"
MAX_ATTEMPTS="${N8N_WEBHOOK_MAX_ATTEMPTS:-3}"
RETRY_DELAY="${N8N_WEBHOOK_RETRY_DELAY:-2}"

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
REPO_OWNER="${GITHUB_REPOSITORY%%/*}"
REPO_NAME="${GITHUB_REPOSITORY##*/}"
if [[ "$REPO_OWNER" == "$GITHUB_REPOSITORY" ]]; then
  REPO_OWNER=""
fi
GITHUB_RUN_ID="${GITHUB_RUN_ID:-}"
GITHUB_RUN_URL="${GITHUB_RUN_URL:-}"
GITHUB_REF_NAME="${GITHUB_REF_NAME:-}"
GITHUB_ACTOR="${GITHUB_ACTOR:-}"
WORKFLOW_NAME="${WORKFLOW_NAME:-}"

SITE_NAME="${SITE_NAME:-}"
SITE_PROMPT="${SITE_PROMPT:-}"
EDIT_PROMPT="${EDIT_PROMPT:-}"
PROJECT_DIR="${PROJECT_DIR:-site}"

RELEASE_URL="${RELEASE_URL:-}"
PREVIEW_URL="${PREVIEW_URL:-}"
FINAL_MESSAGE="${FINAL_MESSAGE:-}"
USER_SUMMARY="${USER_SUMMARY:-}"

if [[ -z "$USER_SUMMARY" ]]; then
  USER_SUMMARY="$(bash "$(dirname "$0")/render-user-summary.sh" 2>/dev/null || true)"
fi

build_payload() {
  local base
  base="$(jq -n \
    --arg event "$WEBHOOK_EVENT" \
    --arg jobResult "$JOB_RESULT" \
    --arg repository "$GITHUB_REPOSITORY" \
    --arg repoOwner "$REPO_OWNER" \
    --arg repoName "$REPO_NAME" \
    --arg runId "$GITHUB_RUN_ID" \
    --arg runUrl "$GITHUB_RUN_URL" \
    --arg ref "$GITHUB_REF_NAME" \
    --arg actor "$GITHUB_ACTOR" \
    --arg workflow "$WORKFLOW_NAME" \
    --arg siteName "$SITE_NAME" \
    --arg sitePrompt "$SITE_PROMPT" \
    --arg editPrompt "$EDIT_PROMPT" \
    --arg projectDir "$PROJECT_DIR" \
    --arg releaseUrl "$RELEASE_URL" \
    --arg previewUrl "$PREVIEW_URL" \
    --arg finalMessage "$FINAL_MESSAGE" \
    --arg userSummary "$USER_SUMMARY" \
    '{
      event: $event,
      jobResult: $jobResult,
      repository: $repository,
      repoOwner: (if $repoOwner == "" then null else $repoOwner end),
      repoName: (if $repoName == "" then null else $repoName end),
      runId: $runId,
      runUrl: $runUrl,
      ref: $ref,
      actor: $actor,
      workflow: $workflow,
      inputs: {
        siteName: $siteName,
        sitePrompt: $sitePrompt,
        editPrompt: $editPrompt,
        projectDir: $projectDir
      },
      outcome: {
        releaseUrl: (if $releaseUrl == "" then null else $releaseUrl end),
        previewUrl: (if $previewUrl == "" then null else $previewUrl end)
      },
      finalMessage: (if $finalMessage == "" then null else $finalMessage end),
      userSummary: (if $userSummary == "" then null else $userSummary end)
    }')"

  if [[ -f "$RUN_JSON_PATH" ]]; then
    echo "$base" | jq --slurpfile run "$RUN_JSON_PATH" '. + { runJson: $run[0] }'
  else
    echo "$base"
  fi
}

PAYLOAD="$(build_payload)"

post_to_webhook() {
  local label="$1"
  local url="$2"
  local attempt curl_status=1

  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    echo "notify-webhook.sh: POST $WEBHOOK_EVENT (jobResult=$JOB_RESULT) → $label (attempt $attempt/$MAX_ATTEMPTS)"

    local curl_args=(-fsS -X POST "$url" -H "Content-Type: application/json" -d "$PAYLOAD")
    if [[ -n "${N8N_WEBHOOK_SECRET:-}" ]]; then
      curl_args+=(-H "X-Webhook-Secret: ${N8N_WEBHOOK_SECRET}")
    fi

    set +e
    curl "${curl_args[@]}"
    curl_status=$?
    set -e

    if [[ "$curl_status" -eq 0 ]]; then
      echo "notify-webhook.sh: webhook delivered to $label"
      return 0
    fi

    if [[ "$attempt" -lt "$MAX_ATTEMPTS" ]]; then
      local sleep_seconds=$((attempt * RETRY_DELAY))
      echo "notify-webhook.sh: $label attempt $attempt failed; retrying in ${sleep_seconds}s" >&2
      sleep "$sleep_seconds"
    fi
  done

  echo "notify-webhook.sh: webhook request failed for $label after $MAX_ATTEMPTS attempts (non-fatal)" >&2
  return 1
}

any_failed=0
for target in "${WEBHOOK_TARGETS[@]}"; do
  label="${target%%|*}"
  url="${target#*|}"
  if ! post_to_webhook "$label" "$url"; then
    any_failed=1
  fi
done

if [[ "$any_failed" -eq 1 ]]; then
  exit 0
fi
