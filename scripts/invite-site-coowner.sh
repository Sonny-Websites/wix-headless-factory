#!/usr/bin/env bash
# Send a Wix site collaboration invite at co-owner level after bootstrap.
# Requires WIX_CLI_API_KEY with Manage Contributors permission.
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-${WIX_PROJECT_DIR:-site}}"
RUN_JSON="${RUN_JSON:-$REPO_ROOT/.wix/run.json}"

COOWNER_EMAIL="${COOWNER_EMAIL:-}"

if [[ -z "$COOWNER_EMAIL" ]]; then
  echo "invite-site-coowner.sh: coowner_email not provided; skipping co-owner invite" >&2
  exit 0
fi

COOWNER_POLICY_ID="${COOWNER_POLICY_ID:-6600344420111308827}"

if [[ -z "${WIX_CLI_API_KEY:-}" ]]; then
  echo "invite-site-coowner.sh: WIX_CLI_API_KEY is required to send site invites" >&2
  exit 1
fi

bash "$SCRIPTS_DIR/verify-wix-auth.sh"

SITE_ID="$(REPO_ROOT="$REPO_ROOT" PROJECT_DIR="$PROJECT_DIR" node "$SCRIPTS_DIR/resolve-site-id.mjs" || true)"
if [[ -z "$SITE_ID" ]]; then
  echo "invite-site-coowner.sh: could not resolve site ID from .wix/site.json or wix.config.json" >&2
  exit 1
fi

echo "invite-site-coowner.sh: resolved site ID $SITE_ID" >&2

resolve_coowner_policy_id() {
  local roles_response policy_id
  roles_response="$(curl -fsS \
    -X GET 'https://www.wixapis.com/roles-management/roles?filter.role_level=SITE_LEVEL&locale=en' \
    -H "Authorization: ${WIX_CLI_API_KEY}" \
    -H "wix-site-id: ${SITE_ID}" \
    -H 'Content-Type: application/json' || true)"

  if [[ -n "$roles_response" ]]; then
    policy_id="$(echo "$roles_response" | jq -r '
      (.predefinedRoles // []) + (.customRoles // [])
      | map(select((.title // "") | ascii_downcase | test("co[- ]?owner")))
      | .[0].id // empty
    ')"
    if [[ -n "$policy_id" ]]; then
      echo "$policy_id"
      return 0
    fi
  fi

  echo "$COOWNER_POLICY_ID"
}

POLICY_ID="$(resolve_coowner_policy_id)"
echo "invite-site-coowner.sh: using co-owner policy ID $POLICY_ID" >&2

REQUEST_BODY="$(jq -n \
  --arg email "$COOWNER_EMAIL" \
  --arg policyId "$POLICY_ID" \
  '{
    policyIds: [$policyId],
    emails: [$email]
  }')"

RESPONSE_FILE="$(mktemp)"
HTTP_STATUS="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST 'https://www.wixapis.com/invites/site-invite/bulk' \
  -H "Authorization: ${WIX_CLI_API_KEY}" \
  -H "wix-site-id: ${SITE_ID}" \
  -H 'Content-Type: application/json' \
  -d "$REQUEST_BODY")"

RESPONSE_BODY="$(cat "$RESPONSE_FILE")"
rm -f "$RESPONSE_FILE"

if [[ "$HTTP_STATUS" -lt 200 || "$HTTP_STATUS" -ge 300 ]]; then
  echo "invite-site-coowner.sh: bulk invite failed (HTTP $HTTP_STATUS)" >&2
  echo "$RESPONSE_BODY" >&2
  echo "Ensure WIX_CLI_API_KEY includes Manage Contributors permission." >&2
  exit 1
fi

FAILED_EMAILS="$(echo "$RESPONSE_BODY" | jq -r '.failedEmails // [] | join(", ")')"
if [[ -n "$FAILED_EMAILS" ]]; then
  echo "invite-site-coowner.sh: invite failed for: $FAILED_EMAILS" >&2
  echo "$RESPONSE_BODY" >&2
  exit 1
fi

INVITE_ID="$(echo "$RESPONSE_BODY" | jq -r '.invites[0].id // empty')"
INVITE_STATUS="$(echo "$RESPONSE_BODY" | jq -r '.invites[0].status // empty')"
echo "invite-site-coowner.sh: sent co-owner invite to $COOWNER_EMAIL (status=${INVITE_STATUS:-unknown}, id=${INVITE_ID:-n/a})" >&2

if [[ -f "$RUN_JSON" ]]; then
  export RUN_JSON COOWNER_EMAIL INVITE_ID INVITE_STATUS POLICY_ID
  node --input-type=module - <<'EOF' >&2
import { readFileSync, writeFileSync } from 'node:fs';

const runPath = process.env.RUN_JSON;
let run;
try {
  run = JSON.parse(readFileSync(runPath, 'utf8'));
} catch {
  run = { version: '1.0', run: {}, outcome: {}, phases: [] };
}

run.outcome = run.outcome || {};
run.outcome.coOwnerInvite = {
  email: process.env.COOWNER_EMAIL,
  policyId: process.env.POLICY_ID,
  inviteId: process.env.INVITE_ID || null,
  status: process.env.INVITE_STATUS || 'Pending',
  sentAt: new Date().toISOString(),
};

writeFileSync(runPath, JSON.stringify(run, null, 2) + '\n');
console.error(`Updated ${runPath} with coOwnerInvite`);
EOF
fi
