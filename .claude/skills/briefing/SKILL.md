---
name: briefing
description: Morning chief-of-staff briefing — composes available signal sources (email, calendar, messaging, issue-tracking, code-hosting) plus local sources (contacts, active projects, USER.md priorities) into one self-contained HTML brief at `<workspace.root>/<workspace.resources>/briefings/morning-briefing-YYYY-MM-DD.html`. Detects tool availability at runtime in Step 0.5 so fork users with zero MCPs still get a useful brief from local state. Use when <user.name> asks to start the day or surface what needs attention — phrases like "/briefing", "brief me", "what's on my plate today", "what should I work on today". Trigger broadly on day-orientation language. Filters `status: personal` contacts; never auto-sends; never fabricates absent signals (see SKILL.md body for invariants T1-T4).
allowed-tools: Read Write Glob Bash AskUserQuestion Skill mcp__slack__slack_search_public_and_private mcp__slack__slack_search_channels mcp__atlassian__searchJiraIssuesUsingJql
---

# briefing

The chief-of-staff morning brief. Probes which signal sources are available, composes only the ones present, and assembles a single structured document at `<workspace.root>/<workspace.resources>/briefings/morning-briefing-YYYY-MM-DD.html`. Applies the user's priority signals, surfaces what needs them today, and recommends what to ship from each active project. Closes with a "Tools used" footer section transparently listing what was composed vs what was not configured — fork users with zero MCPs still get a useful brief from workspace state alone.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.resources>` and `<scripts.project_query>` resolve from there — don't hardcode.

## Why this exists

<user.name> wants <assistant.name> to be a chief-of-staff, not a search engine. The morning brief is the single highest-value moment of the day: cross-referencing whatever signal sources are configured (email, calendar, messaging, issue-tracking, code-hosting) + project state to surface what *actually* needs attention vs what's noise. Before this skill, that ritual was a 4-tab manual scan that took 15 minutes and missed half the signal — and worse, didn't connect it to the active projects' plans.

`/briefing` is the answer to "Morning <user.name>, here's the lay of the land — and here's what to ship today." Its **mandatory floor** runs with zero external tools: read the active-projects index, tail each project's `memory.md`, read USER.md priority signals, read contacts. Its **optional composition layer** uses whatever's configured — `gws-gmail-triage`/`gws-calendar-agenda` (if `gws` CLI is installed), `mcp__slack__*` (if Slack MCP is authorized), `mcp__atlassian__*` (if Atlassian MCP is authorized), `gh pr list` (if `gh` CLI is installed), `/find` (always present, optional last step). Step 0.5 detects what's available at runtime; later steps gate on that map.

The novel piece is the **project synthesis layer**: reading each active project's `memory.md` tail and `CLAUDE.md` status to recommend today's highest-leverage work. That layer is mandatory-floor — works whether <user.name> has a fully-configured multi-MCP stack or no MCPs at all.

This is the Pass 3 headliner of the second-brain project. After this ships, `/meeting-prep` (item 17), `/standup` (item 18), and `/weekly-digest` (item 19) become wrappers around the same probe-then-compose pattern.

## When to use

Trigger phrases (broad — day-orientation is the pattern, not the literal command):

- `/briefing` / `/briefing for today`
- "morning briefing" / "daily brief" / "give me the rundown"
- "what's on my plate today?" / "what needs me today?"
- "orient me for the day" / "what should I tackle first?"
- "what should I work on today" — directly hits the project-synthesis layer
- "brief me" (when context is start-of-day)
- "morning <assistant.name>" / "good morning" — reactive opener to a new session

Do NOT trigger for:
- Per-meeting prep — that's `/meeting-prep` (item 17, separate skill).
- Weekly recap — that's `/weekly-digest` (item 19).
- Standup-only output — that's `/standup` (item 18). `/briefing` is broader (includes Slack, Jira, calendar, etc.); `/standup` is project-memory-focused only.
- A literal question like "what is a briefing?" or "draft a briefing template" — that's content, not invocation.
- Sending the brief somewhere — briefing writes a local file, never auto-sends. If <user.name> wants to share it, they say so explicitly.

## Source of truth

- **Output convention** — `<workspace.root>/<workspace.resources>/briefings/morning-briefing-YYYY-MM-DD.html` per README §Outputs. Briefings live next to `meetings/` (raw transcripts) in Resources, since briefings are reference material the user re-reads. Path moved here from a top-level `docs/` folder in v0.1.5 — Resources is the right PARA home for synthesis-layer outputs.
- **Priority signals** — read at runtime from USER.md "Priority Signals" section. Per fork, <user.name>'s collaborators / urgency rules differ.
- **Contacts directory** — `<workspace.root>/<workspace.resources>/contacts/<slug>.md`. Schema documented at `<workspace.root>/<workspace.resources>/contacts/README.md`.
- **Active projects** — `bash <scripts.project_query>` returns live tabular view (status, project-type, days-since-touched, stale flag). Each project has its own `CLAUDE.md` (status frontmatter) and `memory.md` (append-only decision log).
- **Tool inventory** — `<workspace.root>/<workspace.resources>/reference/tool-inventory.md` §10 has the canonical Layer 3 design implications + composition map.

## Tiger-grade invariants (LOAD-BEARING — DO NOT VIOLATE)

