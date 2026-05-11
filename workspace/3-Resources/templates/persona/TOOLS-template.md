# TOOLS.md — Tool Index

**Auto-loaded at every session start.** Slim by design — one line per tool, with pointers to deeper docs.

For full capabilities, hard limits, auth state, costs, gaps, and the Layer 3 composition map, read **`<workspace.root>/<workspace.resources>/reference/tool-inventory.md`** if you maintain one. That doc is regenerated from CLI probes, so it's the source of truth for verified state.

## Connected MCPs (this repo's `.mcp.json`)

<TBD — list MCPs you've configured. Examples below — replace with your own:>

- ✅ **gemini-vision** (local MCP, `.claude/mcp-servers/gemini-vision.mjs`) — 7 tools: image, OCR, multi-image, compare, filename suggestion, document (PDF/DOCX/TXT), video. Free Gemini tier 15 req/min. Set `GEMINI_API_KEY` in your shell.
- ⏳ **slack** (HTTP MCP) — `https://mcp.slack.com/mcp`. Run `/mcp` to authorize.
- ⏳ **atlassian** (HTTP MCP) — `https://mcp.atlassian.com/v1/mcp`. Standard OAuth.
- ⏳ **figma** (HTTP MCP) — `https://mcp.figma.com/mcp`. Standard OAuth.
- ⏳ **exa** (HTTP MCP) — `https://mcp.exa.ai/mcp?tools=web_search_advanced_exa`. For web search — token-isolation discipline applies (run via Task agent only).

## CLIs

<TBD — list CLIs you use:>

- ✅ **`gws`** (Google Workspace CLI) — for Gmail/Calendar/Drive/Docs/Sheets/Tasks/Slides/Forms via Google APIs. Verify via `gws auth status`. Backs `gws-*` and `recipe-*` skills.
- ✅ **`gh`** (GitHub CLI) — for PR/issue/repo ops. Verify via `gh auth status`.
- <TBD — Databricks, Salesforce, AWS, gcloud, etc. — whatever your tooling layer needs>

## Pipeline tools

- ✅ `jq`, `rg` — JSON parsing + fast grep. Required by several skills.
- <TBD — `ffmpeg`, `yt-dlp`, language toolchains, etc.>

## Native skill bundles (in `.claude/skills/`)

The full inventory of skills is at the top of every session in the available-skills list. Bundle map for orientation:

- ✅ **`design-*`** — HTML/visual artifact skills (decks, dashboards, landing pages, mobile UI, posters, etc.). Auto-trigger from natural language. Brand-token configuration via `DESIGN.md` at workspace root; library at `<workspace.root>/<workspace.resources>/design-systems/`. Swap brand: `/use-design <brand>`.
- ✅ **`gws-*` / `recipe-*`** — Google Workspace skills, from the GWS CLI install.
- ✅ **`persona-*`** — Role-modeled workflows (exec-assistant, sales-ops, content-creator, etc.).
- ✅ **<assistant.name>-internal** — `archive-project`, `new-project`, `prune-projects`, `inbox-process`, `save-resource`, `find`, `thinking-partner`, `contact`, `contact-log`, `briefing`, `bootstrap`, etc.

## Standard Claude Code tools (always available)

`Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `Skill`, `Agent`, `Task` family, `AskUserQuestion`, `CronCreate`/`List`/`Delete`, `WebFetch`, `WebSearch`, `Monitor`, `NotebookEdit`, `RemoteTrigger`, `PushNotification`.

## Google Drive (project-critical IDs)

<TBD — fill in if you use Drive folders for source-of-truth content:>

- **Meeting Transcripts:** `<TBD>` (e.g., Tactiq full transcripts folder ID)
- **Meeting Recordings:** `<TBD>` (e.g., Gemini AI summaries — prefer when available)

## Platform formatting

- **WhatsApp:** No markdown tables, no headers (`#`). Use `*bold*` and bullet lists.
- **Discord:** Wrap multiple links in `<>` to suppress embeds.
- **General:** Keep messages mobile-friendly and concise.
- **Slack:** plain markdown works in messages; canvases support richer formatting. Avoid `#` headers in regular messages — use `*bold*` for emphasis.

## When tools change

1. **Update this file** — flip the entry status, fix the one-liner.
2. **Update `tool-inventory.md`** if you maintain one — deeper verified-state catalog (re-run probes if auth state shifted).
3. If a Layer 3 skill (`/briefing`, `/meeting-prep`, etc.) was gating on the tool, update its composition map too.

## Discipline: every entry needs a probe

Adding an entry to TOOLS.md? The claim should be backed by a **verification probe** (a command output, a test invocation, a Bash check). Trusted-handoff or vibes-based entries lead to drift. Always verify before claiming "ready."

## NOT connected (intentional or gated)

<TBD — list tools you've explicitly chosen NOT to install or that are gated. Helps future-you (or your fork audience) know what was deliberate vs accidentally missing.>
