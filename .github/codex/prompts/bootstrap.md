# Bootstrap prompt — rendered by GitHub Actions before Codex runs.
# Placeholders {{SITE_NAME}}, {{SITE_PROMPT}}, {{SITE_SLUG}}, {{DEPLOY}} are substituted by the workflow.

You are bootstrapping a new **Wix Managed Headless** site in this repository.

## Mandatory reads

1. `AGENTS.md` — CI rules and non-interactive overrides for this factory template.
2. `.github/codex/.bootstrap-context.json` — runtime inputs from n8n / workflow_dispatch.
3. `.skills/wix-headless/SKILL.md` — execute the full Wix Headless skill (Path A: new site from prompt).

## Site inputs

- **Site name (brand):** {{SITE_NAME}}
- **Site slug (metadata):** {{SITE_SLUG}}
- **Project directory (always):** `site/` — scaffold, build, and release use `./site/`
- **Site prompt (full brief):**

{{SITE_PROMPT}}

- **Release after build:** {{DEPLOY}}

## Your task

Run the Wix Headless skill end-to-end for this site:

1. Verify Wix CLI auth (`npx @wix/cli whoami`).
2. Infer verticals and required Wix apps (Stores, CMS, Blog, Forms, etc.) from the site prompt.
3. Scaffold the Wix-managed Headless Astro project.
4. Install inferred apps, seed content, design, wire components and pages.
5. Run `npx @wix/cli build` in `./site/` — the build **must pass**.
6. Write `.wix/run.json` with timing, verticals, and site metadata (CI will add preview/release URLs after your commit).
7. Do **not** run `wix preview` or `wix release` — CI publishes a preview after bootstrap; production release runs only when **Release after build** is `true`.

Follow **CI / non-interactive rules** in `AGENTS.md`: no `AskUserQuestion`, auto-approve the plan, use the provided site name as brand.

Do **not** use WixSiteBuilder MCP. Use `@wix/cli` + `curl` for all Wix API operations per the skill.

When finished, end with the JSON return contract from `AGENTS.md` (fenced JSON block, no trailing prose).
