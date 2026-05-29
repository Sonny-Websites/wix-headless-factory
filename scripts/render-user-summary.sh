#!/usr/bin/env bash
# Print a plain-language summary of site changes (stdout). Non-zero only on script error.
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
node "$SCRIPTS_DIR/render-user-summary.mjs"
