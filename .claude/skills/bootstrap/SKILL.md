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
- `mcp.<name>.connected`: **CANNOT probe from Bash** — OAuth state is per-Claude-Code-session, not exposed. Mark as `⏳ — run /mcp to verify` for any HTTP MCP.

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
- ✅ **`gws-*` / `recipe-*`** (<count> skills) — Google Workspace skills.
- ✅ **`persona-*`** (<count> skills) — Role-modeled workflows.
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

### Phase 10: Surface "you're set up"

Construct the closing message from `detection_report` + Phase 8 values. Use the `<assistant.name>` voice (per SOUL.md):

```
<assistant.emoji> <assistant.name> is configured.

What you can do now:
- /briefing → morning brief composing Gmail+Calendar+Slack+Jira+contacts+projects
- /find <topic> → recall existing knowledge across your second brain
- /new-project → scaffold a new project (or code repo)
- /contact <name> → look up someone in your contacts/
- /help → full skill list

What needs your attention right now:
[Surface from detection_report — e.g.:]
- ⏳ Slack MCP configured but not OAuth'd — run /mcp now
- ⏳ Atlassian MCP configured but not OAuth'd — run /mcp
- ❌ yt-dlp not installed — `brew install yt-dlp` if you want YouTube transcript extraction
- ⚠️ Salesforce CLI auth broken — `sf org login web -a <alias>` if you use SF in daily flow
[Or "All tools authed and ready ✅" if no issues.]

Manual follow-up before /briefing works fully:
- Edit USER.md to fill in your team / collaborators / priority signals (Phase 5 left these as <TBD> scaffolds)
- Add a `## Priority Slack Channels` section to USER.md if you want pinned channels in /briefing's Slack digest
- Drop your meeting Drive folder IDs into TOOLS.md "Google Drive" section if applicable

Active design system: <brand title> (set via /use-design <brand> if you want to swap)

Review the diff and commit when you're ready. /bootstrap does not auto-commit (T3).

To re-run: delete the `setup_completed: <date>` line in CLAUDE.md, then invoke /bootstrap.

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
