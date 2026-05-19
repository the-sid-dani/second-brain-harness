#!/usr/bin/env node
// PreToolUse hook: when drafting/sending a Slack message to a known contact,
// emit their contact-file context to stderr so the model sees it.
//
// Why: prevents wrong-tone drafts to recurring contacts whose context (role,
// relationship, open commitments, last-interaction notes) lives in the
// contacts directory but isn't auto-loaded. Surfaces it just-in-time.
//
// Setup: drop a `.claude/.slack-id-map.json` at the project root mapping
// Slack user IDs to contact slugs:
//   {
//     "U05ABCDE1234": "alex-chen",
//     "U05ABCDE5678": "priya-patel"
//   }
// Each slug must match a file at <workspace.root>/3-Resources/contacts/<slug>.md.
// If either the map or a contact file is missing, the hook exits silently —
// the Slack tool call proceeds normally without context injection.
//
// Behavior: non-blocking warning. Hook reads stdin (Claude Code PreToolUse
// JSON), checks tool_name + channel_id, looks up in .claude/.slack-id-map.json,
// reads matching contact file from <workspace.root>/3-Resources/contacts/<slug>.md,
// emits frontmatter + first ~40 lines of body to stderr. Exit 0.
//
// Stderr from a PreToolUse hook is fed back to the model as additional context,
// so even though the tool call proceeds, the model sees the warning + contact
// summary on the next turn.

import { readFileSync, existsSync, readdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

let payload;
try {
  const input = readFileSync(0, "utf8");
  payload = JSON.parse(input);
} catch {
  process.exit(0);
}

const toolName = payload.tool_name || "";
const SLACK_WRITE_TOOLS = new Set([
  "mcp__slack__slack_send_message_draft",
  "mcp__slack__slack_send_message",
  "mcp__slack__slack_schedule_message",
]);
if (!SLACK_WRITE_TOOLS.has(toolName)) process.exit(0);

const channelId = payload.tool_input?.channel_id;
if (!channelId) process.exit(0);

const projectRoot = process.env.CLAUDE_PROJECT_DIR || resolve(__dirname, "..", "..");
const mapPath = `${projectRoot}/.claude/.slack-id-map.json`;
if (!existsSync(mapPath)) process.exit(0);

let map;
try {
  map = JSON.parse(readFileSync(mapPath, "utf8"));
} catch {
  process.exit(0);
}

const slug = map[channelId];
if (!slug || slug.startsWith("_")) process.exit(0);

// Auto-discover workspace root by globbing for */3-Resources/contacts/ at project root.
// Works for any workspace name (workspace, brain, vault, etc.) — set by /bootstrap.
let workspaceRoot = null;
try {
  for (const entry of readdirSync(projectRoot, { withFileTypes: true })) {
    if (entry.isDirectory() && existsSync(`${projectRoot}/${entry.name}/3-Resources/contacts`)) {
      workspaceRoot = entry.name;
      break;
    }
  }
} catch {
  process.exit(0);
}
if (!workspaceRoot) process.exit(0);

const contactPath = `${projectRoot}/${workspaceRoot}/3-Resources/contacts/${slug}.md`;
if (!existsSync(contactPath)) process.exit(0);

const contact = readFileSync(contactPath, "utf8");
const lines = contact.split("\n");
// Show frontmatter + first ~40 body lines (enough for About + Recurring topics + Open commitments preview)
const trimmed = lines.slice(0, 70).join("\n");

const warning = [
  "",
  `## ⚠️ Contact context for ${slug} (auto-loaded by pre-slack-draft-contact-check hook)`,
  "",
  "**Known recipient — you should have read this file BEFORE drafting.**",
  `**Path:** ${workspaceRoot}/3-Resources/contacts/${slug}.md`,
  "",
  "**Contact summary:**",
  "",
  trimmed,
  "",
  "---",
  "If the draft you just created doesn't match this context (wrong tone, missed open commitments, wrong relationship framing), REWRITE before the user sees it. Run `/contact " + slug + "` for the full file.",
  "",
].join("\n");

process.stderr.write(warning);
process.exit(0);
