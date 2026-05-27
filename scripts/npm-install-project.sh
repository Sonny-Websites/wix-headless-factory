#!/usr/bin/env bash
# Install dependencies in the Wix Headless project directory.
# Uses npm ci when the lockfile matches package.json; otherwise npm install
# (Codex often updates package.json without refreshing package-lock.json).
set -euo pipefail

PROJECT_DIR="${1:-${PROJECT_DIR:-site}}"

if [[ ! -f "$PROJECT_DIR/package.json" ]]; then
  echo "npm-install-project.sh: no package.json in $PROJECT_DIR" >&2
  exit 1
fi

cd "$PROJECT_DIR"

if [[ ! -f package-lock.json ]]; then
  npm install
  exit 0
fi

if npm ci; then
  exit 0
fi

echo "npm-install-project.sh: package-lock.json out of sync; running npm install" >&2
rm -rf node_modules
npm install
