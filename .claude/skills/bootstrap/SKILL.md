---
name: bootstrap
description: Interactive first-run setup for a fresh fork of the second-brain-harness repo. **The most important skill in the harness — the entry point** — every fork user runs this once, and what they build off depends entirely on this configuring correctly. Walks through 10 phases — (1) detect environment via read-only probes (gws/gh/databricks/sf/yt-dlp/ffmpeg/jq/rg + `.mcp.json` MCPs + Claude Code plugins), (2) identity (full name + short name + email + timezone + email signature + GitHub username + company), (3) persona (keep <agent> default OR customize name/role/vibe/emoji), (4) design system (pick from 73 brands in `<workspace.root>/<workspace.resources>/design-systems/` organized by category, OR keep neutral default, OR keep magenta REPLACE-ME placeholder), (5) persona file regeneration from templates at `<workspace.root>/<workspace.resources>/templates/persona/` with concrete git-diff-vs-upstream detection to preserve user-edited files, (6) workspace skeleton creation (`0-Inbox`, `1-Projects`, `2-Coding/{work,personal,forks,archive}`, `3-Resources/{templates,research,reference,meetings,contacts,design-systems}`, `4-Archive`), (7) **dynamic TOOLS.md generation from Phase 1 detection** with ✅/⏳/❌ flags + version strings + configured-MCP listing, (8) Configuration section write in root `CLAUDE.md` with all 11+ tokens (`user.name`, `user.full_name`, `user.email`, `user.timezone`, `user.github`, `user.email_signature`, `user.company`, `assistant.name`, `assistant.role`, `assistant.vibe`, `assistant.emoji`, `setup_completed: <YYYY-MM-DD>`), (9) smoke test invoking `/new-project` with a throwaway to verify placeholder substitution end-to-end, (10) surface "you're set up" message. Use this whenever someone runs the repo for the first time after cloning, or wants to reconfigure their identity / persona / workspace name — phrases like "/bootstrap", "set up <agent>", "I just cloned this", "first-time setup", "fresh install", "bootstrap me", "let's configure this", "set up the workspace", "configure the assistant", "I want to customize the persona", "set up everything from scratch". Trigger broadly on first-run intent. Detects re-runs by inspecting whether `setup_completed: <date>` exists in the Configuration section — if present, refuses gracefully and instructs the user to delete that line and re-run `/bootstrap`. Output is a personalized workspace ready for daily use; the smoke-test artifact is deleted after verification. Tiger invariants stated 4-5x throughout: T1 = NEVER overwrite user-edited persona files without explicit confirmation (uses `git show HEAD:FILE` diff to detect divergence); T2 = NEVER re-run on already-configured fork without explicit user action (delete `setup_completed:` line); T3 = NEVER auto-commit (user reviews diff and commits manually); T4 = NEVER install tools (read-only probes only — surface hints to installers like `samba-onboarding` or `brew install`).
context: fork
---

# bootstrap

The first-run setup skill. Configures identity, persona, design system, workspace, generates TOOLS.md from live probes, writes the Configuration section, smoke-tests end-to-end. ~10–15 minutes for a thorough first run.

**Why this is the most important skill:** every fork user runs this exactly once, and the entire harness is built on top of what `/bootstrap` writes. A broken `/bootstrap` ships a broken second brain to every fork. Treat every step with care — this skill protects against the most expensive failure mode (a new user clones, runs setup, ends up with a half-configured workspace and gives up).

## Tiger invariants (LOAD-BEARING — DO NOT VIOLATE)

Stated multiple times throughout this skill (description, here, in step headers, in failure modes table) by design.

### T1 — NEVER overwrite user-edited persona files without explicit confirmation

If a root persona file (`SOUL.md`, `USER.md`, `IDENTITY.md`, `CLAUDE.md`, `README.md`, `TOOLS.md`) has been edited beyond what the persona template would produce, Phase 5 MUST detect this via `git show HEAD:<file>` comparison (or against the persona template) and ask before overwriting. Default behavior: skip. Only overwrite when user explicitly confirms.

### T2 — NEVER re-run on already-configured fork without explicit user action

Phase 1 detects re-run via `grep -E "^- \`setup_completed\` = " CLAUDE.md`. If found, refuses and prints: *"This fork is already configured (setup_completed: <date>). To re-run /bootstrap, delete the `setup_completed` line in CLAUDE.md and invoke /bootstrap again."* Do NOT proceed past Phase 1.

