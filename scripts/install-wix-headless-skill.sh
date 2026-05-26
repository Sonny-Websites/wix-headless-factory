#!/usr/bin/env bash
# Install the Wix Headless agent skill into .skills/wix-headless/
set -euo pipefail

SKILL_ROOT="${SKILL_ROOT:-.skills/wix-headless}"
SKILL_URL="${WIX_HEADLESS_SKILL_URL:-https://wix-headless.dev/skill.tgz}"

rm -rf "$SKILL_ROOT"
mkdir -p "$SKILL_ROOT"

echo "Installing Wix Headless skill from $SKILL_URL → $SKILL_ROOT"
curl -fsSL "$SKILL_URL" | tar -xzf - -C "$SKILL_ROOT" --strip-components=1

if [[ ! -f "$SKILL_ROOT/SKILL.md" ]]; then
  echo "install-wix-headless-skill.sh: SKILL.md not found after extract" >&2
  exit 1
fi

echo "Wix Headless skill installed at $SKILL_ROOT"
