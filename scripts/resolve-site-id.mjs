#!/usr/bin/env node
/**
 * Resolve Wix meta-site ID from run.json, site.json, or wix.config.json.
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const repoRoot = process.env.REPO_ROOT || process.cwd();
const projectDir = process.env.PROJECT_DIR || process.env.WIX_PROJECT_DIR || 'site';

const candidates = [
  process.env.SITE_JSON_PATH,
  join(repoRoot, '.wix', 'site.json'),
  join(repoRoot, projectDir, '.wix', 'site.json'),
  join(repoRoot, projectDir, 'wix.config.json'),
].filter(Boolean);

function readSiteIdFromFile(path) {
  if (!existsSync(path)) return '';
  try {
    const data = JSON.parse(readFileSync(path, 'utf8'));
    const siteId =
      data.siteId ||
      data.metaSiteId ||
      data.id ||
      data.site?.siteId ||
      data.site?.metaSiteId;
    return typeof siteId === 'string' ? siteId.trim() : '';
  } catch {
    return '';
  }
}

function readRunSiteId() {
  const runPath = process.env.RUN_JSON_PATH || join(repoRoot, '.wix', 'run.json');
  if (!existsSync(runPath)) return '';
  try {
    const run = JSON.parse(readFileSync(runPath, 'utf8'));
    const siteId = run.data?.siteId || run.run?.siteId || run.siteId;
    return typeof siteId === 'string' ? siteId.trim() : '';
  } catch {
    return '';
  }
}

const explicit = (process.env.SITE_ID || '').trim();
const resolved =
  explicit ||
  readRunSiteId() ||
  candidates.map(readSiteIdFromFile).find(Boolean) ||
  '';

if (resolved) {
  process.stdout.write(`${resolved}\n`);
} else {
  process.exitCode = 1;
}
