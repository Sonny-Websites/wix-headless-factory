#!/usr/bin/env node
/**
 * Resolve Wix dashboard URL for webhook outcome.
 * Prefers explicit env, then run.json, agent return JSON, then site.json siteId.
 */
import { readFileSync } from 'node:fs';

const runJsonPath = process.env.RUN_JSON_PATH || '.wix/run.json';
const siteJsonPath = process.env.SITE_JSON_PATH || '.wix/site.json';
const finalMessage = process.env.FINAL_MESSAGE || '';

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

function readSiteDashboard() {
  try {
    const site = JSON.parse(readFileSync(siteJsonPath, 'utf8'));
    const siteId = site.siteId || site.metaSiteId || site.id;
    return dashboardFromSiteId(siteId);
  } catch {
    // site.json may be absent
  }
  return '';
}

const explicit = (process.env.DASHBOARD_URL || '').trim();
const resolved =
  explicit || readRunDashboard() || readFinalMessageDashboard() || readSiteDashboard();

if (resolved) {
  process.stdout.write(`${resolved}\n`);
}
