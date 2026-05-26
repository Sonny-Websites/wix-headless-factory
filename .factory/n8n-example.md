# n8n → wix-headless-factory integration

Checklist for wiring n8n to clone this template and bootstrap a Wix Headless site per customer.

## 1. Template repo setup (once)

- [ ] Publish `wix-headless-factory` as a GitHub template repository
- [ ] Org secrets: `OPENAI_API_KEY`, `WIX_CLI_API_KEY`
- [ ] Wix API key in [API Keys Manager](https://manage.wix.com/account/api-keys) with **Wix CLI - Git Integration** (+ Stores/CMS/etc. if bootstrap needs them)

No self-hosted runner required — workflows use `ubuntu-latest`.

## 2. Per-site workflow in n8n

### Node A — Create repository

Use **GitHub** node or HTTP Request:

```
POST /repos/{template_owner}/wix-headless-factory/generate
{
  "name": "site-{{ $json.customerSlug }}",
  "private": true,
  "include_all_branches": false
}
```

Or duplicate via your internal provisioning API.

Ensure the new repo inherits org secrets (`OPENAI_API_KEY`, `WIX_CLI_API_KEY`) or set them on the repo.

### Node B — Dispatch bootstrap

```
POST /repos/{owner}/{repo}/actions/workflows/bootstrap.yml/dispatches
{
  "ref": "main",
  "inputs": {
    "site_name": "{{ $json.siteName }}",
    "site_prompt": "{{ $json.sitePrompt }}",
    "deploy": "{{ $json.deployImmediately ? 'true' : 'false' }}"
  }
}
```

Map n8n fields:

| n8n field | GitHub input |
| --- | --- |
| Customer / brand name | `site_name` |
| Full creative brief | `site_prompt` |
| Go live immediately | `deploy` (`true` / `false`) |

### Node C — Wait for completion

Poll every 30–60 s:

```
GET /repos/{owner}/{repo}/actions/runs?event=workflow_dispatch&per_page=1
```

When `status=completed`:

- `conclusion=success` → fetch repo, read `.wix/run.json` for URLs
- `conclusion=failure` → surface logs link to operator

### Node D — Notify customer (optional)

Extract from bootstrap job summary or `.wix/run.json`:

- `outcome.previewUrl` / `outcome.releaseUrl`
- `outcome.dashboardUrl`

## 3. Redeploy without rebuild

Trigger deploy only:

```
POST /repos/{owner}/{repo}/actions/workflows/deploy.yml/dispatches
{ "ref": "main", "inputs": { "project_dir": "." } }
```

## 4. Prompt tips for n8n

Include enough signal for vertical inference:

| Goal | Include in `site_prompt` |
| --- | --- |
| Ecommerce | "online store", "sell products", "shopping cart" |
| Blog | "blog", "articles", "publish posts" |
| Lead gen | "contact form", "lead capture" |
| Brand | aesthetic adjectives, industry, target audience |

Example:

> Build a minimalist jewelry ecommerce site for handmade silver rings and necklaces. Warm editorial photography, about page, FAQ, and contact form. Primary palette: cream and charcoal.

## 5. Failure modes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Auth step fails | Missing or invalid `WIX_CLI_API_KEY` secret | Add secret; verify key in API Keys Manager |
| 403 during scaffold/seed | API key lacks permissions | Add Stores, CMS, Blog, Forms permissions to the key |
| Codex times out | Complex prompt / cold npm | Increase `timeout-minutes`; simplify prompt |
| Build fails | Generated code error | Re-dispatch bootstrap or manual fix + deploy |

## 6. Security

- Restrict `workflow_dispatch` to trusted actors (org members, n8n service account with `actions:write`)
- Never pass untrusted PR/issue text directly into `site_prompt` without sanitization
- Store `OPENAI_API_KEY` and `WIX_CLI_API_KEY` as GitHub secrets only — never commit them
