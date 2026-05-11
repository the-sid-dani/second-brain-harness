#!/usr/bin/env node
/**
 * Stop hook — block when context is too high and suggest handoff.
 *
 * Reads context percentage from the temp file written by status.mjs.
 * This ensures 1:1 match with status line display.
 */
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

const CONTEXT_THRESHOLD = 85;

function getSessionId(data) {
  const sid = data.session_id || '';
  if (sid) return sid.slice(0, 8);
  return process.env.CLAUDE_SESSION_ID || String(process.ppid);
}

function main() {
  const data = JSON.parse(readFileSync(0, 'utf-8'));

  if (data.stop_hook_active) { console.log('{}'); return; }

  const sid = getSessionId(data);
  const file = join(tmpdir(), `claude-context-pct-${sid}.txt`);

  let pct = null;
  try {
    if (existsSync(file)) pct = parseInt(readFileSync(file, 'utf-8').trim(), 10);
  } catch {}

  if (pct == null || pct < CONTEXT_THRESHOLD) {
    console.log('{}');
  } else {
    console.log(JSON.stringify({
      decision: 'block',
      reason: `Context at ${pct}%. Run: /create_handoff`,
    }));
  }
}

main();
