#!/usr/bin/env node
/**
 * PostToolUse hook — run diagnostics after file edits.
 *
 * Runs `tldr diagnostics` on the edited file to catch type errors
 * and lint issues immediately after Edit/Write. Shift-left feedback
 * before tests run.
 *
 * Falls through silently if tldr not installed or diagnostics unavailable.
 */
import { readFileSync } from 'fs';
import { execSync } from 'child_process';
import { extname, basename } from 'path';

const ENABLED_EXTENSIONS = new Set([
  '.py', '.pyx', '.pyi',                    // Python: ruff + pyright
  '.ts', '.tsx', '.js', '.jsx', '.mjs',      // JS/TS: eslint + tsc
  '.rs',                                      // Rust: cargo check + clippy
]);

function main() {
  let data;
  try { data = JSON.parse(readFileSync(0, 'utf-8')); } catch { console.log('{}'); return; }

  const editTools = new Set(['Edit', 'Write', 'MultiEdit', 'Update']);
  if (!editTools.has(data.tool_name)) { console.log('{}'); return; }

  const filePath = (data.tool_input || {}).file_path || '';
  if (!filePath) { console.log('{}'); return; }

  const ext = extname(filePath);
  if (!ENABLED_EXTENSIONS.has(ext)) { console.log('{}'); return; }

  // Run tldr diagnostics on the file
  let result;
  try {
    result = execSync(`tldr diagnostics "${filePath}" --format json`, {
      encoding: 'utf-8', timeout: 15000, stdio: ['pipe', 'pipe', 'pipe'],
    });
  } catch { console.log('{}'); return; }

  let diag;
  try { diag = JSON.parse(result); } catch { console.log('{}'); return; }

  // Extract error counts — handle both flat and summary-wrapped formats
  const summary = diag.summary || diag;
  const typeErrors = summary.type_errors || 0;
  const lintIssues = summary.lint_errors || summary.lint_issues || 0;

  if (typeErrors === 0 && lintIssues === 0) { console.log('{}'); return; }

  // Build error summary
  const lines = [`Diagnostics: ${typeErrors} type errors, ${lintIssues} lint issues`];
  const errors = diag.errors || [];
  for (const err of errors.slice(0, 5)) {
    const loc = err.column ? `${basename(err.file || filePath)}:${err.line}:${err.column}` : `${basename(err.file || filePath)}:${err.line}`;
    lines.push(`   - ${loc}: ${err.message}`);
  }
  if (errors.length > 5) lines.push(`   ... and ${errors.length - 5} more`);

  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PostToolUse',
      additionalContext: lines.join('\n'),
    },
  }));
}

main();
