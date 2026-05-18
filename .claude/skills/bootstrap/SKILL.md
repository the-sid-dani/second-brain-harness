---
name: bootstrap
description: Interactive first-run setup for a fresh fork of the second-brain-os — THE entry point every fork user runs once to configure identity, persona, design system, workspace skeleton, TOOLS.md, and the Configuration token block in root CLAUDE.md. Walks the user through 8 narrated steps with AskUserQuestion gates, read-only environment probes, live tool-detection panel (✅/⏳/⚠️/❌), persona-file regeneration from templates (preserves user edits via git-diff vs upstream), TOOLS.md preview before write, and a smoke test through `/new-project` to verify placeholder substitution. Detects re-runs via `setup_completed:` in Configuration; refuses gracefully. Use after cloning the repo, or when reconfiguring identity / persona / workspace — phrases like "/bootstrap", "I just cloned this", "first-time setup", "configure the assistant". Tiger invariants T1-T4 (never overwrite user-edited persona files, never re-run on configured fork, never auto-commit, never install tools) live in SKILL.md body.
allowed-tools: Read Write Edit Bash AskUserQuestion Skill
---

# bootstrap

The first-run setup skill. Configures identity, persona, design system, workspace, generates TOOLS.md from live probes, writes the Configuration section, smoke-tests end-to-end. **8 narrated steps, ~15 minutes for a thorough first run.**

**Why this is the most important skill:** every fork user runs this exactly once, and the entire harness is built on top of what `/bootstrap` writes. A broken `/bootstrap` ships a broken second brain to every fork.

**Design principle — full transparency.** The user should always know what's happening, what was detected, and what's about to be written. Every Bash probe gets a one-line "about to check X" narration. Every write gets a preview + `AskUserQuestion` gate. Detection results render as a confirmable status panel before any side-effecting step.

## Tiger invariants (LOAD-BEARING — DO NOT VIOLATE)

Stated multiple times throughout this skill (description, here, in step headers, in failure modes table) by design.

### T1 — NEVER overwrite user-edited persona files without explicit confirmation

If a root persona file (`SOUL.md`, `USER.md`, `IDENTITY.md`, `CLAUDE.md`, `README.md`, `TOOLS.md`) has been edited beyond what the persona template would produce, Step 6a MUST detect this via `git show HEAD:<file>` comparison and ask before overwriting. Default behavior: skip. Only overwrite when user explicitly confirms.

### T2 — NEVER re-run on already-configured fork without explicit user action

Step 1 detects re-run via `grep -E "^- \`setup_completed\` = " CLAUDE.md`. If found, refuses and prints: *"This fork is already configured (setup_completed: <date>). To re-run /bootstrap, delete the `setup_completed` line in CLAUDE.md and invoke /bootstrap again, or use `/update-config` for partial edits."* Do NOT proceed past Step 1.

### T3 — NEVER auto-commit

After all writes complete, surface the diff (or path list) and tell the user to commit manually. NEVER invoke `git add` or `git commit`.

### T4 — NEVER install tools

Step 2 is READ-ONLY probes. If a tool is missing/unauthed, surface a hint pointing at the appropriate installer:
- For Samba employees: `samba-onboarding` (the company-internal tool-layer installer)
- For external users: `brew install <tool>` + the tool's own auth flow (e.g., `gh auth login`, `gws auth login -s <scopes>`)
- For MCPs: `/mcp` command to authorize via OAuth

---

## Process — 8 narrated steps

### Step 0: Welcome + plan preview

**Narrate to user (verbatim, in `<assistant.name>` voice):**

> Hey! I'm going to walk you through setting up your second-brain harness. Here's the plan — 8 steps, ~15 minutes, every write gates on your approval:
>
> 1. **Check fork state** — make sure this isn't already configured
> 2. **Probe your environment** — detect CLIs, MCPs, pipeline tools (read-only, nothing gets installed)
> 3. **Collect identity** — your name, email, GitHub, timezone, etc.
> 4. **Pick a persona** — keep the default chief-of-staff, or customize
> 5. **Pick a design brand** — for the `design:*` skills (72 brands shipped)
> 6. **Apply changes** — regenerate persona files, create workspace skeleton, write TOOLS.md (with preview)
> 7. **Write Configuration + smoke test** — fill in CLAUDE.md tokens, verify with a throwaway `/new-project`
> 8. **Summary** — what was written, what needs your follow-up, how to commit
>
> I never auto-commit, never install anything, and never overwrite your edits without asking. Ready?

**AskUserQuestion gate:**

| Question | Options |
|----------|---------|
| "Ready to start?" | (a) **Yes, walk me through** (proceed to Step 1) / (b) **Show me what each step does in more detail** (expand each step) / (c) **Abort** (exit cleanly) |

---

### Step 1: Fork-state check (T2 invariant)

**Narrate:** *"First — checking if this fork is already configured. This is a single grep against CLAUDE.md…"*

```bash
grep -E "^- \`setup_completed\` = " CLAUDE.md
```

**Outcomes:**
- **Match found**: T2 refuse. Print:
  > This fork is already configured — `setup_completed: <date>` is set in CLAUDE.md.
  >
  > To re-run /bootstrap from scratch, delete that line in CLAUDE.md and invoke /bootstrap again.
  >
  > For partial edits (just changing your name, swapping the brand, updating one persona file), use `/update-config` — lighter-weight, doesn't touch persona files or run a smoke test.

  STOP. Do NOT proceed.

