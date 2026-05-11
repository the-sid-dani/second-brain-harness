#!/usr/bin/env node
/**
 * PreCompact hook — auto-handoff before context compaction.
 *
 * Parses transcript JSONL, extracts session state (todos, tool calls,
 * files modified, errors), writes auto-handoff to thoughts/shared/handoffs/.
 *
 * Input: JSON with trigger, session_id, transcript_path
 * Output: JSON with continue: true, systemMessage
 *
 * VAL-020 fix 2026-05-11: generateHandoff() returns BODY only — no
 * frontmatter. trigger/session metadata is passed to writeHandoff() via
 * `extra` so a single YAML block (date/type/trigger/session/project_root/
 * repo_root) is emitted. Two stacked frontmatter blocks broke
 * /resume-handoff (parser only reads the first; project_root was in the
 * second and got dropped).
 */
import { readFileSync, existsSync } from 'fs';
import { writeHandoff } from './lib/handoff-writer.mjs';

function parseTranscript(transcriptPath) {
  const summary = {
    lastTodos: [],
    recentToolCalls: [],
    lastAssistantMessage: '',
    filesModified: new Set(),
    errors: [],
  };
  if (!existsSync(transcriptPath)) return summary;

  let content;
  try { content = readFileSync(transcriptPath, 'utf-8'); } catch { return summary; }

  const allToolCalls = [];
  let lastAssistant = '';

  for (const line of content.split('\n')) {
    if (!line.trim()) continue;
    let entry;
    try { entry = JSON.parse(line); } catch { continue; }

    // Last assistant message
    if ((entry.role === 'assistant' || entry.type === 'assistant') && typeof entry.content === 'string') {
      lastAssistant = entry.content;
    }

    // Tool calls
    const toolName = entry.tool_name || (entry.type === 'tool_use' ? entry.name : null);
    if (toolName) {
      const tc = { name: toolName, input: entry.tool_input, success: true };

      if (toolName.toLowerCase() === 'todowrite') {
        const todos = (entry.tool_input || {}).todos || [];
        summary.lastTodos = todos.map((t, i) => ({
          id: t.id || `todo-${i}`,
          content: t.content || '',
          status: t.status || 'pending',
        }));
      }

      if (['edit', 'write'].includes(toolName.toLowerCase())) {
        const fp = (entry.tool_input || {}).file_path || (entry.tool_input || {}).path;
        if (fp) summary.filesModified.add(fp);
      }

      if (toolName.toLowerCase() === 'bash' && (entry.tool_input || {}).command) {
        tc.input = { command: entry.tool_input.command };
      }

      allToolCalls.push(tc);
    }

    // Errors from tool results
    if (entry.type === 'tool_result' || entry.tool_result != null) {
      const result = entry.tool_result || {};
      if (typeof result === 'object') {
        const exitCode = result.exit_code ?? result.exitCode;
        if (exitCode != null && exitCode !== 0) {
          if (allToolCalls.length) allToolCalls[allToolCalls.length - 1].success = false;
          const msg = result.stderr || result.error || 'Command failed';
          const cmd = allToolCalls.length ? (allToolCalls[allToolCalls.length - 1].input || {}).command || 'unknown' : 'unknown';
          summary.errors.push(`${cmd}: ${msg.slice(0, 200)}`);
        }
      }
      if (entry.error) {
        summary.errors.push(entry.error.slice(0, 200));
        if (allToolCalls.length) allToolCalls[allToolCalls.length - 1].success = false;
      }
    }
  }

  summary.recentToolCalls = allToolCalls.slice(-5);
  summary.lastAssistantMessage = lastAssistant.slice(0, 500);
  summary.errors = summary.errors.slice(-5);
  return summary;
}

function generateHandoff(summary, sessionName) {
  // Body only — frontmatter is emitted by writeHandoff() in handoff-writer.mjs.
  // trigger/session live in the `extra` field passed by main().
  const lines = [
    '# Auto-Handoff (PreCompact)', '',
    'This handoff was automatically generated before context compaction.', '',
    '## In Progress', '',
  ];

  if (summary.lastTodos.length) {
    const inProgress = summary.lastTodos.filter(t => t.status === 'in_progress');
    const pending = summary.lastTodos.filter(t => t.status === 'pending');
    const completed = summary.lastTodos.filter(t => t.status === 'completed');
    if (inProgress.length) { lines.push('**Active:**'); inProgress.forEach(t => lines.push(`- [>] ${t.content}`)); lines.push(''); }
    if (pending.length) { lines.push('**Pending:**'); pending.forEach(t => lines.push(`- [ ] ${t.content}`)); lines.push(''); }
    if (completed.length) { lines.push('**Completed this session:**'); completed.forEach(t => lines.push(`- [x] ${t.content}`)); lines.push(''); }
  } else {
    lines.push('No TodoWrite state captured.', '');
  }

  lines.push('## Recent Actions', '');
  if (summary.recentToolCalls.length) {
    for (const tc of summary.recentToolCalls) {
      const status = tc.success ? 'OK' : 'FAILED';
      const inp = tc.input ? ` - ${JSON.stringify(tc.input).slice(0, 80)}...` : '';
      lines.push(`- ${tc.name} [${status}]${inp}`);
    }
  } else lines.push('No tool calls recorded.');
  lines.push('');

  lines.push('## Files Modified', '');
  const files = [...summary.filesModified];
  if (files.length) files.forEach(f => lines.push(`- ${f}`));
  else lines.push('No files modified.');
  lines.push('');

  if (summary.errors.length) {
    lines.push('## Errors Encountered', '');
    summary.errors.forEach(e => lines.push('```', e, '```'));
    lines.push('');
  }

  lines.push('## Last Context', '');
  if (summary.lastAssistantMessage) {
    lines.push('```', summary.lastAssistantMessage);
    if (summary.lastAssistantMessage.length >= 500) lines.push('[... truncated]');
    lines.push('```');
  } else lines.push('No assistant message captured.');
  lines.push('');

  lines.push('## Suggested Next Steps', '',
    '1. Review the "In Progress" section for current task state',
    '2. Check "Errors Encountered" if debugging issues',
    '3. Read modified files to understand recent changes',
    '4. Continue from where session left off', '');

  return lines.join('\n');
}

function main() {
  const input = JSON.parse(readFileSync(0, 'utf-8'));
  const trigger = input.trigger || 'auto';
  const sessionId = input.session_id || 'unknown';
  const sessionName = sessionId.slice(0, 8) || 'unknown';
  const transcriptPath = input.transcript_path || '';

  let message;
  if (trigger === 'auto' && transcriptPath && existsSync(transcriptPath)) {
    const summary = parseTranscript(transcriptPath);
    const content = generateHandoff(summary, sessionName);
    const ts = new Date().toISOString();
    const { path, projectRoot } = writeHandoff({
      kind: 'auto-handoff',
      sessionName,
      body: content,
      ts,
      cwd: process.env.CLAUDE_PROJECT_DIR || process.cwd(),
      extra: { trigger: 'pre-compact-auto', session: sessionName }
    });
    message = `[PreCompact:auto] Created ${path} (project: ${projectRoot})`;
  } else if (trigger === 'auto') {
    message = '[PreCompact:auto] No transcript available. Consider running /create_handoff manually.';
  } else {
    message = '[PreCompact] Consider running /create_handoff before compacting.';
  }

  console.log(JSON.stringify({ continue: true, systemMessage: message }));
}

main();
