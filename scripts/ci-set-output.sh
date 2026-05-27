#!/usr/bin/env bash
# Write a single value to GITHUB_OUTPUT (supports special characters; no multiline pollution).
set -euo pipefail

NAME="${1:?output name}"
VALUE="${2-}"

if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "ci-set-output.sh: GITHUB_OUTPUT is not set" >&2
  exit 1
fi

# Collapse accidental newlines from captured command output.
VALUE="${VALUE//$'\r'/}"
VALUE="${VALUE//$'\n'/}"

DELIM="ghout_${RANDOM}_${RANDOM}"
while [[ "$VALUE" == *"$DELIM"* ]]; do
  DELIM="ghout_${RANDOM}_${RANDOM}"
done

{
  echo "${NAME}<<${DELIM}"
  echo "$VALUE"
  echo "${DELIM}"
} >> "$GITHUB_OUTPUT"