- **No match**: Print *"Fresh fork detected — proceeding to environment probe."* Continue to Step 2.

---

### Step 2: Environment detection (T4 invariant — read-only)

**Narrate:** *"Now I'm probing your machine to see what's installed and authed. Nothing gets installed in this step — I'm just running `which`, `--version`, `auth status` style commands and parsing the output. Takes ~10 seconds."*

**Run all probes in parallel** via a single Bash call when possible. Capture stdout, stderr, exit codes. Build a `detection_report` object in skill memory.

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
command -v rg 2>&1                          # ripgrep
which node 2>&1; node --version 2>&1        # Node (for local MCPs)
```

**CCv4-toolchain probes** (these come from `./scripts/install.sh` — if all three are missing, the fork user almost certainly skipped the installer and `/research` + `/autonomous` will be dead until they run it):
```bash
which bloks 2>&1; bloks --version 2>&1       # Ouros REPL — backs /research
which tldr 2>&1; tldr --version 2>&1         # tldr cache — used by tldr-read hook
which fastedit 2>&1; fastedit --version 2>&1 # FastEdit MCP — surgical AST edits
```

Store as `detection_report.ccv4_install_state`:
- `all-present` → ✅ install.sh was run successfully
- `partial` → ⚠️ install.sh partially completed (rare — surface counts)
- `none` → ❌ install.sh likely skipped — surface STRONG hint in detection panel and gate (c) in the proceed AskUserQuestion (see below)

For each, parse into `detection_report.clis.<name>` with fields: `installed` (bool), `version` (str), `authed` (bool), `scopes` (list), `notes` (str).

**MCP probes:**
```bash
jq '.mcpServers | keys[]' .mcp.json 2>&1            # configured MCPs
ls ~/.claude/plugins/installed_plugins.json 2>&1    # installed plugins
[[ -n "${GEMINI_API_KEY:-}" ]] && echo SET || echo UNSET  # for stdio MCPs that need env vars
```

For each MCP in `.mcp.json.mcpServers`:
- `mcp.<name>.url` (or `command` for stdio)
- `mcp.<name>.type` (http/stdio)
- `mcp.<name>.notes` (from `_notes` block, if any)
- `mcp.<name>.connected`: **do an actual in-session probe**:
  1. Check the deferred-tools list (visible at session start in system-reminders) for any `mcp__<name>__*` tools. If present → `✅ connected`.
  2. If absent → `⏳ configured — needs /mcp authorize for this workspace` (per-project OAuth state).
  3. For stdio MCPs (e.g., gemini-vision): verify required env vars. If unset → `⚠️ stdio MCP needs $GEMINI_API_KEY in shell env`. If set + tools present → `✅ connected`.
  4. Honesty rule: if you can't determine state, write `ℹ️ configured — status unverified` rather than guessing.

**Pipeline tools probe:**
```bash
which jq rg ffmpeg yt-dlp 2>&1
```

**Workspace state probe:**
```bash
ls -d workspace 2>&1                              # default workspace folder name (may already be renamed)
for d in 0-Inbox 1-Projects 2-Coding 3-Resources 3-Resources/github-forks 4-Archive; do
  test -d "workspace/$d" && echo "OK  $d" || echo "MISSING  $d"
done
```

**Persona files state probe:**
```bash
for f in SOUL.md USER.md IDENTITY.md CLAUDE.md README.md TOOLS.md; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    git diff --quiet HEAD -- "$f" && echo "CLEAN     $f" || echo "MODIFIED  $f"
  else
    echo "UNTRACKED $f"
  fi
done
```

#### Render the detection panel (CRITICAL — this is the new transparency step)

After all probes finish, **render a single status panel** to the user showing what was found. Format:

```
🔍 Environment scan complete. Here's what I found on your machine:

CCv4 toolchain (from ./scripts/install.sh):
  ✅ bloks v0.1.0, tldr v0.4.0, fastedit v0.5.0 — install.sh ran successfully
  (OR — if missing —)
  ❌ bloks, tldr, fastedit — NOT installed. Looks like you skipped
     ./scripts/install.sh. /research and /autonomous will not work
     until you run it. Strongly recommend aborting (option c below) and
     running the installer first.

CLIs:
  ✅ gws        v0.X.Y — authed (you@example.com, 7 scopes)
  ✅ gh         v2.X — authed (your-gh-handle)
  ⚠️  databricks v0.X — installed; profile you@example.com valid, default broken
  ⚠️  sf         v2.X — installed; auth broken (AuthDecryptError on 3 orgs)
  ❌ yt-dlp     — NOT installed (needed by transcript-extract.sh)

Pipeline tools:
  ✅ jq, rg, ffmpeg — installed
  ❌ yt-dlp — NOT installed

MCPs (from .mcp.json):
  ✅ gemini-vision  (stdio, local) — connected, GEMINI_API_KEY set
  ⏳ slack          (http) — configured, needs /mcp authorize for this workspace
  ⏳ atlassian      (http) — configured, needs /mcp authorize
  ⏳ figma          (http) — configured, needs /mcp authorize
  ⏳ exa            (http) — configured, needs /mcp authorize