These four invariants protect against high-cost failure modes. They are stated multiple times throughout this skill (in description, here, in step headers, in failure modes table) by design — premortem-tier risks need redundancy.

### T1 — Output path is fixed

Briefing output **always** lands at `<workspace.root>/<workspace.resources>/briefings/morning-briefing-YYYY-MM-DD.html`. The date is today's date in `YYYY-MM-DD` format. Never at workspace root. Never inside a project folder. Never in `<workspace.inbox>/`. Never `morning-briefing.html` (no date suffix). Never `.md` (HTML-only output as of v0.2.0; markdown source path retired — see Step 9).

If the file already exists for today (re-running the briefing same-day), append a timestamp: `<workspace.root>/<workspace.resources>/briefings/morning-briefing-YYYY-MM-DD-HHMM.html`. Do not overwrite the original — <user.name> may have read or edited it.

### T2 — Filter `status: personal` contacts BEFORE building "Open commitments by person"

The contacts directory holds both work AND personal contacts (per decision #22 status enum: `active | inactive | external | personal`). Briefing is a **work-context skill**. Personal contacts (friends, family, side-project collaborators) are intentionally segregated and must never bleed into a work brief.

Implementation: when iterating `<workspace.resources>/contacts/<slug>.md` files, parse frontmatter and skip any where `status: personal`. Do this at read time, not display time — stripping at display means the data was still loaded into context and could leak via summarization.

### T3 — Never fabricate signals

When an MCP returns empty (no Jira tickets, no Slack messages, no calendar events), the corresponding section either:
- **Omits entirely** — clean output, no awkward empty headers
- OR writes a single line like "No active Jira tickets" / "No unread Slack mentions" / "Calendar is clear today"

Never invent fake tickets, fake messages, fake meetings, fake commitments, or fake project recommendations. The "Today's work from your projects" section is especially exposed here — if a project has a thin or empty `memory.md`, surface that fact ("project X has no recent memory entries — consider a `/standup` to refresh") rather than invent next-actions. If a tool errors at runtime (was detected as present but failed mid-call), surface the error in the section's place: "⚠️ Slack MCP errored — skipping Slack digest." Briefing accuracy is the entire value proposition; fabricated content makes it actively harmful.

### T4 — Graceful degradation when tools are absent

The briefing has a **mandatory floor** that runs with zero external tools: project synthesis (Step 7), open commitments (Step 5), today's date, USER.md priority signals. Everything else is **optional composition** gated on tool detection in Step 0.5.

For each gated step (Gmail, Calendar, Slack, Jira, GitHub):
- **If the underlying tool is NOT in the detection map** (`gws` not installed, `mcp__slack__*` not in deferred-tools list, etc.): omit the section entirely from the brief body. NEVER write a "⚠️ X not configured" line into the body — that's noise for users who never wanted that tool. Footer (Step 9) documents the omission transparently.
- **If the tool IS detected but errors at runtime** (auth expired, network failure, MCP returned an error): write a single ⚠️ line in the section's place ("⚠️ Slack MCP errored — skipping Slack digest") AND log to the footer.
- **Never fabricate a tool call.** If `gws` is absent, do NOT invent fake Gmail entries to fill the section. If Slack MCP isn't loaded, do NOT make up Slack messages to flesh out the brief. T3 governs this; T4 codifies that absent tools are FIRST-CLASS state, not an error to paper over.

The `## Tools used` footer at the bottom of every brief lists which signal sources were composed vs which were not configured vs which errored. This is the single source of truth for "what's in this brief" — never invent a section header that the footer doesn't back.

Fork users with zero MCPs still get a useful brief from the mandatory floor: project memory tails, today-relevant signals, priority-ranked synthesis. That's not a degraded experience; that's the floor of the value proposition.

## Process

### Step 0: Load context (parallel reads, cheap)

Run these in parallel via separate tool calls (no dependencies between them):

1. **Today's date** — Bash: `date +%Y-%m-%d` and `date +%H:%M` for the header.
2. **USER.md priority signals** — Read root `USER.md`, locate "Priority Signals" section. Extract:
   - Direct collaborators list (high-priority senders)
   - URGENT triggers (calendar conflicts, team blockers)
   - HIGH topics (e.g., AI/technical for <user.name>)
   - LOW filters (newsletters, generic updates)
3. **Active projects** — Bash: `bash <scripts.project_query>` (no flags = active only). Cache the rows (slug, status, project-type, days-since-touched) for Step 7's project synthesis.
4. **Contacts list** — Bash: `ls <workspace.root>/<workspace.resources>/contacts/*.md` to get the file list (NOT the contents — those come in Step 5).
5. **Briefing output path** — compute target file path: `<workspace.root>/<workspace.resources>/briefings/morning-briefing-${DATE}.html`. If it already exists, set the path to `<workspace.root>/<workspace.resources>/briefings/morning-briefing-${DATE}-${TIME}.html` per T1.
6. **Active design tokens** — Bash: `cat DESIGN.md` (cwd-relative — resolves to the active DESIGN.md whether root-level or project-overridden). Cache the file content for Step 9 — colors, typography, spacing all come from there. Required for HTML composition. If `DESIGN.md` does not exist at cwd, fall back to the neutral defaults inlined in Step 9's CSS scaffold and surface a one-line `⚠️` in the footer ("DESIGN.md not found — used neutral defaults"); never invent tokens.

### Step 0.5: Detect available tools (probe-then-compose — T4 invariant)

Build a `detection` map that gates Steps 1, 2, 3, 4, 6. **This step is what enables fork users with any tool stack (or none) to get a useful brief.** Pattern modeled after `/bootstrap` Phase 1's MCP probe (added in v0.1.4).

Run these probes in parallel:

```bash
command -v gws 2>&1            # detection.cli.gws — gates Steps 1 (Gmail) + 2 (Calendar)
command -v gh 2>&1             # detection.cli.gh — gates Step 6 (GitHub recent shipped)
```

For each MCP, check the **deferred-tools list at the top of the session** (the system reminder that lists `mcp__<name>__*` tools available for this workspace):

- `detection.mcp.slack = true` if ≥1 `mcp__slack__*` tool appears (gates Step 3 — Slack digest)
- `detection.mcp.atlassian = true` if ≥1 `mcp__atlassian__*` tool appears (gates Step 4 — Jira queue)

**Honesty rules** (T4):
- If `command -v gws` exits 0 → `detection.cli.gws = true`; CLI is callable, but the user's `gws auth status` may still be unauth'd. That's a runtime-error case handled in Step 1, not a not-configured case.
- If a `mcp__<name>__*` tool is in the deferred-tools list → the MCP server is loaded and authorized for THIS workspace cwd (Claude Code isolates OAuth state per-project — see bootstrap Phase 1 §honesty rule).
- If a tool is absent from the detection map → the section it backs is omitted silently from the brief body (no `⚠️ X not configured` line). The `## Tools used` footer in Step 9 documents the omission.
- Never gate on a tool's CONTENT (e.g., "did Gmail return ≥1 unread") — that's a runtime concern. Step 0.5 only checks availability.

**Output**: a cached `detection` map used by every subsequent step. Example shapes:

```
# A fully-configured fork:
detection = {cli: {gws: true, gh: true}, mcp: {slack: true, atlassian: true}}
# A partial fork (no MCPs auth'd, but gh is installed):
detection = {cli: {gws: false, gh: true}, mcp: {slack: false, atlassian: false}}
# Zero-tool fork (mandatory floor only):
detection = {cli: {gws: false, gh: false}, mcp: {slack: false, atlassian: false}}
```

The zero-tool case still produces a useful brief — Steps 5 (commitments), 7 (project synthesis), 8 (find cross-refs) all run from local files. That's the floor.

### Step 1: Gmail triage — "What needs you today" inputs

**Gate (T4):** runs ONLY if `detection.cli.gws == true`. If false, skip this step entirely — no section header, no `⚠️` line in the body. The `## Tools used` footer (Step 9) will list Gmail as "not configured."

**Compose the `gws-gmail-triage` skill via the Skill tool** (not raw `gws` Bash). The wrapped skill normalizes the GWS CLI's `--params '{"userId": "me"}'` JSON shape — direct Bash invocation requires schema knowledge that the skill abstracts away. Returns unread inbox summary with sender, subject, date.

Apply USER.md priority signals to classify each unread:
- **URGENT** — sender is in direct-collaborators list AND subject contains an urgency keyword (deadline, blocker, ASAP, urgent), OR sender is the user's manager
- **HIGH** — sender in direct-collaborators OR topic matches HIGH list (e.g., AI/technical)
- **STANDARD** — everything else
- **LOW (filter out from brief)** — newsletters, generic updates per LOW filter

Output: a list of (URGENT + HIGH) entries only — no more than ~7. STANDARD goes into a count ("plus 12 standard unreads"). LOW is excluded entirely.

If `gws-gmail-triage` errors at runtime (e.g., `gws` is installed but auth expired): write "⚠️ Gmail errored — <one-line cause>" in the section and note in the footer. If it returns empty (no unreads): write "No urgent unreads." Distinguish: not-detected = silent omit (Step 0.5 gate); detected-but-errored = ⚠️ line; detected-and-empty = "No urgent unreads."

### Step 2: Calendar agenda — "Calendar at a glance" + conflict detection

**Gate (T4):** runs ONLY if `detection.cli.gws == true`. If false, skip this step entirely — no section in body. Footer documents "not configured."

**Compose the `gws-calendar-agenda` skill via the Skill tool** (not raw `gws` Bash). Same reason as Step 1 — the skill normalizes the `--params` JSON shape. Returns today's events across all calendars.

Process:
- Sort by start time
- Detect conflicts (overlapping events) — flag with 🔴 emoji per USER.md formatting prefs (status indicators OK in briefings)
- Note any events with no description / no attendees as a tag (might need prep)
- Pull next 3 events specifically for the "What needs you today" section

If `gws-calendar-agenda` errors at runtime: write "⚠️ Calendar errored — <one-line cause>" + log to footer. Do not invent events. If it returns empty: "Calendar is clear today."

### Step 3: Slack digest — DYNAMIC channel enumeration

**Gate (T4):** runs ONLY if `detection.mcp.slack == true` (≥1 `mcp__slack__*` tool in the deferred-tools list). If false, skip entirely — no section in body. Footer documents "not configured." Per T4, do NOT write "⚠️ Slack not configured" inline; that's noise for users who never configured Slack.

No hardcoded channel list. Instead, enumerate channels at runtime and surface signal:

1. **Get @-mentions across all channels** — `mcp__slack__slack_search_public_and_private` with query `@<user.slack_handle>` (or `@me` if MCP supports it), filtered to last 24h. This catches everything no matter which channel.
2. **Get the user's channel membership** — `mcp__slack__slack_search_channels` (no query → returns the channel list, including channels the user is a member of).
3. **For each channel with high recent activity** (>10 unread messages in last 24h, threshold tunable via USER.md), surface a one-line digest: top message by reaction count, or thread the user participated in that has a new reply.
4. **Optionally check DMs** — `slack_search_public_and_private` with `is:dm` filter for any unread DM threads where the last message is from someone other than <user.name>.

**Timestamp quirk to know about:** `slack_search_public_and_private` sometimes returns far-future literal dates ("year 56347xxx") due to a Slack search index quirk. The *message content* is real and current. Frame surfaced messages by relative recency ("today", "yesterday", "earlier this morning") rather than echoing the literal date column. Don't show the noisy date strings to <user.name>.

Output structure:
- @-mentions across all channels — top 5
- Active channels — top 3 most-active channels with one-line digest each
- Threads where <user.name> may owe a reply — top 3

If a USER.md "Priority Slack Channels" section exists in the future, prepend those channels to the active-channels list. Otherwise rely on dynamic enumeration. Surface a hint at section bottom: *"💡 To pin specific channels to the top of this digest, add a `## Priority Slack Channels` section to USER.md."*

If Slack MCP errors at runtime (was detected but call failed): write "⚠️ Slack MCP errored — <one-line cause>" + log to footer. Do not invent messages.

### Step 4: Jira queue

**Gate (T4):** runs ONLY if `detection.mcp.atlassian == true` (≥1 `mcp__atlassian__*` tool in the deferred-tools list). If false, skip entirely — no section in body. Footer documents "not configured."

Compose `mcp__atlassian__searchJiraIssuesUsingJql` with query: `assignee = currentUser() AND status != Done ORDER BY duedate ASC, priority DESC`.

Process:
- Group by status (In Progress / To Do / Blocked)
- Flag past-due (duedate < today) with 🔴
- Surface top ~7

If Atlassian MCP errors at runtime: write "⚠️ Jira MCP errored — <one-line cause>" + log to footer. If it returns empty: "No active Jira tickets."

### Step 5: Open commitments by person — T2 INVARIANT (filter `status: personal`)

**T2 reminder: filter `status: personal` BEFORE reading body content.** This is a work-context skill — personal contacts never appear here.

Process:
1. For each contact file at `<workspace.root>/<workspace.resources>/contacts/<slug>.md`:
   - Read frontmatter only first (Bash: `head -30 <file>`)
   - Parse `status:` field
   - **If `status: personal`, SKIP this file entirely.** Do not read body. Do not include slug in any subsequent step.
2. For each remaining contact (status `active`, `inactive`, or `external`):
   - Read full file
   - Parse `## Open commitments` section
   - Extract "From <name>" subsection (things the contact has promised the user)
   - Extract "To <name>" subsection (things the user has promised the contact) — flag any that are stale (>14 days since logged)
3. Compose section:
   - Group by contact name
   - Use WikiLink format: `[[contacts/<slug>]]` per decision #19
   - Surface only contacts with at least one open commitment

If a contact file has no `## Open commitments` section, skip silently — not all contacts have one yet.

If contacts directory is empty: per T3, write "No contacts logged yet — run `/contact-add` to start tracking commitments by person."

### Step 6: GitHub recent shipped

**Gate (T4):** runs ONLY if `detection.cli.gh == true`. If false, skip entirely — no section in body. Footer documents "not configured."

Bash: `gh pr list --author=@me --state=merged --search "merged:>$(date -v-7d +%Y-%m-%d)" --limit 10 --json number,title,url,mergedAt,headRepository`

(Note: `--json repository` is invalid — the correct field name is `headRepository`. Easy to fumble.)

Process:
- Parse JSON
- Sort by mergedAt desc
- Format as bullet list: `- <title> (<repo>) — <url>`

If `gh` errors at runtime (was detected but call failed — auth expired, network): write "⚠️ GitHub auth issue — <one-line cause>" + log to footer. If it returns empty: "No PRs merged in the last 7 days."

### Step 7: Project synthesis — "Today's work from your projects"

This is the load-bearing chief-of-staff section. Don't list projects flatly — read each one and recommend.

For each active project from Step 0's `project-query.sh` output:

1. **Read the project's `CLAUDE.md`** — extract status frontmatter (status, project-type, last-updated). Skip projects with `status: paused` or `status: done` (shouldn't appear, but safety check).
2. **Read the tail of `memory.md`** — Bash: `tail -80 <project>/memory.md` to get the most recent ~3 entries. Parse for:
   - Most recent date entry
   - "Decision:" / "Decided:" patterns → what just got resolved
   - "Next:" / "Open:" / "Pending:" patterns → what's queued
   - "Blocked:" / "Waiting on:" patterns → what's stuck
   - Any "shipped" / "✅" markers from the last 7 days → momentum signals