### T3 — NEVER auto-commit

After all writes complete, surface the diff (or path list) and tell the user to commit manually. NEVER invoke `git add` or `git commit`.

### T4 — NEVER install tools

Phase 1 is READ-ONLY probes. If a tool is missing/unauthed, surface a hint pointing at the appropriate installer:
- For Samba employees: `samba-onboarding` (the company-internal tool-layer installer)
- For external users: `brew install <tool>` + the tool's own auth flow (e.g., `gh auth login`, `gws auth login -s <scopes>`)
- For MCPs: `/mcp` command to authorize via OAuth

## Process

### Phase 1: Detect environment (read-only probes — T4 invariant)

Run all probes in parallel via Bash. Capture stdout, stderr, exit codes. Build a `detection_report` object in memory for use in Phases 7 (TOOLS.md generation) and 10 (surface message).

**Setup state probe** (T2 invariant):
```bash
grep -E "^- \`setup_completed\` = " CLAUDE.md
```
- If matches: T2 refuse with message above. STOP.
- If no match: continue.

**CLI probes:**
```bash
gws auth status 2>&1 | head -20             # GWS state + scopes
gh auth status 2>&1 | head -10              # GitHub
databricks --version 2>&1                   # Databricks CLI
sf --version 2>&1 | head -1                 # Salesforce CLI version
sf org list --json 2>&1 | head -20          # SF org auth state
which yt-dlp 2>&1                           # yt-dlp
which ffmpeg 2>&1                           # ffmpeg
which jq 2>&1                               # jq
command -v rg 2>&1                          # ripgrep (note: may be a Claude Code shell function — `command -v` shows it)
which node 2>&1; node --version 2>&1        # Node (for local MCPs)
```

For each, parse:
- `cli.gws.installed`: bool (path exists)
- `cli.gws.authed`: bool (`gws auth status` exit 0)
- `cli.gws.scopes`: list (parse "Granted scopes" from output)
- `cli.gh.authed`: bool + username
- ... etc.

**MCP probes:**
```bash
jq '.mcpServers | keys[]' .mcp.json 2>&1     # list configured MCPs
ls ~/.claude/plugins/installed_plugins.json 2>&1  # installed plugins
```

For each entry in `.mcp.json.mcpServers`, capture:
- `mcp.<name>.url` (or `command` for stdio)
- `mcp.<name>.type` (http/stdio)
- `mcp.<name>.notes` (from `_notes` block if any)
- `mcp.<name>.connected`: **DO an actual in-session probe — don't assume ⏳ for everything.** Bootstrap runs inside a Claude Code session, so you can see which MCPs are loaded. Use this procedure:
  1. **Check the session's deferred-tools list** (visible in the system prompt at session start) for any tools named `mcp__<name>__*`. If ≥1 such tool exists → the MCP server is loaded and connected for this workspace → mark `✅ connected`.
  2. **If no `mcp__<name>__*` tools exist** → the MCP is configured in `.mcp.json` but not authorized in this workspace (per-project OAuth state). Mark `⏳ configured — run /mcp to authorize for this workspace`. NEVER write "unauthorized" as if it's a global state — Claude Code isolates auth per project root, so this fork may simply need its own `/mcp` flow even if the user has the same MCP authorized elsewhere.
  3. **For stdio MCPs** (e.g., `gemini-vision`): also verify the required env vars are present. For gemini-vision, run `[[ -n "${GEMINI_API_KEY:-}" ]]` via Bash. If unset → mark `⚠️ stdio MCP needs $GEMINI_API_KEY in shell env`. If set + tools present → `✅ connected`.
  4. **Honesty rule:** if you genuinely can't determine connection state for a given MCP (e.g., the deferred-tools list isn't accessible), say `ℹ️ configured — status unverified; run /mcp to check` rather than fabricating ⏳ or ✅.

**Pipeline tools probe:**
```bash
which jq rg ffmpeg yt-dlp 2>&1
```

**Workspace state probe:**
```bash
ls -d workspace 2>&1                    # default workspace folder name
test -d workspace/0-Inbox && echo OK    # canonical subdirs
test -d workspace/1-Projects && echo OK
test -d workspace/2-Coding/work && echo OK
test -d workspace/2-Coding/personal && echo OK
test -d workspace/2-Coding/forks && echo OK
test -d workspace/2-Coding/archive && echo OK
test -d workspace/3-Resources && echo OK
test -d workspace/4-Archive && echo OK
```

