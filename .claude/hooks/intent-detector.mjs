#!/usr/bin/env node
/**
 * intent-detector.mjs — UserPromptSubmit hook v1 (LOG-ONLY)
 *
 * Item 7 of Pass 2c. Reads the user's prompt from stdin, regex-tests it
 * against a narrow set of project-lifecycle trigger patterns, and if any
 * match, appends a JSONL entry to .claude/intent-detector-log.jsonl. NEVER
 * injects context; NEVER blocks; ALWAYS exits 0.
 *
 * After 7 days of logging, audit the JSONL — true-positive rate, missed
 * triggers, false positives — then tune the regex set and ship v2 (item 8)
 * which keeps the same matching but ALSO emits additionalContext to suggest
 * the right slash command in-line.
 *
 * Why narrow first: a chatty hook trains the user to ignore suggestions.
 * A silent
 * v1 lets us measure precision/recall on real traffic without polluting the
 * conversation. Once we know which patterns fire correctly, v2 only suggests
 * on the high-precision ones.
 *
 * Failure modes are silent on purpose — a hook that errors loudly on every
 * prompt is worse than one that silently no-ops. Any uncaught error → exit 0.
 */

import { appendFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";

const main = async () => {
  // 1. Read stdin (Claude Code passes hook event as JSON)
  let raw = "";
  process.stdin.setEncoding("utf8");
  for await (const chunk of process.stdin) raw += chunk;

  let event;
  try {
    event = JSON.parse(raw);
  } catch {
    return; // can't parse → exit silently, don't block the user's prompt
  }

  const prompt = (event.prompt || "").toString();
  if (!prompt) return;

  // 2. Named pattern set. Keep narrow — recall < precision in v1. Each entry
  //    has a name (for audit), a regex, and the slash command we'd suggest
  //    in v2 if this fires.
  const patterns = [
    // /new-project triggers — both meta-project and code-repo cases
    { name: "new-project-explicit",     regex: /\bnew project\b/i,                                                 suggest: "/new-project" },
    { name: "start-a-project",          regex: /\b(start|kick off|kicking off|scaffold|spin up) (a |the |an )?(new )?project\b/i, suggest: "/new-project" },
    { name: "create-project-for",       regex: /\bcreate (a |the |an )?(new )?project (for|on|to|about)\b/i,        suggest: "/new-project" },
    { name: "set-up-deliverable",       regex: /\bset up (the |a |an )?(deck|memo|prep|plan|brief|doc|presentation|qbr|prd)\b/i, suggest: "/new-project" },
    { name: "track-properly",           regex: /\b(track|set up) (this|that|it|the X) (properly|with the assistant)\b/i,       suggest: "/new-project" },

    // /new-project code-repo branch triggers
    { name: "new-mcp-or-agent",         regex: /\bnew (mcp server|agent|library|cli tool|tool|bot|service|repo)\b/i, suggest: "/new-project (code-repo)" },
    { name: "spin-up-repo",             regex: /\bspin up (a |the |an )?(new )?repo\b/i,                            suggest: "/new-project (code-repo)" },
    { name: "scaffold-code",            regex: /\bscaffold (a |the |an )?(new )?(mcp|agent|repo|tool|server|library)\b/i, suggest: "/new-project (code-repo)" },

    // /archive-project triggers
    { name: "archive-named-project",    regex: /\barchive (the |a )?(\w+[- ]?){1,4}project\b/i,                     suggest: "/archive-project" },
    { name: "im-done-with",              regex: /\bI[''']?m done with (the )?[\w-]+\b/i,                              suggest: "/archive-project" },
    { name: "wrap-up-project",          regex: /\bwrap up (the )?[\w-]+( project| prep| memo| deck)?\b/i,            suggest: "/archive-project" },
    { name: "move-to-archive",          regex: /\bmove (\w+ )?to archive\b/i,                                        suggest: "/archive-project" },

    // /prune-projects triggers
    { name: "whats-stale",              regex: /\bwhat[''']?s stale( right now)?\??/i,                                suggest: "/prune-projects" },
    { name: "friday-review",            regex: /\b(friday review|friday cleanup)\b/i,                                suggest: "/prune-projects" },
    { name: "prune-projects-explicit",  regex: /\bprune projects?\b/i,                                                suggest: "/prune-projects" },
    { name: "what-should-archive",      regex: /\b(what|anything) (should I|to) (archive|close out|clean up)\b/i,    suggest: "/prune-projects" },
    { name: "review-my-projects",       regex: /\b(review my projects|whats? gone cold|any stale projects)\b/i,       suggest: "/prune-projects" },

    // /briefing triggers — chief-of-staff morning orient
    { name: "morning-briefing",         regex: /\b(morning briefing|daily brief|brief me|give me the rundown)\b/i,    suggest: "/briefing" },
    { name: "whats-on-my-plate",        regex: /\bwhat[''']?s on my plate( today)?\??/i,                              suggest: "/briefing" },
    { name: "orient-me",                regex: /\b(orient me|orient me for the day|where do I stand)\b/i,             suggest: "/briefing" },
    { name: "what-needs-me",            regex: /\bwhat needs (me|my attention)( today)?\b/i,                          suggest: "/briefing" },
    { name: "what-should-work-on",      regex: /\bwhat should I (work on|do first)( today| this morning)?\b/i,         suggest: "/briefing" },

    // /find triggers — recall existing knowledge
    { name: "find-explicit",            regex: /^\/?find\b/i,                                                          suggest: "/find" },
    { name: "do-i-have-on",             regex: /\bdo I have (anything|notes|research|something|a note) (on|about|for)\b/i, suggest: "/find" },
    { name: "what-do-i-know",           regex: /\bwhat do I (have|know) (on|about)\b/i,                                suggest: "/find" },
    { name: "search-my-notes",          regex: /\b(search|grep|look through) my (notes|vault|workspace|files)\b/i,     suggest: "/find" },
    { name: "what-did-i-save",          regex: /\bwhat did I (save|write|note) about\b/i,                              suggest: "/find" },
    { name: "is-there-a-note",          regex: /\bis there (a |any )?(note|project|research|doc) (on|for|about)\b/i,  suggest: "/find" },

    // /contact triggers — recall a person
    { name: "tell-me-about-person",     regex: /\btell me about \w+/i,                                                 suggest: "/contact" },
    { name: "who-is-x",                 regex: /\bwho is \w+( again)?\??/i,                                            suggest: "/contact" },
    { name: "context-on-person",        regex: /\b(what[''']?s my context with|context on|remind me about) \w+/i,      suggest: "/contact" },
    { name: "contact-explicit",         regex: /^\/?contact\b/i,                                                       suggest: "/contact" },

    // /contact-log triggers — write-mode, log an interaction
    { name: "log-meeting-with",         regex: /\b(log|record|append) (my )?(meeting|call|1[: -]?1|chat|conversation|sync) with \w+/i, suggest: "/contact-log" },
    { name: "just-talked-to",           regex: /\b(just (talked to|spoke with|met with|caught up with|had a call with)|just got off (a call|the phone) with) \w+/i, suggest: "/contact-log" },
    { name: "contact-log-explicit",     regex: /^\/?contact-log\b/i,                                                   suggest: "/contact-log" },

    // /save-resource triggers — stash something for later
    { name: "save-this-resource",       regex: /\b(save|stash|bookmark) (this|that|it)( for later| somewhere| in resources)?\b/i, suggest: "/save-resource" },
    { name: "save-resource-explicit",   regex: /^\/?save[- ]resource\b/i,                                              suggest: "/save-resource" },

    // /inbox-process triggers — Friday-style inbox triage
    { name: "process-inbox",            regex: /\b(process|triage|clear out|sort through) (the |my )?inbox\b/i,        suggest: "/inbox-process" },
    { name: "inbox-process-explicit",   regex: /^\/?inbox[- ]process\b/i,                                              suggest: "/inbox-process" },
    { name: "whats-in-my-inbox",        regex: /\bwhat[''']?s in (the |my )?inbox\b/i,                                  suggest: "/inbox-process" },

    // /thinking-partner triggers — exploration mode
    { name: "thinking-partner-explicit", regex: /\b(be (a |my )?thinking partner|thinking partner mode|sounding board)\b/i, suggest: "/thinking-partner" },
    { name: "lets-think-through",       regex: /\blet[''']?s (think through|noodle on|explore|talk through|work through)\b/i, suggest: "/thinking-partner" },
    { name: "help-me-explore",          regex: /\bhelp me (explore|think about|work through|noodle on)\b/i,            suggest: "/thinking-partner" },

    // /sync-indexes triggers — code-repo bookkeeping audit
    { name: "sync-indexes-explicit",    regex: /\b(sync indexes|sync code projects|audit code repos)\b/i,              suggest: "/sync-indexes" },
    { name: "orphan-repos",             regex: /\b(orphan repos|whats? in 2-Coding|whats? in coding that isn[''']?t)\b/i, suggest: "/sync-indexes" },
  ];

  // 3. Test all patterns. Multiple may match (e.g., "new MCP server project" hits two).
  const matches = patterns
    .filter((p) => p.regex.test(prompt))
    .map((p) => ({ name: p.name, suggest: p.suggest }));

  if (matches.length === 0) return;

  // 4. Append to JSONL log. Bound the prompt size in the log so secrets / huge
  //    pastes don't get persisted forever.
  const cwd = event.cwd || process.cwd();
  const logFile = join(cwd, ".claude", "intent-detector-log.jsonl");
  const logDir = dirname(logFile);
  if (!existsSync(logDir)) mkdirSync(logDir, { recursive: true });

  const entry = {
    ts: new Date().toISOString(),
    matched: matches.map((m) => m.name),
    would_suggest: [...new Set(matches.map((m) => m.suggest))],
    prompt: prompt.length > 500 ? prompt.slice(0, 500) + "…" : prompt,
    session_id: event.session_id || null,
  };

  try {
    appendFileSync(logFile, JSON.stringify(entry) + "\n");
  } catch {
    // Disk full, permissions, whatever — silent. The user's prompt must not be blocked.
  }
};

// v1 contract: never inject context, never block. Any path → exit 0.
main()
  .catch(() => {})
  .finally(() => process.exit(0));
