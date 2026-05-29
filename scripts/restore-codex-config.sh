#!/usr/bin/env bash
# Generate .github/codex/config.toml from config.toml.template (never commit codex-action proxy blocks).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/.github/codex/config.toml.template"
TARGET="$REPO_ROOT/.github/codex/config.toml"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "restore-codex-config.sh: missing $TEMPLATE" >&2
  exit 1
fi

cp "$TEMPLATE" "$TARGET"
echo "restore-codex-config.sh: restored $TARGET from template"
