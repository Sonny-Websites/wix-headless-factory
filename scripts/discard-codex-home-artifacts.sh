#!/usr/bin/env bash
# Drop runtime codex-action / Codex CLI artifacts under .github/codex (do not commit).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_HOME="$REPO_ROOT/.github/codex"

bash "$(dirname "$0")/restore-codex-config.sh"

git -C "$REPO_ROOT" checkout -- .github/codex/factory.config.toml 2>/dev/null || true

rm -f "$CODEX_HOME"/*.sqlite "$CODEX_HOME"/*.sqlite-shm "$CODEX_HOME"/*.sqlite-wal 2>/dev/null || true
rm -f "$CODEX_HOME"/goals_*.sqlite "$CODEX_HOME"/logs_*.sqlite "$CODEX_HOME"/state_*.sqlite* 2>/dev/null || true
rm -f "$CODEX_HOME"/*.json 2>/dev/null || true

git -C "$REPO_ROOT" clean -fdq "$CODEX_HOME/sessions" 2>/dev/null || true

echo "discard-codex-home-artifacts.sh: cleaned runtime files under .github/codex/"