3. **Cross-reference today's calendar** (from Step 2) — if any of today's calendar events have a topic matching this project's slug or recent memory keywords, flag the project as "today-relevant" (you'll be discussing it).
4. **Cross-reference open commitments** (from Step 5) — if open commitments mention this project, the project owes someone something.

Then **synthesize per project** (don't dump raw memory):

```
### <Project name> 🟢/🟡/🔴
**Status:** <one-line from CLAUDE.md frontmatter or memory.md latest "Status:" line>
**Latest move:** <most recent memory entry summary, ~1 line>
**Today's recommended action:** <opinionated — what should ship next based on Next:/Blocked: signals>
**Today-relevant:** <yes/no — calendar event matches, OR commitment due, OR stale >7 days>
```

Status emoji rules:
- 🟢 — active momentum (memory entry within last 3 days, no blockers)
- 🟡 — slow (no memory entry in 4-14 days, OR has a Blocked: marker)
- 🔴 — stale or critical (no memory in 14+ days, OR Blocked: + today-relevant)

Order projects: 🔴 first (urgency), then 🟡 today-relevant, then 🟢 today-relevant, then 🟡 not today-relevant, then 🟢 not today-relevant.

**Cap:** surface top 5 projects. If there are more, end with "+ N more active projects — see `bash <scripts.project_query>` for the full list."

**Final synthesis line** at the end of this section:

> **From what I'm seeing, the highest-leverage work today is: <pick one, justify in one clause>.**

This is the opinionated chief-of-staff voice. Pick based on: (a) intersection of today-relevant + 🔴/🟡 status, (b) open commitments due, (c) calendar weight (lots of meetings → less heads-down time → recommend a focused micro-task; light calendar → recommend a deep project block).

Per T3: if a project has a thin `memory.md` (fewer than 2 entries), surface that — "Project X has no recent memory entries — consider a `/standup` to refresh context" — instead of inventing recommendations.

If `project-query.sh` returns empty: write "No active projects — your `1-Projects/` folder is clean. Anything new to scaffold? Use `/new-project`."

### Step 8: Optional cross-references via `/find`

For the top 3-5 calendar events from Step 2 with substantive topics (NOT recurring 1:1s, standups, or weekly reviews):
- For each event topic, invoke `/find <topic>` to surface "you have a relevant note on this"
- This produces the optional "Notes & cross-references" section at the bottom of the brief

This step is **optional** — if `/find` is unavailable or returns nothing for all events, omit the section entirely. Don't error.

### Step 9: Compose and write the brief as a self-contained HTML dashboard

Output is a **single self-contained HTML file** styled with the active DESIGN.md tokens (cached in Step 0). Layout follows the `design-dashboard` pattern at `.claude/skills/design-dashboard/SKILL.md` (with `example.html` as the canonical reference), adapted for briefing-specific regions.

**Hard rules for the HTML file:**
- One file, `<!doctype html>` through `</html>`. All CSS in one inline `<style>` block. NO external links (fonts, CSS, images, JS). NO `<script>`. NO `<img src="http...">`. Inline SVG only for any chart. Briefings must open offline from disk.
- CSS custom properties at the `:root` seed from DESIGN.md tokens: `--bg`, `--fg`, `--muted`, `--border`, `--accent`, `--surface`, `--good`, `--warn`, `--bad`. If DESIGN.md is missing or omits a token, fall back to the neutral defaults inlined here — never invent hex values.
- Semantic HTML: `<aside>`, `<header>`, `<main>`, `<section>`, `<nav>`, `<table>`. Every logical region carries `data-od-id="<slug>"` so future parsers can locate sections deterministically.
- Density follows DS mood — airy DSes get more padding, dense DSes tighten rows. Match the design-dashboard skill's self-check criteria.
- Accent used at most twice — sidebar active state + one hero-stat highlight. Don't accent every status pill.
- Status indicators 🟢🟡🔴 stay as Unicode emoji inside `<span class="pill">` (per USER.md formatting prefs — OK in briefings).

**DOM scaffold (mandatory structure — section order fixed):**

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Morning brief — <YYYY-MM-DD></title>
  <style>
    :root { --bg: ...; --fg: ...; --muted: ...; --border: ...; --accent: ...; --surface: ...; --good: ...; --warn: ...; --bad: ...; }
    /* All seeded from DESIGN.md tokens. See design-dashboard/example.html for the full CSS scaffold —
       same component classes (.sidebar, .nav, .topbar, .kpis, .kpi, .panel, .panels-row, .pill, table). */
  </style>
</head>
<body>
  <aside class="sidebar" data-od-id="sidebar">
    <div class="brand"><assistant.emoji> <assistant.name></div>
    <nav class="nav">
      <a href="#what-needs-you" class="active">Today's priorities</a>
      <a href="#calendar">Calendar</a>
      <a href="#projects">Projects</a>
      <a href="#slack">Slack</a>          <!-- omit anchor if gate false -->
      <a href="#jira">Jira</a>            <!-- omit anchor if gate false -->
      <a href="#commitments">Commitments</a>
      <a href="#shipped">Recent shipped</a> <!-- omit anchor if gate false -->
      <a href="#notes">Notes</a>          <!-- omit anchor if Step 8 empty -->
      <span class="group-label">Brief</span>
      <a href="#tools-used">Tools used</a>
    </nav>
  </aside>
  <main>
    <header class="topbar" data-od-id="topbar">
      <div>
        <h1>Morning brief · <YYYY-MM-DD></h1>
        <p class="tagline">Generated <HH:MM> by <assistant.name>. <One-line tagline derived from the day's signal — e.g., "Three meetings, two open Jira tickets, and Omar's waiting on you."></p>
      </div>
      <div class="right"><span class="pill"><day-of-week, e.g., Tuesday></span></div>
    </header>

    <section class="kpis" data-od-id="kpis">
      <!-- 3-4 KPI cards. Dynamic — pick from: urgent count, meetings today, unread @-mentions,
           past-due tickets, blocked projects, recent shipped count. Use only KPIs the detection
           map enables; never pad with fake stats (T3). At least 2, at most 4. -->
      <div class="kpi"><div class="label">Urgent today</div><div class="value">3</div><div class="delta"><X high-priority items></div></div>
      <div class="kpi"><div class="label">Meetings</div><div class="value">7</div><div class="delta"><first start, last end></div></div>
      <!-- ... -->
    </section>

    <section class="panel" id="what-needs-you" data-od-id="what-needs-you">
      <h3>What needs you today</h3>
      <!-- Step's 1+2+3+4 cross-section: top 5-7 items, urgent emails + next 3 cal events + past-due Jira + Slack mentions. Use <ul> with status pills. -->
    </section>

    <section class="panel" id="calendar" data-od-id="calendar">
      <!-- Gated on detection.cli.gws — OMIT this <section> entirely if false. -->
      <h3>Calendar at a glance</h3>
      <table><thead><tr><th>Time</th><th>Event</th><th>Status</th></tr></thead><tbody>...</tbody></table>
    </section>

    <section class="panel" id="projects" data-od-id="projects">
      <h3>Today's work from your projects</h3>
      <div class="projects-grid">
        <!-- One <article class="project"> per project from Step 7. Status emoji as <span class="pill"> in the card header. -->
        <article class="project">
          <header><h4><Project name></h4> <span class="pill <good|warn|bad>">🟢/🟡/🔴</span></header>
          <p class="status"><Status one-liner></p>
          <p class="latest"><strong>Latest move:</strong> ...</p>
          <p class="action"><strong>Today's recommended action:</strong> ...</p>
        </article>
      </div>
      <p class="synthesis"><strong>From what I'm seeing, the highest-leverage work today is: ...</strong></p>
    </section>

    <section class="panel" id="slack" data-od-id="slack">
      <!-- Gated on detection.mcp.slack — OMIT this <section> entirely if false. -->
      <h3>Slack digest</h3>
      <!-- @-mentions / active channels / threads owing reply, structured as <h4> + <ul>. -->
    </section>

    <section class="panel" id="jira" data-od-id="jira">
      <!-- Gated on detection.mcp.atlassian — OMIT entirely if false. -->
      <h3>Jira queue</h3>
      <table>...</table>
    </section>

    <section class="panel" id="commitments" data-od-id="commitments">
      <h3>Open commitments by person</h3>
      <!-- Per T2: status: personal contacts already filtered upstream in Step 5. WikiLinks render as plain <a href="../contacts/<slug>.md"><slug></a>. -->
    </section>

    <section class="panel" id="shipped" data-od-id="shipped">
      <!-- Gated on detection.cli.gh — OMIT entirely if false. -->
      <h3>Recent shipped</h3>
      <ul>...</ul>
    </section>

    <section class="panel" id="notes" data-od-id="notes">
      <!-- Omit if Step 8 returned nothing useful. -->
      <h3>Notes &amp; cross-references</h3>
      <ul>...</ul>
    </section>

    <section class="panel footer" id="tools-used" data-od-id="tools-used">
      <h3>Tools used</h3>
      <p class="muted">Composed from Step 0.5's detection map. Transparency footer per T4 — never fabricated.</p>
      <ul>
        <li><span class="pill good">✅ Composed</span> <comma-separated list></li>
        <li><span class="pill warn">⏳ Not configured</span> <list></li>  <!-- OMIT <li> entirely if all gated tools detected -->
        <li><span class="pill bad">⚠️ Errored at runtime</span> <list></li>  <!-- OMIT <li> entirely if no runtime errors -->
      </ul>
    </section>

    <p class="signoff">That's the lay of the land. Where do you want to start?</p>
  </main>
</body>
</html>
```

**Voice (per SOUL.md) — applies to the human-readable text rendered inside the HTML:**
- Topbar tagline: warm + direct, like "Morning <user.name>! Three meetings, two open Jira tickets, and Omar's waiting on you." (no "Per your request..." / "Please be advised...")
- Use phrases like "Here's what matters...", "Worth noting...", "From what I'm seeing..." in the project-synthesis closing line
- Status indicators 🟢🟡🔴 inside `<span class="pill">` — colored by status, not decoration
- Be opinionated in the projects section's closing synthesis line. "Ship X today because Y." Not "you could consider..."

**Section-omission rules (T4 — preserve order of present sections):**
- Gated section with detection=false → OMIT the entire `<section>` AND remove its `<a href="#...">` from the sidebar nav. No empty headers, no "⚠️ not configured" body content.
- Gated section with detection=true but runtime error → keep the `<section>` and its `<h3>`, render a single `<p class="warn">⚠️ <Tool> errored — <cause></p>` as the body.
- Mandatory-floor sections (what-needs-you, projects, commitments, tools-used) are ALWAYS in the DOM. Tools-used is the last `<section>` before `<p class="signoff">`.

**Pre-Write assertions (catch regressions):**
- Path string ends in `.html` (not `.md`) — reject otherwise (T1).
- Contains `<!doctype html>` opening and `</html>` closing.
- Contains the `<section data-od-id="tools-used">` (T4 mandatory footer).
- Does NOT contain `<script>` or `http://` / `https://` references (self-contained rule).
- Does NOT contain any `status: personal` contact slug in commitments section (T2 sanity grep).

**T1 reminder: write to `<workspace.root>/<workspace.resources>/briefings/morning-briefing-${DATE}.html`** (or `-${DATE}-${TIME}.html` if collision). Confirm the path before Write. The Write tool will fail if the parent directory doesn't exist — `<workspace.root>/<workspace.resources>/briefings/` should already exist (created during workflow-defect cleanup 2026-05-06); if not, `mkdir -p` first.

### Step 10: Surface to user

Don't dump the full brief into chat — that's the file's job. Instead:

```
Morning <user.name>! Brief is ready at `<workspace.root>/<workspace.resources>/briefings/morning-briefing-<DATE>.html` — open in a browser.

Top 3 from "What needs you today":
1. <item>
2. <item>
3. <item>

Highest-leverage work today: <one-line synthesis from Step 7's closing line>.

<Optional line — INCLUDE ONLY IF Step 0.5's detection map had any `false` entries:>
ℹ️ Composed from <N>/5 optional signal sources. <skipped tools list>. See `## Tools used` footer in the brief for setup hints.

That's the lay of the land. Where do you want to start?
```

This gives <user.name> the headline + the project synthesis + a prompt for direction without forcing him to scroll. For full-stack users with everything detected, omit the `ℹ️` line entirely — it's only there when degradation occurred, to flag "you could get more by configuring X."

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Output written to wrong path | T1 violation | Validate path string `<workspace.root>/<workspace.resources>/briefings/morning-briefing-<DATE>.html` BEFORE Write. Add an assertion in Step 9. |
| Output written as `.md` instead of `.html` | Pre-v0.2.0 muscle memory | The skill is HTML-only as of v0.2.0. Markdown output retired. Reject any path string ending in `.md` in Step 9's pre-Write assertion. |
| HTML opens to a blank/unstyled page | DESIGN.md not loaded or token names mismatch in CSS | Step 0 caches DESIGN.md content; Step 9's `<style>` block defines `--bg`/`--fg`/`--accent`/etc. CSS custom properties seeded from those tokens. If DESIGN.md is absent, use neutral fallbacks (do NOT skip the `<style>` block). |
| HTML missing semantic structure (raw `<div>` soup) | Skill wrote freeform HTML instead of using the dashboard scaffold | Use `<aside>`, `<header>`, `<main>`, `<section>` per Step 9. Each region carries a `data-od-id` slug so downstream parsers (future `/weekly-digest`, etc.) can locate sections deterministically. |
| Inline JS or external assets in the HTML | Briefing must be a single self-contained file | NO `<script>` tags, NO external CSS/font links, NO `<img src="http...">` references. Everything inline. Briefings open offline from disk. Inline SVG for any chart. |
| Same-day re-run overwrites existing brief | T1 violation (date-only filename) | Detect existing file in Step 0, append `-HHMM` to filename. |
| Personal contact appears in "Open commitments by person" | T2 violation (filter not applied or applied at display time) | Filter `status: personal` at READ time in Step 5. Confirm via grep: output should not contain `[[contacts/faizan]]` or any other `status: personal` slug. |
| Fake Jira ticket in output | T3 violation (MCP returned empty, skill invented content) | If `searchJiraIssuesUsingJql` returns `[]`, write "No active Jira tickets." NOT a fake row. |
| Fake Slack message | T3 violation | Same pattern. Empty MCP response → empty or skip. |
| Fake project recommendation | T3 violation in Step 7 | If a project's `memory.md` has fewer than 2 entries, surface "thin memory — consider /standup" instead of inventing a Next: action. |
| Slack section in brief but Slack MCP not configured | T4 violation (gate broken or skipped) | Step 3 MUST gate on `detection.mcp.slack`. If a section appears with no MCP backing it, the content is fabricated. Re-run Step 0.5; the gate is the contract. |
| Body has "⚠️ Slack not configured" line | T4 violation (footer-only state leaked into body) | The body NEVER says "not configured" — that's footer-only. Body's ⚠️ lines are exclusively for *detected-but-errored* tools. Not-configured tools omit silently. |
| `<section data-od-id="tools-used">` footer missing | Step 9 skipped the footer block | The footer is MANDATORY in every brief — single source of truth for what was composed. Even for full-stack users with all green checks, the footer lists "✅ Composed: everything." Pre-Write assertion in Step 9 should reject any HTML lacking `data-od-id="tools-used"`. |
| Footer fabricates tool status (says "✅ Composed: Slack" when Slack wasn't detected) | T4 violation | The footer is built from the `detection` map cached in Step 0.5, not from the body content. Wire it directly from the map. |
| Step 1-6 ran even though tool not in detection map | T4 violation (gate ignored) | Each of Steps 1, 2, 3, 4, 6 has an explicit `Gate (T4):` line. Don't run the step's body when the gate is false. |
| Slack channels missed | Static channel list assumption | Step 3 uses DYNAMIC enumeration via `slack_search_channels`, not a hardcoded list. No maintenance required as channel membership changes. |
| Project section flat (no opinion) | Skill defaulted to listing instead of synthesizing | Step 7 final synthesis line is mandatory: "From what I'm seeing, the highest-leverage work today is X because Y." Don't ship without it. |
| Calendar conflict missed | Overlap detection failed | Sort events by start, scan for `event[i].end > event[i+1].start` — flag both with 🔴. |
| Section order is wrong | Skill writer ad-libbed | Order is FIXED: What needs today → Calendar → Today's work from projects → Slack → Jira → Commitments → Recent shipped → Notes → Tools used. Don't reorder per "what felt right today" — predictability matters. Absent gated sections collapse out cleanly; order of present sections is preserved. |
| Generated artifact ends up in 0-Inbox or 1-Projects | Skill confused output convention | Briefing is an OUTPUT (lives at `<workspace.resources>/briefings/`), not an INBOX item, not a PROJECT. The output convention is hardcoded to `<workspace.root>/<workspace.resources>/briefings/` — see Step 9 validation. |
| Briefing leaks into Slack/email | Skill auto-sent | Briefing NEVER auto-sends (boundary rule). It writes a local file. <user.name> sends manually if at all. |
| Exa called from main context | Token-isolation violation per decision #23 | Briefing does not invoke `web_search_advanced_exa` directly. For external-topic enrichment, suggest `/find` or `/contact-research`. |

## Boundaries

- **Never auto-send.** Briefing is a draft that <user.name> reads. Sending to Slack/email/Jira requires explicit "send it" from <user.name> (per CLAUDE.md "Boundaries"). Drafts only.
- **Never modify project files.** This skill READS `<workspace.projects>/*/CLAUDE.md` and `<workspace.projects>/*/memory.md` (via project-query.sh and tail) and `<workspace.resources>/contacts/*.md`. It does NOT write to either.
- **Never auto-commit.** The briefing file is uncommitted by default; <user.name> commits it (or not — `<workspace.root>/<workspace.resources>/briefings/` may be `<user.name>`-curated).
- **Never call Exa directly** (decision #23 token-isolation). If a topic needs external research, suggest `/find` or `/contact-research`.
- **Never fabricate.** T3 invariant. Empty MCP → empty section or short note. Thin project memory → surface that fact, don't invent recommendations.
- **Never mix personal-life content into work brief.** T2 invariant. `status: personal` contacts filtered at read time.
- **Never assume a tool is present.** T4 invariant. Step 0.5 detects availability; Steps 1-6 gate on it. Absent tools omit silently from body, footer documents. Never invent a tool call to fill a section; never write a "⚠️ X not configured" line into the body.

## Output format reference

The brief is a single self-contained HTML file with a stable DOM order so downstream tooling (eventually `/standup`, `/weekly-digest`) can parse it deterministically via `data-od-id` slugs. Section order is FIXED:

1. `<title>` — `Morning brief — <YYYY-MM-DD>`
2. `<aside data-od-id="sidebar">` — nav anchors mirror the present sections
3. `<header data-od-id="topbar">` — H1 + tagline + day-of-week pill
4. `<section data-od-id="kpis">` — 2-4 KPI cards (dynamic; from detection map + signal volume)
5. `<section data-od-id="what-needs-you">` — always present (mandatory floor — top 5-7 items merged from calendar / Gmail / Jira / Slack per priority signals)
6. `<section data-od-id="calendar">` — gated on `detection.cli.gws`
7. `<section data-od-id="projects">` — always present (mandatory floor — load-bearing chief-of-staff section with project-card grid + closing synthesis line)
8. `<section data-od-id="slack">` — gated on `detection.mcp.slack`
9. `<section data-od-id="jira">` — gated on `detection.mcp.atlassian`
10. `<section data-od-id="commitments">` — always present (file reads, no external dep); omitted if contacts dir is empty
11. `<section data-od-id="shipped">` — gated on `detection.cli.gh`
12. `<section data-od-id="notes">` — always tried; omitted if `/find` returned nothing useful
13. `<section data-od-id="tools-used">` — ALWAYS present, transparency footer per T4
14. `<p class="signoff">That's the lay of the land. Where do you want to start?</p>`

**Section behaviors:**
- Gated sections (6, 8, 9, 11) collapse out entirely if `detection.<key>` is false — no `<section>`, no sidebar nav anchor, no body. The `tools-used` footer documents the omission.
- Gated sections that DID get detection but errored at runtime: keep the `<section>` and its `<h3>`, render a single `<p class="warn">⚠️ <Tool> errored — <cause></p>` as the body, also log to footer.
- Mandatory-floor sections (5, 7, 10) always appear unless they have genuinely no content (e.g., empty contacts dir → omit section 10).
- The footer (13) is the source of truth: if a `<section>` is present in the DOM, the footer should list it under ✅ Composed; if absent, it goes under ⏳ Not configured or ⚠️ Errored.

**Why HTML, not Markdown (v0.2.0 decision):**
- `<user.name>` wanted a styled, scannable artifact he could open in a browser and (eventually) `/samba-publish` for share. Dashboard mood beats prose for daily orientation.
- Parsing tradeoff: downstream skills that previously grepped `## What needs you today` now query by `data-od-id="what-needs-you"` instead. DOM slugs are stable across cosmetic CSS changes; H2 text could drift with voice tweaks.
- Self-contained constraint (no JS, no external assets) keeps briefings portable: opens offline, archivable, no link rot.
