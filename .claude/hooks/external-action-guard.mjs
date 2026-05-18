#!/usr/bin/env node
/**
 * PreToolUse hook — show-and-confirm friction on irreversible external actions.
 *
 * Four sub-handlers, dispatched by tool name:
 *
 *   62a. Slack send guard       — mcp__slack__slack_send_message |
 *                                  slack_schedule_message
 *   62b. GitHub destructive-push — Bash matching `git push --force` OR
 *                                  `git push` targeting main/master
 *   62c. Atlassian write guard  — mcp__atlassian__(create|edit|transition|
 *                                  add|update|delete).*
 *   62d. rm -rf guard           — Bash matching `rm -rf` outside a whitelist
 *
 * Output is `permissionDecision: "ask"` (modern hookSpecificOutput format).
 * Per locked decision 2026-05-17: blocks are show-and-confirm, not
 * show-and-deny. Goal is friction at the moment of action, not refusal.
 *
 * Spec: locked decision — show-and-confirm friction on irreversible external
 *       actions (Slack send, force push to main/master, Atlassian writes,
 *       rm -rf outside whitelisted paths).
 *
 * Performance: Bash fires constantly. handleBash() exits in <1ms on the 99%
 * case via plain string includes() before any regex runs.
 *
 * Failure-mode discipline: any uncaught error → exit 0 (action proceeds).
 * A hook that errors on every prompt is worse than one that misses.
 */

// rm -rf is allowed (silently) when the target path matches one of these
// fragments. Covers transient build/cache state and explicit /tmp scratch.
const SAFE_RM_PATHS = [
  "/tmp/",
  "node_modules/",
  "__pycache__/",
  ".venv/",
  "dist/",
  "build/",
  ".tldr/",
  ".workflow/",
];

const SLACK_SEND_TOOLS = new Set([
  "mcp__slack__slack_send_message",
  "mcp__slack__slack_schedule_message",
]);

// Atlassian MCP write/mutate tools (Jira + Confluence). Reads (get*, search*,
// fetch) and metadata calls (getJiraProject*, atlassianUserInfo) are NOT
// guarded — they're idempotent and safe.
const ATLASSIAN_WRITE_TOOLS = new Set([
  "mcp__atlassian__createJiraIssue",
  "mcp__atlassian__editJiraIssue",
  "mcp__atlassian__transitionJiraIssue",
  "mcp__atlassian__addCommentToJiraIssue",
  "mcp__atlassian__addWorklogToJiraIssue",
  "mcp__atlassian__createIssueLink",
  "mcp__atlassian__createConfluencePage",
  "mcp__atlassian__updateConfluencePage",
  "mcp__atlassian__createConfluenceFooterComment",
  "mcp__atlassian__createConfluenceInlineComment",
]);

function truncate(s, n = 200) {
  return s.length > n ? s.slice(0, n) + "…" : s;
}

// 62b + 62d: dispatch on the bash command content.
function handleBash(toolInput) {
  const cmd = (toolInput.command || "").toString();
  if (!cmd) return null;

  // Fast string filter — most bash commands aren't destructive
  const hasRm = cmd.includes("rm -rf") || cmd.includes("rm -fr");
  const hasGitPush = cmd.includes("git push");
  if (!hasRm && !hasGitPush) return null;

  // 62d. rm -rf guard
  if (hasRm) {
    // Extract the FIRST positional arg after `rm -rf` for whitelist check.
    // (Multi-arg rm -rf could have a mix; we check the first; user can review
    // the full command in the surfaced preview.)
    const match = cmd.match(/\brm\s+-(?:rf|fr)\s+(\S+)/);
    const path = match ? match[1] : "<unparseable>";

    const safe = SAFE_RM_PATHS.some((s) => path.includes(s));
    if (safe) return null;

    return [
      "🛑 Destructive `rm -rf` detected outside whitelist:",
      "",
      `  ${truncate(cmd)}`,
      "",
      `Parsed target: ${path}`,
      "",
      `Auto-allowed paths: ${SAFE_RM_PATHS.join(", ")}`,
      "",
      "This op is irreversible. Confirm only if you're certain.",
    ].join("\n");
  }

  // 62b. GitHub destructive-push guard
  if (hasGitPush) {
    const isForce = /git push\s+(?:[^\n]*\s)?--force\b/.test(cmd) ||
                    /git push\s+(?:[^\n]*\s)?-f\b/.test(cmd) ||
                    cmd.includes("--force-with-lease");
    const isMain = /git push\s+\w+\s+(?:HEAD:)?(main|master)\b/.test(cmd) ||
                   /git push.*\bHEAD:(main|master)\b/.test(cmd);

    if (!isForce && !isMain) return null; // regular push to feature branch — allow

    const flags = [];
    if (isForce) flags.push("force-push");
    if (isMain) flags.push("push to main/master");

    return [
      `🛑 Destructive git push detected (${flags.join(" + ")}):`,
      "",
      `  ${truncate(cmd)}`,
      "",
      "Force-pushes rewrite history; pushes to main affect everyone with the remote.",
      "Confirm only if you're certain.",
    ].join("\n");
  }

  return null;
}