Workspace skeleton (workspace/):
  ✅ 0-Inbox, 1-Projects, 3-Resources, 4-Archive exist
  ❌ 2-Coding/{work,personal,forks,archive} — MISSING (will create in Step 6)

Persona files (git diff against HEAD):
  CLEAN     SOUL.md, IDENTITY.md, USER.md, CLAUDE.md, README.md, TOOLS.md

Setup state: fresh fork (no setup_completed: line found)
```

**Then `AskUserQuestion` gate** (user picked "Confirm every step" + "Summary with drill-down"):

| Question | Options |
|----------|---------|
| "Proceed with this detection result?" | (a) **Proceed to identity collection** (Step 3) / (b) **Show me the full probe output** (print raw stdout/stderr per tool) / (c) **Fix something first** (abort cleanly so user can install/auth a missing tool, then re-run /bootstrap) |

**Special handling for `ccv4_install_state == "none"`**: BEFORE the standard gate, surface this extra prompt:

> ⚠️ Heads up: `bloks`, `tldr`, and `fastedit` are all missing from your PATH. That's the signature of a fork user who skipped `./scripts/install.sh`. The persona-config half of `/bootstrap` will still work fine without those binaries — but `/research`, `/autonomous`, and the FastEdit MCP will be dead until you run install.sh.
>
> Recommended: pick (c), exit, run `./scripts/install.sh`, then re-run `/bootstrap`. ~10-15 min for the installer; one-time cost.

Then issue the standard gate. Default-recommend (c) when this case fires; default-recommend (a) otherwise.

If (b) chosen: print all raw probe output verbatim, then re-ask the same question.

If (c) chosen: print *"Fine — go install/auth what you need, then run /bootstrap again. No changes made."* and STOP.

---

### Step 3: Identity collection (AskUserQuestion-driven)

**Narrate:** *"Now I need to know who you are. I've prefilled defaults where I could detect them — review each one and edit if wrong. These values write to the Configuration section of CLAUDE.md and get substituted into your persona files."*

**Detect defaults** in parallel:
```bash
git config user.email 2>/dev/null
git config user.name 2>/dev/null
date +%Z 2>/dev/null
gh api user --jq .login 2>/dev/null
```

**Ask in batched groups** (3 fields per `AskUserQuestion` call, since users can type custom values via "Other"):

**Group 1 — name + email:**
- `user.full_name` — *"Your full display name?"* (no detected default)
- `user.name` — *"What should I call you (short name)?"* (default: first word of full_name once entered)
- `user.email` — *"Email address?"* (default: `git config user.email`)

**Group 2 — location + GitHub:**
- `user.timezone` — *"Timezone?"* (default: `date +%Z`; e.g., `America/New_York`)
- `user.github` — *"GitHub username?"* (default: `gh api user --jq .login` if `gh` authed)
- `user.company` — *"Company / org? (optional)"* (default: domain from email if it looks company-shaped)

**Group 3 — signature + workspace:**
- `user.email_signature` — *"Email signature line?"* (default: `<full_name>` as starter)
- `workspace.root` — *"Workspace folder name?"* (default: `workspace`; common alternatives: `brain`, `vault`, `<assistant>-workspace`)

Validate lightly: no spaces in github username; email contains `@`. Re-prompt on obvious typos.

**After all 8 collected, echo back:**
```
Got it. Here's what I'll write:

  user.name         = <value>
  user.full_name    = <value>
  user.email        = <value>
  user.timezone     = <value>
  user.github       = <value>
  user.company      = <value>
  user.email_signature = <value>
  workspace.root    = <value>
```

`AskUserQuestion`: *"Look right?"* — (a) **Confirm, move on** / (b) **Edit one** (re-asks which field to edit) / (c) **Restart Step 3**.

---

### Step 4: Persona pick (AskUserQuestion-driven)

**Narrate:** *"Now the assistant persona. You can keep the default chief-of-staff persona (named Beru), or customize a new one. If you customize, Step 6 regenerates SOUL.md, USER.md, IDENTITY.md, README.md from templates with your values substituted in."*

**AskUserQuestion:**

| Question | Options |
|----------|---------|
| "How do you want the persona configured?" | (a) **Keep the default** — chief-of-staff, "Beru", 🎯 emoji, professional-but-warm voice. Skips regeneration of SOUL/IDENTITY/README in Step 6. / (b) **Customize a new persona** — collect name, role, vibe, emoji. Regenerates all persona files in Step 6. / (c) **Keep current files as-is** — even more conservative; useful if you've already hand-edited SOUL/IDENTITY/USER. Step 6 skips ALL persona regen. |

**If (a) "keep default":** record
- `assistant.name` = `Beru`
- `assistant.role` = `Chief of Staff`
- `assistant.vibe` = `Professional but warm — like a trusted exec assistant who's worked with you for years. Direct, no corporate fluff, detail-heavy.`
- `assistant.emoji` = `🎯`

**If (b) "customize":** AskUserQuestion follow-up batch:
- `assistant.name` — *"Name for the assistant?"* (e.g., Atlas, Echo, Pierre, Cortex, Sage)
- `assistant.role` — *"Short role descriptor?"* (e.g., "Chief of Staff", "Research Companion", "Engineering Co-Pilot")
- `assistant.vibe` — *"One-line vibe descriptor?"* (e.g., "Quiet and analytical, like a librarian who knows where every book is")
- `assistant.emoji` — *"Single emoji?"* (e.g., 🎯, 📚, ⚙️, 🧠)

