#!/usr/bin/env bash
# POST workflow completion payload to N8N_WEBHOOK_URL (optional secret header).
# Set N8N_WEBHOOK_URL (and optionally N8N_WEBHOOK_SECRET) as repo/org secrets.
set -euo pipefail

if [[ -z "${N8N_WEBHOOK_URL:-}" ]]; then
  echo "notify-webhook.sh: N8N_WEBHOOK_URL not set; skipping webhook"
  exit 0
fi

WEBHOOK_EVENT="${WEBHOOK_EVENT:?WEBHOOK_EVENT is required (e.g. bootstrap.completed)}"
JOB_RESULT="${JOB_RESULT:-unknown}"
RUN_JSON_PATH="${RUN_JSON_PATH:-.wix/run.json}"

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
GITHUB_RUN_ID="${GITHUB_RUN_ID:-}"
GITHUB_RUN_URL="${GITHUB_RUN_URL:-}"
GITHUB_REF_NAME="${GITHUB_REF_NAME:-}"
GITHUB_ACTOR="${GITHUB_ACTOR:-}"
WORKFLOW_NAME="${WORKFLOW_NAME:-}"

SITE_NAME="${SITE_NAME:-}"
SITE_PROMPT="${SITE_PROMPT:-}"
SITE_SLUG="${SITE_SLUG:-}"
DEPLOY="${DEPLOY:-}"
EDIT_PROMPT="${EDIT_PROMPT:-}"
PROJECT_DIR="${PROJECT_DIR:-site}"

RELEASE_URL="${RELEASE_URL:-}"
PREVIEW_URL="${PREVIEW_URL:-}"
FINAL_MESSAGE="${FINAL_MESSAGE:-}"

build_payload() {
  local base
  base="$(jq -n \
    --arg event "$WEBHOOK_EVENT" \
    --arg jobResult "$JOB_RESULT" \
    --arg repository "$GITHUB_REPOSITORY" \
    --arg runId "$GITHUB_RUN_ID" \
    --arg runUrl "$GITHUB_RUN_URL" \
    --arg ref "$GITHUB_REF_NAME" \
    --arg actor "$GITHUB_ACTOR" \
    --arg workflow "$WORKFLOW_NAME" \
    --arg siteName "$SITE_NAME" \
    --arg sitePrompt "$SITE_PROMPT" \
    --arg siteSlug "$SITE_SLUG" \
    --arg deploy "$DEPLOY" \
    --arg editPrompt "$EDIT_PROMPT" \
    --arg projectDir "$PROJECT_DIR" \
    --arg releaseUrl "$RELEASE_URL" \
    --arg previewUrl "$PREVIEW_URL" \
    --arg finalMessage "$FINAL_MESSAGE" \
    '{
      event: $event,
      jobResult: $jobResult,
      repository: $repository,
      runId: $runId,
      runUrl: $runUrl,
      ref: $ref,
      actor: $actor,
      workflow: $workflow,
      inputs: {
        siteName: $siteName,
        sitePrompt: $sitePrompt,
        siteSlug: $siteSlug,
        deploy: $deploy,
        editPrompt: $editPrompt,
        projectDir: $projectDir
      },
      outcome: {
        releaseUrl: (if $releaseUrl == "" then null else $releaseUrl end),
        previewUrl: (if $previewUrl == "" then null else $previewUrl end)
      },
      finalMessage: (if $finalMessage == "" then null else $finalMessage end)
    }')"

  if [[ -f "$RUN_JSON_PATH" ]]; then
    echo "$base" | jq --slurpfile run "$RUN_JSON_PATH" '. + { runJson: $run[0] }'
  else
    echo "$base"
  fi
}

PAYLOAD="$(build_payload)"

CURL_ARGS=(
  -fsS
  -X POST
  "$N8N_WEBHOOK_URL"
  -H "Content-Type: application/json"
  -d "$PAYLOAD"
)

if [[ -n "${N8N_WEBHOOK_SECRET:-}" ]]; then
  CURL_ARGS+=(-H "X-Webhook-Secret: ${N8N_WEBHOOK_SECRET}")
fi

echo "notify-webhook.sh: POST $WEBHOOK_EVENT (jobResult=$JOB_RESULT) → N8N_WEBHOOK_URL"
if ! curl "${CURL_ARGS[@]}"; then
  echo "notify-webhook.sh: webhook request failed (non-fatal)" >&2
  exit 0
fi

echo "notify-webhook.sh: webhook delivered"