**Persona files state probe:**
```bash
git ls-files SOUL.md USER.md IDENTITY.md CLAUDE.md README.md TOOLS.md
git diff --quiet HEAD -- SOUL.md && echo CLEAN || echo MODIFIED
# repeat for each file — informs Phase 5's T1 logic
```

**Output of Phase 1**: `detection_report` (in skill memory) — used by Phase 7 to write TOOLS.md, by Phase 5 to know which files are user-edited, by Phase 10 to surface "what needs auth" hints.

### Phase 2: Identity (AskUserQuestion-driven)

Collect via `AskUserQuestion`. Default values where detectable:

| Field | Prompt | Default source |
|-------|--------|----------------|
| `user.full_name` | "Your full display name?" | none — must input |
| `user.name` | "What should I call you (short name)?" | first word of full_name |
| `user.email` | "Email address?" | `git config user.email` if set |
| `user.timezone` | "Timezone?" | `date +%Z` (e.g., `America/New_York`) |
| `user.email_signature` | "Email signature line?" | `<full_name>` as a starter |
| `user.github` | "GitHub username?" | `gh api user --jq .login 2>/dev/null` if `gh` authed |
| `user.company` | "Company / org?" (optional) | from email domain if it looks like a company domain |
| `workspace.root` | "Workspace folder name? [default: workspace]" | default `workspace` |

Validate inputs lightly (no spaces in github username; email contains `@`). Re-prompt on obvious typos.

### Phase 3: Persona — keep default OR customize

`AskUserQuestion`:
- **(a) Keep <agent> default** — chief-of-staff persona, "🎯", professional-but-warm voice. Skill skips Phase 5 for SOUL/IDENTITY/USER (preserves <agent> content), only updates Configuration section in CLAUDE.md with identity values.
- **(b) Customize a new persona** — collect:
  - `assistant.name` (e.g., "Atlas", "Echo", "Pierre")
  - `assistant.role` (e.g., "Research Companion", "Engineering Co-Pilot")
  - `assistant.vibe` (one-line — e.g., "Quiet and analytical, like a librarian who knows where every book is")
  - `assistant.emoji` (single emoji)

If (a): record `assistant.name=<agent>`, `assistant.role=Chief of Staff`, `assistant.vibe="Professional but warm — like a trusted exec assistant…"`, `assistant.emoji=🎯`.

### Phase 4: Design system picker

Read the design-systems library and present categorized brands:

```bash
ls workspace/3-Resources/design-systems/ | grep -v '^README'
# 73 brands — group by category from the README parsing
```

Categories from `design-systems/README.md`:
- AI & LLM (12 brands): claude, cohere, elevenlabs, minimax, mistral-ai, ollama, opencode-ai, replicate, runwayml, together-ai, voltagent, x-ai
- Developer Tools (7): cursor, expo, lovable, raycast, superhuman, vercel, warp
- Productivity & SaaS (7): cal, intercom, linear-app, mintlify, notion, resend, zapier
- Backend & Data (8): clickhouse, composio, hashicorp, mongodb, posthog, sanity, sentry, supabase
- Design & Creative (6): airtable, clay, figma, framer, miro, webflow
- Fintech & Crypto (7): binance, coinbase, kraken, mastercard, revolut, stripe, wise
- E-Commerce & Retail (5): airbnb, meta, nike, shopify, starbucks
- Media & Consumer (11): apple, ibm, nvidia, pinterest, playstation, spacex, spotify, theverge, uber, vodafone, wired
- Automotive (6): bmw, bugatti, ferrari, lamborghini, renault, tesla
- Starter (1): default — Neutral Modern
- Hand-authored (1): warm-editorial — Warm Editorial

`AskUserQuestion`: pick a category first (10 options), then within that category, list brands with their one-line summary (read first 3 lines of each `DESIGN.md` for the title + category + tagline).

Three meta options always available:
- **(default)** — `default` brand (Neutral Modern starter — safe pick if user is unsure)
- **(keep current)** — leave the existing root `DESIGN.md` as-is (useful if user already swapped manually)
- **(magenta placeholder)** — leave the bright `#ff00aa` REPLACE-ME draft (useful if user wants to develop their own brand from scratch)