**If (c) "keep as-is":** record values from current `IDENTITY.md` / `SOUL.md` (read them) — used for Configuration write only, no template regen.

---

### Step 5: Design system pick (AskUserQuestion-driven)

**Narrate:** *"The `design:*` skills (decks, dashboards, landing pages, posters, etc.) read brand tokens from a root `DESIGN.md` file. We ship 72 brand presets — pick one as your active brand. You can swap anytime with `/use-design <brand>`."*

**Read available brands:**
```bash
ls workspace/3-Resources/design-systems/ | grep -v '^README'
```

**Category-first picker** (AskUserQuestion with 4 options — categories grouped so the list fits):

| Question | Options (group 1) |
|----------|-------------------|
| "Pick a category for your active brand:" | (a) **AI & LLM** (claude, cohere, elevenlabs, mistral-ai, ollama, replicate, runwayml, together-ai, x-ai…) / (b) **Developer Tools** (cursor, raycast, superhuman, vercel, warp…) / (c) **Productivity & SaaS** (cal, intercom, linear-app, notion, resend…) / (d) **More categories** |

If "More categories" picked, follow-up:
- (a) Backend & Data (clickhouse, mongodb, posthog, sentry, supabase…)
- (b) Design & Creative (airtable, figma, framer, miro, webflow…)
- (c) Fintech & Crypto (stripe, coinbase, kraken, revolut, wise…)
- (d) **Even more** → Media & Consumer, Automotive, E-Commerce, Starter, Hand-authored

Then within the chosen category, AskUserQuestion lists brands with their tagline (read first 3 lines of each `DESIGN.md`).

