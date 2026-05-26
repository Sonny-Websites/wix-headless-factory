# wix-headless-factory

Reusable bootstrap template for spinning up **Wix Managed Headless** sites from automation (n8n, scripts, or manual `workflow_dispatch`).

Each cloned repo gets:

- **`AGENTS.md`** — Codex / agent rules with CI overrides for the [Wix Headless skill](https://www.wix-headless.dev/skill.md)
- **Bootstrap workflow** — runs Codex against the skill, scaffolds the project, builds, commits, optionally releases
- **Deploy workflow** — build + release on demand via GitHub-hosted runners

## Architecture

```mermaid
flowchart LR
  n8n[n8n automation]
  template[wix-headless-factory template]
  repo[Per-site GitHub repo]
  gha[GitHub Actions ubuntu-latest]
  codex[Codex + Wix Headless skill]
  wix[Wix Headless site]

  n8n -->|clone template| repo
  n8n -->|workflow_dispatch site_name + site_prompt| repo
  repo --> gha
  gha -->|WIX_CLI_API_KEY| codex
  codex -->|scaffold build commit| repo
  codex -->|optional release| wix
```

## Prerequisites

### GitHub secrets

| Secret | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Codex CLI via [openai/codex-action](https://github.com/openai/codex-action) |
| `WIX_CLI_API_KEY` | Wix CLI auth for scaffold, build, and release in CI |

### Wix API key

Generate a key in the [API Keys Manager](https://manage.wix.com/account/api-keys). Each job runs:

```bash
npx @wix/cli login --api-key "$WIX_CLI_API_KEY"
```

**Permissions:** start with **Wix CLI - Git Integration** (documented for [GitHub Actions + Wix CLI](https://dev.wix.com/docs/develop-websites/articles/workspace-tools/developer-tools/git-integration-wix-cli-for-sites/set-up-git-hub-actions-to-work-with-the-wix-cli-for-sites.md)). Full bootstrap also scaffolds new sites, installs apps, and seeds content — if those steps return `403`, add the relevant permissions (Stores, CMS, Blog, Forms, etc.) to the key.

Store the key as org or repo secret `WIX_CLI_API_KEY`. No self-hosted runner required.

## Workflows

### Bootstrap (`bootstrap.yml`)

**Trigger:** `workflow_dispatch`  
**Runner:** `ubuntu-latest`

| Input | Required | Description |
| --- | --- | --- |
| `site_name` | yes | Brand / display name (from n8n) |
| `site_prompt` | yes | Full site brief — Codex infers Stores/CMS/Blog/Forms from this |
| `site_slug` | no | Scaffold slug override (`^[a-z0-9]{3,20}$`) |
| `deploy` | no | Release to Wix after successful build (default `false`) |

**What it does:**

1. Authenticates Wix CLI with `WIX_CLI_API_KEY`
2. Installs the Wix Headless skill from `https://wix-headless.dev/skill.tgz`
3. Writes `.github/codex/.bootstrap-context.json` from inputs
4. Runs Codex (`openai/codex-action@v1`) with `AGENTS.md` + skill instructions
5. Commits generated project files and pushes
6. Optionally runs `scripts/release-to-wix.sh` when `deploy=true`

### Deploy (`deploy.yml`)

**Trigger:** `workflow_dispatch` or reusable `workflow_call`  
**Runner:** `ubuntu-latest`

Builds and releases an existing Wix Headless project (`npx @wix/cli build` → `npx @wix/cli release`).

## n8n integration

Typical flow per new site:

1. **Create repo** — clone or generate from this template (GitHub “Use this template”, `gh repo create`, or n8n GitHub node).
2. **Configure secrets** — `OPENAI_API_KEY` and `WIX_CLI_API_KEY` on the new repo (or inherit from org).
3. **Dispatch bootstrap** — GitHub API:

```http
POST /repos/{owner}/{repo}/actions/workflows/bootstrap.yml/dispatches
Authorization: Bearer {github_pat}
Content-Type: application/json

{
  "ref": "main",
  "inputs": {
    "site_name": "Bloom & Root",
    "site_prompt": "Build a modern skincare ecommerce store with hero, about, and contact form. Warm minimal aesthetic, sell serums and moisturizers online.",
    "deploy": "true"
  }
}
```

**n8n HTTP Request node settings:**

- Method: `POST`
- URL: `https://api.github.com/repos/{{owner}}/{{repo}}/actions/workflows/bootstrap.yml/dispatches`
- Headers: `Authorization: Bearer {{$credentials.githubToken}}`, `Accept: application/vnd.github+json`
- Body (JSON): map your site name and prompt fields to `inputs.site_name` and `inputs.site_prompt`

Poll run status:

```http
GET /repos/{owner}/{repo}/actions/runs?event=workflow_dispatch
```

After success, read the live URL from the job summary or `.wix/run.json` in the repo.

See [`.factory/n8n-example.md`](.factory/n8n-example.md) for a step-by-step n8n checklist.

## Local development

```bash
# Authenticate (pick one)
export WIX_CLI_API_KEY="your-key"
bash scripts/verify-wix-auth.sh
# or: npx @wix/cli login

# Install skill only
bash scripts/install-wix-headless-skill.sh

# Prepare context (simulates workflow inputs)
SITE_NAME="Acme Coffee" \
SITE_PROMPT="Coffee roastery online store, sell beans and subscriptions" \
DEPLOY=false \
bash scripts/prepare-bootstrap-context.sh
```

Codex bootstrap is intended to run in CI; local runs need `OPENAI_API_KEY` and Wix CLI auth.

## Agent rules

Codex reads **`AGENTS.md`** at repo root. Key CI behaviors:

- No interactive Q&A — brand from `site_name`, verticals inferred from `site_prompt`
- Auto-approve discovery plan
- Wix CLI pre-authenticated via API key — no device login
- Full Wix Headless skill pipeline: Discovery → Setup → Seed → Orchestration → Build
- Wix API via `@wix/cli token` + `curl` (not MCP)

## File layout

```
.
├── AGENTS.md                          # Codex / Wix Headless CI rules
├── .github/
│   ├── workflows/
│   │   ├── bootstrap.yml              # n8n entry point
│   │   └── deploy.yml                 # manual / post-bootstrap release
│   └── codex/
│       ├── config.toml                # Codex profile (factory)
│       └── prompts/bootstrap.md       # Bootstrap prompt template
├── scripts/
│   ├── install-wix-headless-skill.sh
│   ├── prepare-bootstrap-context.sh
│   ├── verify-wix-auth.sh             # API key or existing session
│   ├── commit-generated.sh
│   └── release-to-wix.sh
├── .factory/                          # Automation metadata
└── .wix/                              # Created during bootstrap
```

## References

- [Wix Headless Skill](https://www.wix-headless.dev/skill.md)
- [Wix CLI login (--api-key)](https://dev.wix.com/docs/wix-cli/command-reference/global-commands/login.md)
- [Codex GitHub Action](https://developers.openai.com/codex/github-action)
- [Wix Headless docs](https://dev.wix.com/docs/go-headless)