After pick, run the `/use-design <brand>` slash command equivalent:
```bash
test -f DESIGN.md && cp DESIGN.md .DESIGN.md.previous
cp "workspace/3-Resources/design-systems/<brand>/DESIGN.md" DESIGN.md
```

Surface: "Active design system: <brand title>. Backup at .DESIGN.md.previous if you want to undo."

### Phase 5: Persona file regeneration (T1 invariant)

For each persona template at `workspace/3-Resources/templates/persona/<file>-template.md`:

1. Read the corresponding root file (e.g., `SOUL-template.md` ↔ `SOUL.md`).
2. **T1 detection**:
   ```bash
   git show HEAD:<file> 2>/dev/null > /tmp/upstream_<file>
   diff -q /tmp/upstream_<file> <file>   # exit 0 = clean (matches upstream); exit 1 = modified
   ```
   - If clean (matches upstream): safe to overwrite.
   - If modified: **AskUserQuestion** with options `skip` / `overwrite` / `show-diff` / `merge-manually`. Default: `skip`.
3. If overwriting:
   - Read the template
   - Substitute all 11+ placeholder tokens with the values collected in Phase 2 + 3 (use `sed` for atomic substitution, e.g., `sed -e "s/<user.name>/${USER_NAME}/g" -e "s/<user.full_name>/${USER_FULL_NAME}/g" ...`)
   - Write to root path
4. If skipping: log "preserved your existing <file>" and continue.