// 62a. Slack send guard
function handleSlackSend(toolName, toolInput) {
  const channel = toolInput.channel_id || toolInput.channel || toolInput.channel_name || "<unknown channel>";
  const text = (toolInput.text || toolInput.markdown_text || "").toString();
  const preview = truncate(text);
  const scheduleNote = toolName === "mcp__slack__slack_schedule_message"
    ? `\n  Scheduled for: ${toolInput.post_at || "<unspecified>"}`
    : "";

  return [
    "📨 About to send Slack message — confirm send?",
    "",
    `Tool: ${toolName}`,
    `Channel: ${channel}${scheduleNote}`,
    "",
    "Message preview:",
    ...preview.split("\n").map((l) => "  > " + l),
    "",
    "Slack sends are immediate and visible to channel members.",
    "Per locked rule: no auto-send to messaging surfaces without explicit user approval.",
  ].join("\n");
}

// 62c. Atlassian write guard
function handleAtlassianWrite(toolName, toolInput) {
  const action = toolName.replace("mcp__atlassian__", "");

  // Identify the target resource if possible
  let identity = "(new resource)";
  if (toolInput.issueIdOrKey) identity = `issue ${toolInput.issueIdOrKey}`;
  else if (toolInput.pageId) identity = `page ${toolInput.pageId}`;
  else if (toolInput.projectKey) identity = `project ${toolInput.projectKey}`;
  else if (toolInput.spaceKey || toolInput.spaceId) identity = `space ${toolInput.spaceKey || toolInput.spaceId}`;

  return [
    `🎫 About to perform Atlassian write: ${action}`,
    "",
    `Target: ${identity}`,
    "",
    "This mutates live Atlassian state (Jira tickets / Confluence pages).",
    "Load-bearing during `/scaffold-engineering-project` bulk-create runs —",
    "a misconfigured spec can create dozens of unwanted tickets.",
    "",
    "Confirm only if you intend this exact mutation.",
  ].join("\n");
}

const main = async () => {
  let raw = "";
  process.stdin.setEncoding("utf8");
  for await (const chunk of process.stdin) raw += chunk;

  let event;
  try {
    event = JSON.parse(raw);
  } catch {
    return;
  }

  const toolName = event.tool_name;
  const toolInput = event.tool_input || {};
  if (!toolName) return;

  let reason = null;

  if (toolName === "Bash") {
    reason = handleBash(toolInput);
  } else if (SLACK_SEND_TOOLS.has(toolName)) {
    reason = handleSlackSend(toolName, toolInput);
  } else if (ATLASSIAN_WRITE_TOOLS.has(toolName)) {
    reason = handleAtlassianWrite(toolName, toolInput);
  }

  if (!reason) return;

  // Modern hookSpecificOutput format. permissionDecision: "ask" prompts the
  // user — this is the "show-and-confirm" semantics we want.
  const output = {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: reason,
    },
  };

  process.stdout.write(JSON.stringify(output));
};

main()
  .catch(() => {})
  .finally(() => process.exit(0));