**Three meta-options always offered (in every category question's option list):**
- **(default)** — `default` brand (Neutral Modern starter — safe pick)
- **(keep current)** — leave the existing root `DESIGN.md` as-is
- **(magenta placeholder)** — leave the bright `#ff00aa` REPLACE-ME draft

**After pick, run the `/use-design <brand>` equivalent:**
```bash
test -f DESIGN.md && cp DESIGN.md .DESIGN.md.previous
cp "workspace/3-Resources/design-systems/<brand>/DESIGN.md" DESIGN.md
```

**Surface:** *"Active design system: `<brand title>`. Backup at `.DESIGN.md.previous` if you want to undo. Swap anytime with `/use-design <other-brand>`."*

---

### Step 6: Apply persona files + workspace skeleton + TOOLS.md (with previews)

This step has three sub-steps. **Narrate before each one** so the user knows what's happening.

#### Step 6a: Persona file regeneration (T1 invariant)

**Narrate:** *"Now regenerating persona files from templates. I'll check each file against its git-tracked version first — if you've edited it, I'll ask before overwriting (defaults to skip)."*

**Files in scope** (depends on Step 4 pick):
- If Step 4 = (a) keep-default → regenerate USER.md only (your details), skip SOUL/IDENTITY/README (keep Beru voice)
- If Step 4 = (b) customize → regenerate SOUL.md, IDENTITY.md, USER.md, README.md from templates with your values
- If Step 4 = (c) keep as-is → skip ALL files; only Configuration block in CLAUDE.md updates in Step 7

**For each file in scope, per-file flow:**

```bash
git show HEAD:<file> 2>/dev/null > /tmp/upstream_<file>
diff -q /tmp/upstream_<file> <file>   # exit 0 = clean; exit 1 = modified
```

**Narrate per file:** *"Checking `<file>`… clean / modified beyond upstream."*

**If clean** (matches upstream): print *"Safe to overwrite — your `<file>` matches what was checked into git, no manual edits to preserve."* Read template, substitute placeholders, write. Print *"✅ Wrote `<file>`."*

**If modified** (T1 invariant triggers): `AskUserQuestion`:

| Question | Options |
|----------|---------|
| "Your `<file>` has edits beyond the upstream version. What should I do?" | (a) **Skip** — preserve your edits. (Recommended) / (b) **Show diff** — print `git diff HEAD -- <file>` and re-ask / (c) **Overwrite** — replace with regenerated template / (d) **Save regenerated copy to `<file>.bootstrap-suggested`** — write the new version side-by-side so you can manually merge later |

Default = (a) skip.

**Placeholder substitution** (use `sed` for atomic substitution, single command per file):
```bash
sed \
  -e "s/<user.name>/${USER_NAME}/g" \
  -e "s/<user.full_name>/${USER_FULL_NAME}/g" \
  -e "s/<user.email>/${USER_EMAIL}/g" \
  -e "s/<user.timezone>/${USER_TZ}/g" \
  -e "s/<user.github>/${USER_GITHUB}/g" \
  -e "s/<user.company>/${USER_COMPANY}/g" \
  -e "s|<user.email_signature>|${USER_SIG}|g" \
  -e "s/<assistant.name>/${ASSISTANT_NAME}/g" \
  -e "s|<assistant.role>|${ASSISTANT_ROLE}|g" \
  -e "s|<assistant.vibe>|${ASSISTANT_VIBE}|g" \
  -e "s/<assistant.emoji>/${ASSISTANT_EMOJI}/g" \
  -e "s/<workspace.root>/${WORKSPACE_ROOT}/g" \
  workspace/3-Resources/templates/persona/<file>-template.md > <file>
```

After all in-scope files processed, narrate a one-line summary: *"Persona files: wrote `<list>`, skipped `<list>` (preserved your edits)."*

#### Step 6b: Workspace skeleton (idempotent — T4)

**Narrate:** *"Now ensuring the workspace folder skeleton exists. This is idempotent — `mkdir -p` only, never destructive. If you renamed `workspace.root` in Step 3, I'll `mv` the folder first."*

**If `workspace.root` was renamed:**
```bash
if [[ -d workspace && ! -d "${WORKSPACE_ROOT}" ]]; then
  mv workspace "${WORKSPACE_ROOT}"
  echo "Renamed workspace/ → ${WORKSPACE_ROOT}/"
fi
```

**Then create missing canonical subdirs:**
```bash
mkdir -p "${WORKSPACE_ROOT}"/{0-Inbox,1-Projects,2-Coding/{work,personal,forks,archive},3-Resources/{templates,research,reference,meetings,contacts,design-systems},4-Archive}
```

**Surface diff:** which subdirs were newly created vs already existed (cross-reference Step 2's workspace probe).

#### Step 6c: TOOLS.md generation with preview (T1 invariant)

**Narrate:** *"Now generating TOOLS.md from the Step 2 detection panel. I'll show you the content before writing — you can accept, save to a side-file for review, or skip entirely."*

**Build content** from `detection_report`. Skeleton — every status flag must trace back to a real Step 2 probe result, no fabrication:

```markdown
# TOOLS.md — Tool Index

**Auto-loaded at every session start.** Generated by `/bootstrap` on <YYYY-MM-DD>. Re-run `/bootstrap` (after deleting `setup_completed:` line) to regenerate, or edit by hand.

## Connected MCPs (this repo's `.mcp.json`)

<from detection_report.mcps — one line per MCP with ✅/⏳/⚠️/ℹ️ flag and any notes>
- ✅ **gemini-vision** (stdio, local) — connected, GEMINI_API_KEY set. 7 tools: image, OCR, multi-image, compare, filename suggestion, document, video.
- ⏳ **slack** (http) — `https://mcp.slack.com/mcp`. Configured but not authorized in this workspace. Run `/mcp` to authorize.
- ⏳ **atlassian** (http) — Run `/mcp` to authorize.
- ...

## CLIs

<from detection_report.clis — one line per CLI>
- ✅ **`gws`** (Google Workspace CLI) — v<X.Y> authed (`<email>`, <N> scopes: <comma-list>). Called directly via Bash by `/briefing` (Gmail triage + calendar agenda). No `gws-*` / `recipe-*` wrapper bundle ships in this harness; re-add from `~/.agents/skills/gws-*` if you want the wrappers back.
- ✅ **`gh`** (GitHub CLI) — v<X.Y> authed as `<username>`, scopes: <list>.
- ⚠️ **`databricks`** — v<X.Y> installed; profile `<email>` valid, default profile broken. Pass `-p <email>` or set `DATABRICKS_CONFIG_PROFILE`.
- ⚠️ **`sf`** (Salesforce CLI) — v<X.Y> installed; auth broken (`sf org login web -a <alias>` to fix). Open question: is Salesforce load-bearing for your flow? If not, leaving broken is fine.
- ❌ **`yt-dlp`** — NOT installed. Install: `brew install yt-dlp`. Required by `transcript-extract.sh`.

## Pipeline tools

- ✅ `jq`, `rg`, `ffmpeg` — installed
- ❌ `yt-dlp` — NOT installed; install via `brew install yt-dlp`

## Native skill bundles (in `.claude/skills/`)

The full inventory is visible at session start in the available-skills list. Bundle map:

- ✅ **`design-*`** (14) — HTML/visual artifact skills (decks, dashboards, landing pages, blog posts, OKR trackers, PM specs, finance reports). Brand tokens from root `DESIGN.md`. Library: `<workspace.root>/3-Resources/design-systems/`. Swap: `/use-design <brand>`.
- ✅ **<assistant.name>-internal** (15) — `archive-project`, `briefing`, `bootstrap`, `budget-tracker`, `contact`, `contact-log`, `desktop-organizer`, `find`, `inbox-process`, `new-project`, `prune-projects`, `save-resource`, `skill-creator`, `sync-indexes`, `thinking-partner`.
- (NOT shipped — dropped v0.1.13: 21 `gws-*` CLI wrappers, 12 niche `design-*`, all `recipe-*` / `persona-*`. Re-add from `~/.agents/skills/` if needed.)

## ContinuousClaude V4.7 bundle

9 skills (`autonomous`, `autonomous-research`, `bootup`, `create-handoff`, `premortem`, `research`, `resume-handoff`, `review`, `upgrade-harness`) + 5 hooks + 4 Python tools. Run `./scripts/install.sh` to install supporting binaries. See `INSTALL.md`.

## Standard Claude Code tools (always available)

`Read`, `Write`, `Edit`, `Bash`, `Glob`, `Grep`, `Skill`, `Agent`, `Task` family, `AskUserQuestion`, `CronCreate`/`List`/`Delete`, `WebFetch`, `WebSearch`, `Monitor`, `NotebookEdit`, `RemoteTrigger`, `PushNotification`.

## Google Drive (project-critical IDs)

<TBD — fill in if you use Drive folders for source-of-truth content. /bootstrap can't know which Drive folders matter to you.>

- **Meeting Transcripts:** `<TBD>` (e.g., Tactiq full transcripts folder ID)
- **Meeting Recordings:** `<TBD>` (e.g., Gemini AI summaries — prefer when available)

## Platform formatting

- **WhatsApp:** No markdown tables, no headers. Use `*bold*` and bullet lists.
- **Discord:** Wrap multiple links in `<>` to suppress embeds.
- **Slack:** plain markdown works in messages; canvases support richer formatting. Avoid `#` headers in regular messages — use `*bold*` for emphasis.

## NOT connected (intentional or gated)

<TBD — list tools you've explicitly chosen NOT to install. Helps future-you (and your fork audience) know what was deliberate vs accidentally missing.>

## When tools change

1. Edit this file — flip the status flags.
2. Re-run `/bootstrap` (delete `setup_completed:` line first) to regenerate from current detection, OR edit by hand.
3. If a Layer 3 skill (`/briefing`, `/meeting-prep`) gated on a tool, update its composition map too.

## Discipline: every entry needs a probe

Adding an entry to TOOLS.md? Back it with a **verification probe** — a command output, a test invocation, a Bash check. Vibes-based entries drift.
```

**T1 check on TOOLS.md:**
```bash
git diff --quiet HEAD -- TOOLS.md && echo CLEAN || echo MODIFIED
```

**Preview + AskUserQuestion gate (user picked "Preview + accept/skip"):**

Print the full generated content to the user. Then:

| Question | Options |
|----------|---------|
| "Here's the TOOLS.md I'd write. What now?" | (a) **Write it** — replace root TOOLS.md (T1 check: if file modified, downgrade to (b)) / (b) **Write to `TOOLS.md.bootstrap-suggested`** — leave current TOOLS.md alone, save the generated version side-by-side so you can manually merge / (c) **Skip TOOLS.md entirely** — keep current, no side-file |

If T1 flag is MODIFIED, force (b) unless user explicitly overrides — show one extra confirmation: *"TOOLS.md has uncommitted edits. Defaulting to side-file write so I don't lose them. Override with 'force overwrite' if you really mean it."*

---

### Step 7: Configuration write + smoke test

**Narrate:** *"Now writing the Configuration section in CLAUDE.md (this is the atomic commit point — every value collected so far lands here) and running a smoke test through `/new-project` to verify placeholder substitution actually works end-to-end."*

#### Step 7a: Configuration write

Edit root `CLAUDE.md` Configuration section using `Edit` tool with line anchors. **Show the user the diff before writing.**

Required edits (one `Edit` call per line, or one Write of the whole Configuration block):
- `user.name` line → Step 3 value
- `user.full_name` line → Step 3
- `user.email` line → Step 3
- `user.timezone` line → Step 3
- `user.github` line → Step 3
- `user.email_signature` line → Step 3
- `user.company` line → Step 3
- `assistant.name` line → Step 4
- `assistant.role` line → Step 4
- `assistant.vibe` line → Step 4
- `assistant.emoji` line → Step 4
- `workspace.root` line → Step 3 (if renamed)
- **append `setup_completed: <YYYY-MM-DD>` line** to `### lifecycle` section (T2 re-run gate)

**AskUserQuestion before edits:**

| Question | Options |
|----------|---------|
| "I'm about to write 12 Configuration lines + `setup_completed:` to CLAUDE.md. The diff is shown above. Proceed?" | (a) **Yes, write it** / (b) **Show me the exact diff again** / (c) **Skip Configuration write** (will block smoke test — abort cleanly) |

After write, **append a daily-log entry** to `memory/<YYYY-MM-DD>.md`:

```markdown
## <YYYY-MM-DD HH:MM> — /bootstrap run

Configured fork:
- user.name: <value>
- user.full_name: <value>
- user.github: <value>
- assistant.name: <value> (default-kept / customized)
- workspace.root: <value>
- design-system: <brand name>
- Persona files regenerated: <list, or "kept default">
- Tool probes: <N CLIs ready, M missing, K MCPs ✅, L MCPs ⏳>

Smoke test: <PASSED / FAILED — see <path>>
```

#### Step 7b: Smoke test via `/new-project`

**Narrate:** *"Running the smoke test now — invoking `/new-project` with a throwaway name to verify placeholder substitution. If it fails (placeholder string `<user.name>` literal still appears in the scaffolded files), I'll leave the artifact for debugging rather than deleting it."*

Invoke `/new-project` via the Skill tool with:
- name: `bootstrap-smoke-test-<HHMMSS>` (timestamp suffix prevents collisions)
- type: `design` (lightest scaffold — no GitHub repo, no extra branches)
- skip Step 0's "find existing" gate

**After scaffold completes, verify:**
1. Folder exists at `<workspace.root>/<workspace.projects>/<YYYY-MM>-bootstrap-smoke-test-<HHMMSS>/`
2. `CLAUDE.md` inside the new project contains the user's `<user.name>` value (literal value, not the `<user.name>` placeholder string)
3. `memory.md` contains today's date entry

**On PASS:**
```bash
rm -rf <path-to-smoke-test-project>
```
Print *"✅ Smoke test passed. Placeholder resolution working end-to-end."*

**On FAIL:**
- DO NOT delete the smoke-test artifact (leave for debugging — surfaces a real bug to fix)
- Print *"⚠️ Smoke test FAILED — placeholder resolution didn't work. Inspect: `<path>`. Configuration section may need manual review. Proceeding to Step 8 with this caveat."*

---

### Step 8: Final summary (T3 invariant — never auto-commit)

**Narrate:** *"All done. Here's the rundown — what was written, what still needs your attention, where to start, and how to commit."*

The closing message has four sections. Every status flag must trace back to a real Step 2 probe.

#### Section 1 — confirmation + smoke test result

One line. Example:
> ✅ /bootstrap complete. Smoke test passed. 7 files modified, 4 created, workspace skeleton ensured.

Or if smoke test failed:
> ⚠️ /bootstrap completed with smoke-test failure. 7 files modified, but `/new-project` smoke test left placeholders. Inspect `<path>` and fix Configuration before relying on this setup.

#### Section 2 — "What needs your attention right now"

Filter from `detection_report` — only surface items needing user action:
- **If `ccv4_install_state == "none"`: surface this FIRST and most prominently** — `❌ ./scripts/install.sh — looks unrun (bloks/tldr/fastedit missing on PATH). /research, /autonomous, and FastEdit MCP will not work until you run it. Exit Claude Code, run the installer, restart.`
- Skip MCPs marked `✅ connected`
- Surface `⏳ configured — needs /mcp authorize`, `⚠️ stdio MCP needs env var`, `❌ tool not installed`, `⚠️ CLI auth broken`
- If nothing needs attention: *"Everything's authed and ready — no MCP or CLI followups."* Skip Section 2's body.
- Include the per-workspace OAuth disclaimer **once** at the top: *"(MCP OAuth is per-project in Claude Code — even if you've authorized these elsewhere, this workspace needs its own grants.)"*

Example:
```
What needs your attention right now:

(MCP OAuth is per-project in Claude Code — even if you've authorized these
elsewhere, this workspace needs its own grants.)

❌ ./scripts/install.sh appears unrun — bloks/tldr/fastedit missing. Run it
   before relying on /research or /autonomous.
⏳ Run /mcp → authorize slack, atlassian, figma, exa for this workspace (~30s each)
❌ brew install yt-dlp (transcript-extract.sh needs it)
⚠️ sf org login web -a samba-prod (Salesforce CLI auth broken — only if you use SF)
```

#### Section 3 — "Day 1 — start here (in this order)"

Numbered walkthrough. Skip steps that aren't relevant (e.g., skip "authorize MCPs" if Section 2 was empty).

```
Day 1 — start here:

1. Authorize any MCPs flagged above
   Run /mcp → walk through the OAuth flow for any ⏳ entries. Standard browser
   OAuth, no clientId or app registration needed. Skip this step if Section 2
   was empty.

2. Fill in USER.md
   Step 6a left <TBD> placeholders for your team, priority signals, Slack channels.
   /briefing reads these — without them the brief still works but surfaces less.
   Takes ~5 minutes.

3. Try /briefing
   First run will be sparse (empty contacts, empty projects, USER.md half-full)
   — that's expected on a fresh fork. The point is to see the shape and confirm
   MCPs are returning data. Writes to
   <workspace.root>/3-Resources/briefings/morning-briefing-YYYY-MM-DD.md.

4. Scaffold your first project
   /new-project Q3-strategy (or whatever you're actually working on). Creates
   <workspace.root>/1-Projects/YYYY-MM-q3-strategy/ with its own CLAUDE.md +
   memory.md. This is the pattern for every project from here.

5. Add one contact
   Drop a teammate at <workspace.root>/3-Resources/contacts/<slug>.md following
   the schema in contacts/README.md. Then /contact <name> should fuzzy-match.
   Repeat for your inner circle over time.

Day 2+ — natural rhythms:

- /os-guide              when you don't know how something in this OS works (PARA,
                         Configuration tokens, tools, project lifecycle, etc.) —
                         reads canonical files live, so it can't drift
- /find <topic>          when you're not sure if you've already noted something
- /contact-log <name>    after every meaningful call or 1:1
- /thinking-partner      when you want to explore before solving
- /save-resource         to stash a link / doc for later
- /prune-projects        every Friday to clean up stale work
- /use-design <brand>    to swap the active design system (72 brands shipped)
- /os-guide --sync       after adding a new tool, skill, or design brand — refreshes
                         /os-guide's routing table so it sees the new addition

For everything else, just talk naturally — Claude routes to the right skill via
the description field. /help for the full skill list if you want to browse.
```

#### Section 4 — manifest + commit instructions (T3 — never auto-commit)

```
Files written or modified:
- SOUL.md, IDENTITY.md, USER.md, README.md — regenerated from persona templates (or "kept as-is — your edits preserved")
- TOOLS.md — regenerated from live probes (or "saved to TOOLS.md.bootstrap-suggested" if T1 flagged)
- CLAUDE.md — Configuration section tokenized with your values
- DESIGN.md — swapped to <brand> (previous backed up to .DESIGN.md.previous)
- <workspace.root>/2-Coding/{work,personal,forks,archive}/ — created
- memory/<YYYY-MM-DD>.md — new daily log entry

Active design system: <brand title> — swap anytime with /use-design <brand>

/bootstrap did NOT auto-commit (T3 invariant). Review the diff and commit when
you're ready:

  git status
  git diff
  git add SOUL.md IDENTITY.md USER.md README.md TOOLS.md CLAUDE.md DESIGN.md memory/<YYYY-MM-DD>.md <workspace.root>/2-Coding/
  git commit -m "fork bootstrap: configure as <user.name> / <assistant.name> / <brand>"

To re-run /bootstrap later: delete the `setup_completed: <date>` line in
CLAUDE.md, then invoke /bootstrap again.

That's the lay of the land. Where do you want to start?
```

---

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Skill runs on already-configured fork | T2 detection failed | Step 1 MUST grep for `setup_completed:` line in CLAUDE.md and refuse if found |
| Persona files overwritten despite user edits | T1 detection mechanism not concrete | Step 6a uses `git show HEAD:<file>` + `diff -q` — concrete + repeatable. Default to skip on MODIFIED. |
| Skill auto-committed | T3 violation | NEVER `git add` or `git commit` — explicit invariant. Step 8 surfaces commands as text only. |
| Skill tried to install gws/gh/yt-dlp | T4 violation | Step 2 is READ-ONLY probes. Step 8 surfaces install hints — never runs them. |
| Smoke test passed but new project still has placeholder | Step 7b ran before Step 7a | Step order is FIXED: 7a (Configuration write) → 7b (smoke test). |
| TOOLS.md generated but missing tools detected on the system | Step 2 probe list incomplete | Add to probe list — TOOLS.md is dynamic, regenerable via re-run. |
| Workspace skeleton clobbered existing content | Step 6b was destructive | `mkdir -p` only — never `rm -rf`, never overwrite existing subfolder contents. |
| Configuration section edits clobbered each other | Multiple Edit calls without unique anchors | Use `Edit` tool with unique line anchors per field; show diff before writing. |
| MCP probe failed and skill aborted | Probes treated as fatal | Probes are informational (`2>&1 \|\| true`). Surface ⚠️ in detection panel and continue. |
| User skipped Step 5 design pick | Skill aborted on missing input | AskUserQuestion always offers "(keep current)" / "(default neutral)" / "(magenta placeholder)" as escape hatches. |
| User abandoned mid-flow (Ctrl-C between steps) | Partial state | Step 7a's Configuration write is the atomic commit point. If skill exits before Step 7a, no `setup_completed:` line is written, and the next /bootstrap run picks up cleanly. Steps 5–6 are idempotent (re-runnable). Step 6a file overwrites are the riskiest mid-flow cancel — minimize by ordering Step 6a AFTER user approves every persona file individually. |
| User sees no narration, doesn't know what's happening | Skill ran without surfacing detection panel or step-by-step "about to do X" text | Every step has a "Narrate" block at the top — emit it as text before running probes/writes. Detection panel in Step 2 is the most important transparency moment. |
| TOOLS.md generated with wrong status flags | Bootstrap fabricated ⏳ for connected MCPs | Status flags MUST trace back to real Step 2 probe results. Honesty rule: write `ℹ️ unverified` rather than guessing. |

## Boundaries

- **NEVER auto-commit** (T3). User reviews diff, user commits.
- **NEVER install tools** (T4). Surface hints; don't run them.
- **NEVER overwrite user-edited persona files without explicit confirmation** (T1). Default = skip.
- **NEVER re-run on already-configured fork without setup_completed: line being deleted first** (T2).
- **NEVER alter `2-Coding/` repos.** Independent gits with their own state. `/bootstrap` only creates the empty `{work,personal,forks,archive}/` skeleton folders.
- **NEVER write to `memory/` other than today's daily log.** Append-only by convention.
- **NEVER call Exa / WebSearch / WebFetch.** Bootstrap is local — no web search.
- **NEVER fabricate detection results.** Every ✅/⏳/⚠️/❌ in TOOLS.md and the Step 8 summary must trace back to a real Step 2 probe. When unsure, write `ℹ️ unverified` and let the user verify manually.
- **NEVER skip the narration.** Each step's "Narrate" block is part of the contract — emit it as user-visible text, not internal thinking.

## Re-run mechanism

The skill's re-run gate is the `setup_completed: <date>` line in the `### lifecycle` section of CLAUDE.md's Configuration block. Presence = configured (refuse, point at `/update-config`). Absence = fresh fork (proceed).

To re-run `/bootstrap`:
1. Edit root `CLAUDE.md`
2. Delete the `- \`setup_completed\` = \`<date>\`` line
3. Invoke `/bootstrap` again

Steps 2, 5, 6b are idempotent (won't double-create folders, won't re-prompt for already-set values if user enters the same answers). Step 6a protects user edits via T1. Step 7a overwrites the Configuration section with fresh values. Step 7b's smoke test runs again to verify.

For lighter-weight reconfigs (just changing your name, swapping the brand, updating one persona file) — use `/update-config` instead. It's purpose-built for partial edits, doesn't touch persona files, doesn't run a smoke test.