Files in scope (in this order):
- `SOUL-template.md` → `SOUL.md` (only if Phase 3 = customize; else skip — keep <agent>'s voice)
- `IDENTITY-template.md` → `IDENTITY.md` (only if Phase 3 = customize)
- `USER-template.md` → `USER.md` (always — even keeping <agent>, swap `<user.name>`'s specifics for new user's)
- `CLAUDE-template.md` → `CLAUDE.md` — DEFER to Phase 8 (Configuration write); CLAUDE.md is mostly tokenized via the Configuration section, no need to regenerate the whole file
- `README-template.md` → `README.md` (only if Phase 3 = customize OR workspace.root renamed)

NOTE: TOOLS.md is NOT regenerated from template here — Phase 7 builds it dynamically from Phase 1 detection (a far better signal than a static template).

### Phase 6: Workspace skeleton (idempotent — T1 + T4)

Check if `<workspace.root>/` exists. If `<workspace.root>` was renamed in Phase 2, `mv` the folder.

Create missing canonical subdirs:
```bash
mkdir -p <workspace.root>/{0-Inbox,1-Projects,2-Coding/{work,personal,forks,archive},3-Resources/{templates,research,reference,meetings,contacts,design-systems},4-Archive}
```

NEVER `rm -rf` anything. NEVER overwrite existing subfolder contents. `mkdir -p` is idempotent and safe.

If the user renamed `workspace.root` from default `workspace`: also update CLAUDE.md's Configuration section's `workspace.root` value (deferred to Phase 8 for atomicity).

### Phase 7: Build TOOLS.md from Phase 1 detection

This is the second-most-load-bearing phase after Phase 8 — every session reads TOOLS.md, so accuracy matters. Build it from `detection_report` collected in Phase 1.

Structure (skeleton, fill with detected state):

```markdown
# TOOLS.md — Tool Index

**Auto-loaded at every session start.** Slim by design — one line per tool.

## Connected MCPs (this repo's `.mcp.json`)

[For each MCP in detection_report.mcps:]
- ✅/⏳ **<name>** (<type — http or stdio>) — <url-or-command>. <notes from _notes block, if any>. <"Run /mcp to authorize" hint if HTTP and not yet OAuth'd>

## CLIs

[For each CLI in detection_report.clis:]
- ✅/⚠️/❌ **`<name>`** — <version if installed> | <auth state if applicable> | <one-line description>

[Examples — actual content depends on detection:]
- ✅ **`gws`** (Google Workspace CLI) — verified via `gws auth status`: <N> APIs enabled. Granted scopes: <comma-list>. Backs `gws-*` and `recipe-*` skills.
- ✅ **`gh`** (GitHub CLI) — verified via `gh auth status`: logged in as `<username>`, scopes: <list>.
- ⚠️ **`databricks`** — installed (`<version>`); auth state: <profiles list or "not configured">.
- ⚠️ **`sf`** (Salesforce CLI) — installed (`<version>`); <auth state — likely "Auth broken — re-run `sf org login web -a <alias>`" if AuthDecryptError detected>.
- ❌ **`yt-dlp`** — NOT installed. Install: `brew install yt-dlp`. Required by `transcript-extract.sh`.

## Pipeline tools

[For each in detection_report.pipeline:]
- ✅/❌ `<name>` — <version or "NOT installed; install via X">

## Native skill bundles (in `.claude/skills/`)

[Read .claude/skills/ — categorize by prefix:]
- ✅ **`design-*`** (<count> skills) — HTML/visual artifact skills.
- ✅ **`gws-*`** (<count> skills) — Google Workspace CLI wrappers (Gmail, Calendar, Drive, Docs, Sheets, Slides, Meet). Require `gws` CLI on PATH — install via `brew install googleworkspace-cli` if not present.
- ✅ **<assistant.name>-internal** — list of internal skills (archive-project, briefing, etc.)

## Standard Claude Code tools (always available)

`Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `Skill`, `Agent`, `Task` family, `AskUserQuestion`, `CronCreate`/`List`/`Delete`, `WebFetch`, `WebSearch`, `Monitor`, `NotebookEdit`, `RemoteTrigger`, `PushNotification`.

## Google Drive (project-critical IDs)

[Leave as <TBD> for the user to fill — /bootstrap doesn't know which Drive folders matter to them. Surface in Phase 10 surface message.]

- **Meeting Transcripts:** `<TBD — fill with your folder ID>`
- **Meeting Recordings:** `<TBD — prefer Gemini AI summaries when available>`

## Platform formatting

- **WhatsApp:** No markdown tables, no headers (`#`). Use `*bold*` and bullet lists.
- **Discord:** Wrap multiple links in `<>` to suppress embeds.
- **Slack:** plain markdown works in messages; canvases support richer formatting. Avoid `#` headers in regular messages — use `*bold*` for emphasis.

## When tools change

1. Update this file — flip status flags.
2. Re-run `/bootstrap --reconfigure` to regenerate this file from current detection state, OR edit manually.

## NOT connected (intentional or gated)

[Leave as <TBD> — user fills as they explicitly choose to skip tools.]
```

**T1 reminder:** if root `TOOLS.md` has user edits beyond the upstream/template (detected via `git diff` in Phase 1), `AskUserQuestion` before overwriting. Default: skip. Show the user the new TOOLS.md content as a side file (`TOOLS.md.bootstrap-suggested`) instead of overwriting.

### Phase 8: Configuration write + log

Edit root `CLAUDE.md` Configuration section atomically. Use `Edit` tool with anchor matches to update each value.

Required edits:
- `user.name` line → set to Phase 2 value
- `user.full_name` line → Phase 2
- `user.email` line → Phase 2
- `user.timezone` line → Phase 2
- `user.github` line → Phase 2
- `user.email_signature` line → Phase 2
- `user.company` line → Phase 2
- `assistant.name` line → Phase 3
- `assistant.role` line → Phase 3
- `assistant.vibe` line → Phase 3
- `assistant.emoji` line → Phase 3
- `workspace.root` line → Phase 2 (if renamed)
- **NEW**: append `setup_completed: <YYYY-MM-DD>` line to `### lifecycle` section. This is the T2 re-run gate.

After editing CLAUDE.md, append to `memory/<YYYY-MM-DD>.md`:

```markdown
## <YYYY-MM-DD HH:MM> — /bootstrap run (initial fork OR --reconfigure)

Configured fork:
- user.name: <value>
- user.full_name: <value>
- user.github: <value>
- assistant.name: <value> (default: <agent> / customized)
- workspace.root: <value>
- design-system: <brand name>
- Persona files regenerated: <list, or "kept <agent> default">
- Tool probes summary: <X CLIs ready, Y missing, Z MCPs configured>

Smoke test: <PASSED — placeholder substitution verified / FAILED — see <path>>
```

### Phase 9: Smoke test

NOTE: this runs AFTER Phase 8 (Configuration write) so `/new-project` reads the user's actual values, not placeholders.

Invoke `/new-project` via the Skill tool with:
- name: `bootstrap-smoke-test-<HHMMSS>` (timestamp suffix prevents collisions)
- type: `design` (lightest scaffold — no GitHub repo, no extra branches)
- skip Step 0's "find existing"

After scaffold completes, verify:
1. Folder created at `<workspace.root>/<workspace.projects>/<YYYY-MM>-bootstrap-smoke-test-<HHMMSS>/`
2. `CLAUDE.md` inside the new project contains `<user.name>` value (not the literal `<user.name>` placeholder string)
3. `memory.md` contains today's date entry

If verification PASSES:
- `rm -rf <path-to-smoke-test-project>`
- Surface: "✅ Smoke test passed. Placeholder resolution working end-to-end."

If verification FAILS (e.g., `<user.name>` literal still appears):
- DO NOT delete the smoke-test artifact (leave for debugging — surfaces a real bug to fix)
- Surface: "⚠️ Smoke test FAILED — placeholder resolution didn't work. Inspect: <path>. Configuration section may need manual review."
- DO NOT proceed to Phase 10's "you're set up" message — instead, surface the failure.

### Phase 10: Surface "you're set up" — with real status, not assumptions

Construct the closing message from `detection_report` + Phase 8 values. Use the `<assistant.name>` voice (per SOUL.md). **Critical: every status (✅/⏳/⚠️/❌) must correspond to a real Phase 1 probe result. Don't fabricate ⏳ for MCPs you can see are connected via `mcp__<name>__*` tools in the deferred-tools list.**

The closing message has four sections in this order:

**Section 1 — confirmation + smoke test result.** One line.

**Section 2 — "What needs your attention right now".** Only list items that genuinely need user action. Filter from `detection_report`:
- Skip MCPs marked `✅ connected` — they don't need attention
- Surface only `⏳ configured — needs /mcp authorize`, `⚠️ stdio MCP needs env var`, `❌ tool not installed`, `⚠️ CLI auth broken`, etc.
- If nothing needs attention: say "Everything's authed and ready — no MCP or CLI followups required." and skip to Section 3.
- For per-workspace OAuth items, include the disclaimer line **once** at the top of the section: *"(MCP OAuth is per-project in Claude Code — even if you've authorized these elsewhere, this workspace needs its own grants.)"*

**Section 3 — "Day 1 — start here (in this order)".** Numbered walkthrough. Skip steps that aren't relevant (e.g., skip "authorize MCPs" if Section 2 had nothing in it).

```
Day 1 — start here:

1. Authorize any MCPs flagged above
   Run /mcp → walk through the OAuth flow for any ⏳ entries. Standard browser
   OAuth, no clientId or app registration needed. Skip this step if Section 2
   was empty.

2. Fill in USER.md
   Phase 5 left <TBD> placeholders for your team, priority signals, and Slack
   channels. /briefing reads these — without them the brief still works but
   surfaces less. 5 minutes to do roughly.

3. Try /briefing
   First run will be sparse (empty contacts, empty projects, USER.md half-full)
   — that's expected on a fresh fork. The point of running it is to see the
   shape and confirm your MCPs are returning data. Writes to
   <workspace.root>/<workspace.resources>/briefings/morning-briefing-YYYY-MM-DD.md.

4. Scaffold your first project
   /new-project Q3-strategy (or whatever you're actually working on)
   Creates workspace/1-Projects/YYYY-MM-q3-strategy/ with its own CLAUDE.md +
   memory.md. This is the pattern for every project from here.

5. Add one contact
   Drop a teammate at workspace/3-Resources/contacts/<slug>.md following the
   schema in workspace/3-Resources/contacts/README.md. Then /contact <name>
   should fuzzy-match. Repeat for your inner circle over time.

Day 2+ — natural rhythms:

- /find <topic> when you're not sure if you've already noted something
- /contact-log <name> after every meaningful call or 1:1
- /thinking-partner when you want to explore before solving
- /save-resource to stash a link / doc for later
- /prune-projects every Friday to clean up stale work
- /use-design <brand> to swap the active design system (73 brands shipped)

For everything else, just talk naturally — Claude routes to the right skill via
the description field. /help for the full skill list if you want to browse.
```

**Section 4 — manifest + commit instructions.** Files written, diff/commit pointer, re-run note.

```
Files written or modified:
- SOUL.md, IDENTITY.md, USER.md, README.md — regenerated from persona templates
- TOOLS.md — regenerated from live probes
- CLAUDE.md — Configuration section + project-context prose tokenized
- DESIGN.md — swapped to <brand> (previous backed up to .DESIGN.md.previous)
- workspace/2-Coding/{work,personal,forks,archive}/ — created
- memory/<YYYY-MM-DD>.md — new daily log entry

Active design system: <brand title> — swap with /use-design <brand>

/bootstrap did NOT auto-commit (T3 invariant). Review the diff and commit when
you're ready:

  git status
  git diff
  git add SOUL.md IDENTITY.md USER.md README.md TOOLS.md CLAUDE.md DESIGN.md memory/<YYYY-MM-DD>.md workspace/2-Coding/
  git commit -m "fork bootstrap: configure as <user.name> / <assistant.name> / <brand>"

To re-run /bootstrap later: delete the `setup_completed: <date>` line in
CLAUDE.md, then invoke /bootstrap again.

That's the lay of the land. Where do you want to start?
```

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Skill runs on already-configured fork | T2 detection failed | Phase 1 MUST grep for `setup_completed:` line in CLAUDE.md and refuse if found |
| Persona files overwritten despite user edits | T1 detection mechanism not concrete | Phase 5 uses `git show HEAD:<file>` + `diff -q` — concrete + repeatable |
| Skill auto-committed | T3 violation | NEVER `git add` or `git commit` — explicit invariant |
| Skill tried to install gws/gh/yt-dlp | T4 violation | Phase 1 is READ-ONLY probes. Phase 7/10 surface install hints — never run them |
| Smoke test passed but new project still has placeholder | Phase 9 ran before Phase 8 | Phase order is FIXED: 8 → 9 (Config write before smoke test) |
| TOOLS.md generated but missing tools detected on the system | Phase 1 probe list incomplete | Add to detection list — TOOLS.md is dynamic, regenerable via re-run |
| Workspace skeleton clobbered existing content | Phase 6 was destructive | `mkdir -p` only — never `rm -rf`, never overwrite existing subfolder |
| Configuration section edits clobbered each other | Multiple Edit calls without anchors | Use `Edit` tool with unique line anchors per field; or use a single Write of the whole Configuration block built from current values |
| MCP probe failed and skill aborted | Probes treated as fatal | Probes are informational (`2>&1 \|\| true`). Surface ⚠️ and continue. |
| User skipped Phase 4 design system pick | Skill aborted on missing input | `AskUserQuestion` always offers "(keep current)" / "(default neutral)" / "(magenta placeholder)" as escape hatches |
| User abandoned mid-flow (Ctrl-C between phases) | Partial state | Phase 8's Configuration write is the atomic commit point. If skill exits before Phase 8, no `setup_completed:` line is written, and the next /bootstrap run picks up cleanly. Phases 4-6 are idempotent (re-runnable). Phase 5 file overwrites are the riskiest mid-flow cancel — minimize by ordering Phase 5 AFTER user has approved every persona file individually. |

## Boundaries

- **NEVER auto-commit** (T3). User reviews diff, user commits.
- **NEVER install tools** (T4). Surface hints; don't run them.
- **NEVER overwrite user-edited persona files without explicit confirmation** (T1).
- **NEVER re-run on already-configured fork without setup_completed: line being deleted first** (T2).
- **NEVER alter `2-Coding/` repos.** Independent gits with their own state. `/bootstrap` only creates the empty `{work,personal,forks,archive}/` skeleton folders.
- **NEVER write to `memory/` other than today's daily log.** Append-only by convention.
- **NEVER call Exa.** Bootstrap is local — no web search.

## Re-run mechanism (replaces the imaginary `--reconfigure` flag)

The skill's re-run gate is the `setup_completed: <date>` line in the `### lifecycle` section of CLAUDE.md's Configuration block. Presence = configured (refuse). Absence = fresh fork (proceed).

To re-run `/bootstrap`:
1. Edit root `CLAUDE.md`
2. Delete the `- \`setup_completed\` = \`<date>\`` line
3. Invoke `/bootstrap` again

Phases 1-6 are idempotent (won't double-create folders, won't re-prompt for already-set values if user enters the same answers). Phase 5 protects user edits via T1. Phase 8 overwrites the Configuration section with fresh values. Phase 9's smoke test runs again to verify.
