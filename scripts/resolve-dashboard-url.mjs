#!/usr/bin/env node
/**
 * Resolve Wix dashboard URL for webhook outcome.
 * Prefers explicit env, then run.json, agent return JSON, then site ID (resolve-site-id.mjs).
 */
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const runJsonPath = process.env.RUN_JSON_PATH || '.wix/run.json';
const finalMessage = process.env.FINAL_MESSAGE || '';
const scriptDir = dirname(fileURLToPath(import.meta.url));

function extractJsonBlock(text) {
  const matches = [...text.matchAll(/```(?:json|jsonc)\s*([\s\S]*?)```/g)];
  if (!matches.length) return null;
  try {
    return JSON.parse(matches[matches.length - 1][1]);
  } catch {
    return null;
  }
}

function dashboardFromSiteId(siteId) {
  if (typeof siteId !== 'string' || !siteId.trim()) return '';
  return `https://manage.wix.com/dashboard/${siteId.trim()}`;
}

function readRunDashboard() {
  try {
    const run = JSON.parse(readFileSync(runJsonPath, 'utf8'));
    const candidate = run.outcome?.dashboardUrl || run.data?.dashboardUrl;
    if (typeof candidate === 'string' && candidate.trim()) {
      return candidate.trim();
    }
  } catch {
    // run.json may be absent in notify job checkout
  }
  return '';
}

function readFinalMessageDashboard() {
  const parsed = extractJsonBlock(finalMessage);
  const candidate = parsed?.data?.dashboardUrl;
  if (typeof candidate === 'string' && candidate.trim()) {
    return candidate.trim();
  }
  return '';
}

function readSiteIdDashboard() {
  try {
    const siteId = execFileSync('node', [join(scriptDir, 'resolve-site-id.mjs')], {
      encoding: 'utf8',
      env: process.env,
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    return dashboardFromSiteId(siteId);
  } catch {
    return '';
  }
}

const explicit = (process.env.DASHBOARD_URL || '').trim();
const resolved =
  explicit || readRunDashboard() || readFinalMessageDashboard() || readSiteIdDashboard();

if (resolved) {
  process.stdout.write(`${resolved}\n`);
}
