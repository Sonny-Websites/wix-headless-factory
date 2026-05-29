# Edit prompt — rendered by GitHub Actions before Codex runs.
# Placeholder {{EDIT_PROMPT}} is substituted by the workflow.

You are editing an existing **Wix Managed Headless** site in this repository.

## Mandatory reads

1. `AGENTS.md` — CI rules for this factory template.
2. `.github/codex/.edit-context.json` — runtime edit request from workflow_dispatch.
3. `.skills/wix-headless/SKILL.md` — use relevant skill guidance for CMS, components, pages, and builds (do **not** re-scaffold).

## Project layout

- **Project directory:** `./site/` (or `projectDir` from edit context)
- **Wix config:** `./site/wix.config.json` must already exist
- **Run metadata:** `.wix/run.json` at repo root

## Edit request

{{EDIT_PROMPT}}

## Your task

1. Verify Wix CLI auth (`npx @wix/cli whoami`).
2. Inspect the existing project in `./site/` — do **not** run scaffold or create a new Wix site.
3. Implement the edit request: update components, pages, CMS content, styles, or config as needed.
4. Run `npm install` in `./site/` if dependencies changed.
5. Run `npx @wix/cli build` in `./site/` — the build **must pass**.
6. Update `.wix/run.json` with edit metadata (timestamp) and `outcome.userSummary` — a plain-language description of what changed for the site owner (no CLI commands, file paths, or internal tooling).
7. Do **not** run `wix preview` or `wix release` — CI publishes a preview after your commit.

Follow **CI / non-interactive rules** in `AGENTS.md`: no `AskUserQuestion`, proceed without interactive approval.

Do **not** use WixSiteBuilder MCP. Use `@wix/cli` + `curl` for Wix API operations per the skill.

When finished, end with a fenced JSON block (include `data.userSummary` per `AGENTS.md`):

```json
{
  "status": "complete" | "partial" | "failed",
  "phase": "edit",
  "summary": "one-line outcome",
  "data": {
    "projectDir": "site",
    "userSummary": "Updated the homepage hero headline and added a featured products row below it."
  },
  "errors": []
}
```
