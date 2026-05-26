# Wix Headless Factory — Agent Instructions

This repository is a **bootstrap template** cloned by n8n (or similar automation) into a per-site GitHub repo. Your job in CI is to run the [Wix Headless skill](https://www.wix-headless.dev/skill.md) end-to-end and produce a buildable Wix Managed Headless project.

## Runtime context

Before starting, read `.github/codex/.bootstrap-context.json`. It contains:

| Field | Meaning |
| --- | --- |
| `siteName` | Brand / display name (from n8n `site_name` input) |
| `sitePrompt` | Full site brief (from n8n `site_prompt` input) |
| `slug` | Pre-validated scaffold slug derived from `siteName` |
| `deploy` | If `true`, release to Wix after a successful build |
| `ci` | Always `true` in this repo — enables non-interactive rules below |
| `skillRoot` | Path to installed skill (`.skills/wix-headless`) |
| `skillEntry` | Read this first: `.skills/wix-headless/SKILL.md` |

Environment variables mirror the context file: `SITE_NAME`, `SITE_PROMPT`, `SITE_SLUG`, `CI=true`.

## Skill entry

1. Read **`SKILL.md`** at `skillEntry` (`.skills/wix-headless/SKILL.md`).
2. Follow **Path A — New site from a prompt** unless the working directory already contains a resumed `wix.config.json` + Astro scaffold.
3. Resolve all `<SKILL_ROOT>/…` paths against `.skills/wix-headless/`.
4. Do **not** call `WixSiteBuilder` MCP — this skill is the sole entry point for new-site builds.

Install reference (already done by CI before you run):

```bash
curl -fsSL https://wix-headless.dev/skill.tgz | tar -xzf - -C .skills/wix-headless --strip-components=1
```

Online fallback: fetch `https://dev.wix.com/skills/wix-headless/<path>` for any referenced file.

## CI / non-interactive rules

When `CI=true` (always in this repo):

| Normal skill behavior | CI override |
| --- | --- |
| `AskUserQuestion` for brand, vibe, plan approval | **Skip.** Use `siteName` as brand. Infer vibe + verticals from `sitePrompt`. **Auto-approve** the plan. |
| Discovery clarifier when prompt is vague | If `sitePrompt` lacks vertical signal, assume **cms-only marketing site** and note the assumption in `.wix/run.json`. |
| `wix login` device flow | **Do not run.** CI authenticates via `WIX_CLI_API_KEY` before Codex starts (`npx @wix/cli login --api-key`). Assume `npx @wix/cli whoami` exits 0. If auth fails, stop — do not attempt browser login. |
| Interactive plan review | Emit the plan as a markdown summary in your final message, then proceed immediately. |

Opening message to treat as the user's prompt:

```
Site name: {{siteName}}
Site brief: {{sitePrompt}}
```

Substitute from `.bootstrap-context.json`.

## Vertical / app inference

Infer required Wix Business Solutions from `sitePrompt` **before** Setup app install:

| Signal in prompt | Packs to load | Apps installed |
| --- | --- | --- |
| sell, store, shop, ecommerce, products, cart | `stores`, `cms`, `ecom`, `gift-cards` | Wix Stores |
| blog, articles, news, posts | `blog`, `cms` | Wix Blog |
| form, contact, lead, inquiry, signup | `forms`, `cms` | Wix Forms |
| portfolio, business, landing, marketing (no commerce) | `cms` | (CMS only) |
| bookings, appointments, schedule | `cms` + note in run.json | Flag `bookings` as unsupported in v1 |

Always include **`cms`** (skill default). Read pack frontmatter from `references/verticals/*.md` in one batch per SKILL.md routing table.

Known app IDs (for verification): `references/commands/known-apps.json`.

## Execution flow (summary)

Follow the skill's canonical pipeline:

```
Discovery (CI overrides) → Setup → Seed → ORCHESTRATION → Build → [Release if deploy]
```

Critical checkpoints:

1. **Pre-flight** — `npx @wix/cli whoami` must pass before scaffold (CI logs in with API key in a prior workflow step).
2. **Scaffold** — `bash .skills/wix-headless/scripts/scaffold.sh "$slug" "$siteName"` (background early in Discovery).
3. **Setup** — patch `.wix/site.json`, install inferred apps, env pull, npm install.
4. **Seed + Orchestration** — full skill flow through components, pages, images.
5. **Build** — `npx @wix/cli build` must exit 0 before commit.
6. **Release** (only if `deploy: true`) — run `bash scripts/release-to-wix.sh` from repo root; capture stdout as live URL.

Write **`.wix/run.json`** at end of run per `references/shared/RETURN_CONTRACT.md`.

## Authentication

All Wix REST calls use `@wix/cli` + `curl` — **no MCP** for site operations:

```bash
TOKEN=$(npx @wix/cli token --site "$SITE_ID")
curl -H "Authorization: Bearer $TOKEN" -H "wix-site-id: $SITE_ID" …
```

See `.skills/wix-headless/references/shared/AUTHENTICATION.md`.

## Subagent model tiers

Per SKILL.md:

- **Fast tier** — seeders, image-generation subagents.
- **Default tier** — designer, components, pages, anything authoring source files.

When unsure, use default tier.

## Files you must produce

At minimum after a successful bootstrap:

- `wix.config.json`, `astro.config.mjs`, `src/`, `package.json`
- `.wix/site.json`, `.wix/run.json`
- Build passes: `npx @wix/cli build`

Do **not** commit `.skills/` or `.github/codex/.bootstrap-context.json` — CI handles that.

## Failure handling

- **Build failure** — fix TypeScript/Astro errors; do not release.
- **401/403 on Wix API** — re-mint token once; if still failing, stop and report (likely missing app install).
- **Scaffold slug rejected** — re-derive slug per DISCOVERY.md (strip non-alnum, 3–20 chars) and retry scaffold once.

## Final message contract

End with a fenced JSON block (last content in message):

```json
{
  "status": "complete" | "partial" | "failed",
  "phase": "bootstrap",
  "summary": "one-line outcome",
  "data": {
    "siteName": "...",
    "slug": "...",
    "verticals": ["stores", "cms"],
    "previewUrl": "https://…",
    "dashboardUrl": "https://manage.wix.com/dashboard/…"
  },
  "files": ["…"],
  "errors": []
}
```

No prose after the closing fence.
