#!/usr/bin/env node
/**
 * Render a plain-language site summary for operators and end users.
 * Prefers run.json outcome.userSummary, then the agent return JSON, then filtered prose.
 */
import { readFileSync } from 'node:fs';

const runJsonPath = process.env.RUN_JSON_PATH || '.wix/run.json';
const finalMessage = process.env.FINAL_MESSAGE || '';

const TECHNICAL =
  /\bnpx\b|\bnpm\b|\bwix\/cli\b|\bscaffold\b|\bcurl\b|\bMCP\b|\.wix\/|\bsrc\/|package\.json|run\.json|whoami|workflow|codex|commit|```|build passed|skill\.md|AGENTS\.md/i;

function extractJsonBlock(text) {
  const matches = [...text.matchAll(/```(?:json|jsonc)\s*([\s\S]*?)```/g)];
  if (!matches.length) return null;
  try {
    return JSON.parse(matches[matches.length - 1][1]);
  } catch {
    return null;
  }
}

function isTechnical(text) {
  return TECHNICAL.test(text);
}

function cleanProse(text) {
  return text
    .split(/\n+/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#') && !isTechnical(line))
    .filter((line) => !/^(\*\*Plan|\*\*Discovery|## )/.test(line))
    .join('\n\n')
    .trim();
}

function extractProseBeforeJson(text) {
  const fence = text.lastIndexOf('```json');
  if (fence === -1) return '';
  return cleanProse(text.slice(0, fence));
}

function readRunSummary() {
  try {
    const run = JSON.parse(readFileSync(runJsonPath, 'utf8'));
    const candidate = run.outcome?.userSummary || run.userSummary;
    if (typeof candidate === 'string' && candidate.trim()) {
      return candidate.trim();
    }
  } catch {
    // run.json may be absent in notify job checkout
  }
  return '';
}

function resolveSummary() {
  const fromRun = readRunSummary();
  if (fromRun) return fromRun;

  const parsed = extractJsonBlock(finalMessage);
  if (parsed) {
    const fromData = parsed.data?.userSummary;
    if (typeof fromData === 'string' && fromData.trim()) {
      return fromData.trim();
    }
    if (
      typeof parsed.summary === 'string' &&
      parsed.summary.trim() &&
      !isTechnical(parsed.summary)
    ) {
      return parsed.summary.trim();
    }
  }

  return extractProseBeforeJson(finalMessage);
}

const summary = resolveSummary();
if (summary) {
  process.stdout.write(`${summary}\n`);
}
