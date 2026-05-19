---
name: bootstrap
description: Interactive first-run setup for a fresh fork of the second-brain-os — THE entry point every fork user runs once to configure identity, the assistant's persona (no default name — fork user always names their own assistant), the user's writing voice (sampled or described, saved to memory/writing-style.md), design system, workspace skeleton, TOOLS.md, and the Configuration token block in root CLAUDE.md. Walks through 6 narrated steps with AskUserQuestion gates, conversational explanations of WHY each step matters (not just WHAT), read-only environment probes (tier-aware via SBOS_TIER — CCv4 toolchain probes only fire on coding tier), live tool-detection panel (✅/⏳/⚪/⚠️/❌), persona-file regeneration from templates (preserves user edits via git-diff vs upstream), writing-voice analysis from sample or descriptive answers, TOOLS.md preview before write, and a smoke test through `/new-project` to verify placeholder substitution. Detects re-runs via `setup_completed:` in Configuration; refuses gracefully. Use after cloning the repo, or when reconfiguring identity / persona / workspace / voice — phrases like "/bootstrap", "I just cloned this", "first-time setup", "configure the assistant". Tiger invariants T1-T4 (never overwrite user-edited persona files, never re-run on configured fork, never auto-commit, never install tools) live in SKILL.md body.
allowed-tools: Read Write Edit Bash AskUserQuestion Skill
---

# bootstrap

First-run setup. Walks a freshly-cloned fork through identity, the assistant's persona (you always name your own — no default anchor), your writing voice, design system, workspace, TOOLS.md, configuration, and a smoke test. **6 narrated steps, ~15-20 minutes for a thorough first run.**

**Why this is the most important skill:** every fork user runs this exactly once, and the entire harness is built on what `/bootstrap` writes. A broken `/bootstrap` ships a broken second brain to every fork.

**Design principle — full transparency, conversational tone.** Narrate the *why* before every probe and write. Each substantive write gets a preview + `AskUserQuestion` gate. Detection results render as a confirmable panel before any side-effecting step. Tone is "trusted colleague explaining as we go," not "automated wizard."

## Tiger invariants (LOAD-BEARING — DO NOT VIOLATE)

The four tiger invariants are referenced by ID throughout this file (in step headers and the failure-modes table). Canonical statements live here only.

### T1 — NEVER overwrite user-edited persona files without explicit confirmation

If a root persona file (`SOUL.md`, `USER.md`, `IDENTITY.md`, `CLAUDE.md`, `README.md`, `TOOLS.md`) has been edited beyond what the persona template would produce, Step 5 MUST detect this via `git show HEAD:<file>` comparison and ask before overwriting. Default behavior: skip. Only overwrite when user explicitly confirms.

### T2 — NEVER re-run on already-configured fork without explicit user action

Step 1 detects re-run via `grep -E "^- \`setup_completed\` = " CLAUDE.md`. If found, refuses and prints: *"This fork is already configured (setup_completed: <date>). To re-run /bootstrap, delete the `setup_completed` line in CLAUDE.md and invoke /bootstrap again, or use `/update-config` for partial edits."* Do NOT proceed past Step 1.

### T3 — NEVER auto-commit

After all writes complete, surface the diff (or path list) and tell the user to commit manually. NEVER invoke `git add` or `git commit`.

### T4 — NEVER install tools

Step 2 is READ-ONLY probes. If a tool is missing/unauthed, surface a hint pointing at the appropriate installer — `brew install <tool>` + the tool's own auth flow, or `/mcp` for MCPs. Never run the installer.

---

## Process — 6 narrated steps

### Step 0: Welcome + plan preview

**Narrate to user (verbatim, no assistant name yet — you don't have one until Step 4):**

> Hey — welcome. You've just cloned a second-brain harness, and now we're going to make it *yours*. Not mine. Not the original author's. Yours. By the end of this you'll have an assistant with the name you pick, a personality you describe, and enough understanding of how *you* write that it can draft in your voice.
>
> Here's the plan — 6 steps, ~15-20 minutes. Every write asks before it happens. Nothing gets installed. Nothing gets committed. You're in the driver's seat the whole time.
>
> 1. **Safety check** — make sure this fork isn't already configured (so we don't clobber anything)
> 2. **Look around your machine** — see what CLIs, MCPs, and tools are installed (read-only)
> 3. **Who you are** — your name, email, GitHub, timezone — the basics that get substituted everywhere
> 4. **Design your assistant + teach it your voice** — name, role, vibe, pronoun, emoji; then sample writing or describe how you write
> 5. **Apply** — persona files, workspace skeleton, design system, TOOLS.md — with previews
> 6. **Lock in + verify** — Configuration block to CLAUDE.md, smoke test through `/new-project`, closing summary
>
> I'll explain *why* each step matters as we go, not just what I'm doing. If anything feels off, say so — we can back up or skip.

**AskUserQuestion gate:**

| Question | Options |
|----------|---------|
| "How thorough should I be?" | (a) **Full walkthrough** (recommended for first-time forks) — narrate every step, confirm every write / (b) **Express** — same writes but skip narration and lump confirmations |

If (b): same step list, same writes, fewer prompts. Default = (a).

---

### Step 1: Fork-state check (T2 — never re-run on configured fork)

```bash
grep -E "^- \`setup_completed\` = " CLAUDE.md 2>/dev/null
```

- **Match found**: print the T2 refusal copy and STOP.
- **No match**: print *"Fresh fork detected — proceeding to environment probe."* Continue to Step 2.

---

### Step 2: Environment detection (T4 — read-only)

**Narrate:** *"Now I'm going to take a look around your machine — what CLIs you have, which MCPs are configured, what pipeline tools are around. I do this because half the skills in this harness depend on external tools (Slack, GitHub, Google Workspace, etc.) and I'd rather find out now what's available than have you discover at 8am tomorrow that `/briefing` is missing a piece. Strictly read-only — just `which`, `--version`, `auth status`. Nothing gets installed. ~10 seconds."*

**Read install tier first** (so CCv4 probes are gated correctly):

```bash
SBOS_TIER=$(grep -E '^SBOS_TIER=' ~/.second-brain-os.env 2>/dev/null | head -1 | cut -d= -f2)
SBOS_TIER=${SBOS_TIER:-minimal}
```

Stash as `detection_report.install_tier`. Branch:
- `minimal` → SKIP the CCv4-toolchain probe block (bloks/tldr/fastedit). These are intentionally absent on a knowledge-worker fork. Render the "Optional coding-tier tools — Skipped, not missing" panel instead of an ❌ warning.
- `coding` → run the existing CCv4 probes. Missing binaries here are a real install failure.
- Unset → treat as `minimal`; soft note: *"No SBOS_TIER marker found — assuming minimal tier."*

**Run all probes in parallel** via a single Bash call. Capture stdout, stderr, exit codes.

**CLI probes:**
```bash
gws auth status 2>&1 | head -20             # GWS state + scopes
gh auth status 2>&1 | head -10              # GitHub
databricks --version 2>&1                   # Databricks CLI
sf --version 2>&1 | head -1                 # Salesforce CLI version
sf org list --json 2>&1 | head -20          # SF org auth state
which jq 2>&1                               # jq (installer + MCP config)
command -v rg 2>&1                          # ripgrep (opt-in; /find falls back to grep -r)
which node 2>&1; node --version 2>&1        # Node (local MCPs + .claude/hooks/*.mjs)
```

**CCv4-toolchain probes — coding tier ONLY:**
```bash
which bloks 2>&1; bloks --version 2>&1       # Ouros REPL — backs /research
which tldr 2>&1; tldr --version 2>&1         # tldr cache — used by tldr-read hook
which fastedit 2>&1; fastedit --version 2>&1 # FastEdit MCP — surgical AST edits
```

Store as `detection_report.ccv4_install_state`:
- tier=minimal → `skipped-by-design` (render "skipped, not missing" panel)
- tier=coding + all-present → ✅
- tier=coding + partial → ⚠️ (surface counts)
- tier=coding + none → ❌ install failed mid-run — strongly recommend (c) re-run installer

**MCP probes:**
```bash
jq '.mcpServers | keys[]' .mcp.json 2>&1
[[ -n "${GEMINI_API_KEY:-}" ]] && echo SET || echo UNSET
```

For each MCP in `.mcp.json.mcpServers`: probe the deferred-tools list (session-start system-reminders) for `mcp__<name>__*` tools — present → `✅ connected`; absent → `⏳ configured — needs /mcp authorize`. Stdio MCPs (e.g., gemini-vision) also need their env var set (`✅` if both set + tools present; `⚠️` if env var missing). Honesty rule: when unsure, write `ℹ️ configured — status unverified`.

**Workspace + persona state probes:**
```bash
for d in 0-Inbox 1-Projects 2-Coding 3-Resources 4-Archive; do
  test -d "workspace/$d" && echo "OK  $d" || echo "MISSING  $d"
done
for f in SOUL.md USER.md IDENTITY.md CLAUDE.md README.md TOOLS.md; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    git diff --quiet HEAD -- "$f" && echo "CLEAN  $f" || echo "MODIFIED  $f"
  else
    echo "UNTRACKED  $f"
  fi
done
```

**Render the detection panel** (CRITICAL — the transparency moment). Single text panel headed `🔍 Environment scan complete (install tier: <minimal|coding>)`. Sections, in order: **Optional coding-tier tools** (renders "Skipped, not missing — add later with `./scripts/install.sh --with-coding`" on minimal; lists `✅ bloks/tldr/fastedit` versions on coding), **CLIs** (✅/⚠️/❌ per CLI with version + auth state), **Pipeline tools** (jq + opt-in rg), **MCPs** (per .mcp.json — ✅ connected / ⏳ needs /mcp authorize / ⚠️ stdio env missing), **Workspace skeleton** (✅ existing dirs / ❌ missing dirs to be created in Step 5), **Persona files** (CLEAN/MODIFIED/UNTRACKED per file via git-diff), **Setup state** (fresh fork or setup_completed line found).

**Then `AskUserQuestion` gate:**

| Question | Options |
|----------|---------|
| "Proceed with this detection result?" | (a) **Proceed to identity collection** / (b) **Show me the full probe output** (print raw stdout/stderr per tool) / (c) **Fix something first** (abort cleanly so user can install/auth a missing tool, then re-run /bootstrap) |

**Special-handling — coding-tier failure ONLY** (`install_tier == coding` AND `ccv4_install_state == none`): BEFORE the standard gate, surface this extra prompt:

> ⚠️ Heads up: you ran `./scripts/install.sh --with-coding`, but `bloks`, `tldr`, and `fastedit` are all missing from your PATH. The CCv4 install must have failed mid-run. `/research`, `/autonomous`, and the FastEdit MCP will be dead until you fix it. Recommended: pick (c), re-run `./scripts/install.sh --with-coding` (idempotent), then re-run `/bootstrap`.

**Minimal-tier note:** if `install_tier == minimal`, NEVER surface a CCv4-missing warning. The "Skipped, not missing" panel is the whole conversation. Knowledge-worker forks never see a red flag for CCv4 absence.

If (b): print all raw probe output verbatim, then re-ask. If (c): print *"Fine — go install/auth what you need, then run /bootstrap again. No changes made."* and STOP.

#### Step 2.5 — Optional connector MCPs (W6 interactive opt-in)

After the user picks (a) Proceed, surface the optional-connector picker. Only fresh forks (no `setup_completed:` line) reach here — Sid's existing fork and any re-configured fork are gated by T2 in Step 1.

**Narrate:** *"Three MCPs ship out of the box (gemini-vision, exa, firecrawl). Three more are opt-in — pick the ones you actually use and I'll add them to `.mcp.json`. You'll authorize them with `/mcp` after bootstrap. No pick = no entry = no red error on first launch."*

**AskUserQuestion (multi-select):**

| Question | Options |
|----------|---------|
| "Which connectors do you use? (multi-select)" | (a) **Slack** — read/send messages, search channels, threads, canvases / (b) **Atlassian (Jira + Confluence)** — issues, pages, comments / (c) **Figma** — design files, dev mode, code connect / (d) **None of these** — skip |

For each selected option, append the canonical MCP entry to `.mcp.json` via a Python json.load/dump (preserves comments/order, no jq dep). **Defensive:** if `.mcp.json` is missing or malformed, write a minimal `{"mcpServers":{}}` shell first, then append.

**Canonical entries** — single source of truth lives in `.mcp.json` `_notes.opt_in_slack` / `_notes.opt_in_atlassian` / `_notes.opt_in_figma`. Read those at runtime; do NOT hardcode the JSON here (drift risk). Slack's entry MUST include `oauth.clientId` and `oauth.callbackPort` (Anthropic's public Slack app, dynamic-client-registration — a Slack workspace admin approves it once).

**Closing line after writes:** *"Added <list of selected connectors>. Run `/mcp` after bootstrap to authorize each — Atlassian/Figma do standard browser-OAuth; Slack needs the workspace-admin approval mentioned above."*

If (d) None: print *"No optional connectors added. Just gemini-vision + exa + firecrawl in .mcp.json (the three universals). Re-run /bootstrap or hand-edit .mcp.json later if you change your mind."* and continue.

---

### Step 3: Identity collection (AskUserQuestion-driven)

**Narrate:** *"Now the part that's about you. I need your name, email, GitHub handle, timezone — the basics. These get substituted into every persona file and written to the Configuration block of CLAUDE.md, which every skill reads. I've prefilled defaults from `git config` and `gh` where I could find them."*

**Detect defaults** in parallel: `git config user.email`, `git config user.name`, `date +%Z`, `gh api user --jq .login`.

**Ask in batched groups (3 fields per `AskUserQuestion` call):**

- Group 1 — `user.full_name` / `user.name` (short) / `user.email`
- Group 2 — `user.timezone` / `user.github` / `user.company`
- Group 3 — `user.email_signature` / `workspace.root` (default `workspace`)

Validate lightly: no spaces in github username; email contains `@`.

**Echo back the 8 fields, gate:** (a) **Confirm** / (b) **Edit one** / (c) **Restart Step 3**.

---

### Step 4: Design your assistant + teach it your voice

The heart of bootstrap. Two sub-steps — **4a** assistant persona (name/role/vibe/pronoun/emoji, *no default name*), **4b** writing voice.

#### Step 4a: Assistant persona

**Narrate (verbatim) — this is an affective moment, preserve the spirit:**

> Now let's design the assistant — *your* assistant. This is the entity you'll be talking to every morning, the one drafting your emails, taking your meeting notes, surfacing the projects you've been ignoring. It needs a name. It needs a tone. It needs to feel like *yours*, not like someone else's leftover.
>
> A few examples to spark ideas (you don't have to pick from this list):
>
> - **Atlas** — strategic, broad-perspective, holds the whole map
> - **Echo** — quiet, reflective, mirrors your thinking back at you
> - **Cortex** — analytical, fast, pattern-matching
> - **Sage** — wise, deliberate, asks the right questions
> - **Juno** — warm, attentive, like a thoughtful friend
> - **Pierre, Nova, Mira, Iris, Ren, Kai, Astra** — or anything you want
>
> Pick what feels right. You can always change it later.

**Escape hatch first** — before the collection batch, offer an out for users who've already hand-edited:

| Question | Options |
|----------|---------|
| "Ready to design your assistant?" | (a) **Yes, walk me through it** (default) / (b) **I've already hand-edited SOUL/IDENTITY/USER and want to keep them** — Step 5 skips ALL persona regen; we still write Configuration in Step 6 using values read from your existing files. |

If (b): read `assistant.name`, `assistant.role`, etc. from current `IDENTITY.md` / `SOUL.md`. Skip the collection batch and continue to Step 4b.

**Collection batch — one AskUserQuestion call with all five fields:**

- `assistant.name` — *"What do you want to call your assistant?"* (free text)
- `assistant.role` — *"Short role descriptor?"* (e.g., "Chief of Staff", "Research Companion", "Writing Partner")
- `assistant.vibe` — *"One-line vibe — how should it feel to talk to them?"*
- `assistant.pronoun` — *"Which pronoun?"* — (she / he / they / no-pronouns — use name only)
- `assistant.emoji` — *"Single emoji that represents them?"* (🎯, 📚, ⚙️, 🧠, 🪐, 🌿, 🦉, 🗺️, 🔭)

**Pronoun resolution rule:** `assistant.pronoun` flows into every downstream narration. Resolve `<pronoun>` placeholders in templates and in the echo-back text below. For `no-pronouns`, substitute the assistant's name everywhere a pronoun would naturally appear (e.g., "I'll refer to <name> by name" instead of "I'll refer to <pronoun> by name").

**After collection, echo back (this is THE affective moment — preserve verbatim):**

```
Got it. Meet your assistant:

  Name:    <assistant.name>  <assistant.emoji>
  Role:    <assistant.role>
  Vibe:    <assistant.vibe>
  Pronoun: <assistant.pronoun>

This is who you'll be talking to. From here on I'll refer to <pronoun-resolved> by name.
```

`AskUserQuestion`: *"Look right?"* — (a) **Yes, perfect** / (b) **Edit one field** / (c) **Restart Step 4a**.

#### Step 4b: Writing voice (single collapsed spec — preview-before-write gate is THE affective moment)

**T1 pre-check** — if `memory/writing-style.md` already exists with non-trivial content (file size > 500 bytes and not just a TODO skeleton), gate FIRST:

| Question | Options |
|----------|---------|
| "`memory/writing-style.md` already exists. What should I do?" | (a) **Keep as-is** (recommended) — skip Step 4b / (b) **Show me what's there** — print, then re-ask / (c) **Regenerate from scratch** — back up to `.previous`, then run the collection flow |

Default = (a). If (c), `cp memory/writing-style.md memory/writing-style.md.previous` before proceeding.

**Narrate (verbatim) — only if absent OR user picked (c):**

> One more piece — *your* writing voice. Down the line, <assistant.name> is going to draft emails for you, write status updates that sound like you, summarize meetings the way you'd summarize them. To do that well, I need a sense of how you actually write. Not a vague "professional and concise" — actual signal: phrases you use, structure you prefer, things you'd never write.

**Single AskUserQuestion (collapsed from three branches into one):**

| Question | Options |
|----------|---------|
| "How should <assistant.name> learn your writing voice?" | (a) **Paste a sample inline** (recommended) — 1-3 paragraphs of something you wrote / (b) **Point me at a file path** — I'll read up to ~200 lines / (c) **Just ask me descriptive questions** — no sample, ~2 minutes / (d) **Skip for now** — drop a TODO starter template |

**Common path — collect → preview → gate → write.** Input source auto-detected:

1. **Collect input** based on choice:
   - (a) → wait for the user's next turn (the paste). When received, proceed.
   - (b) → ask for path, validate `test -f "$PATH"`. Fall back to (a) if missing. `Read` up to 200 lines.
   - (c) → ask three descriptive batches (tone: formal/casual, terse/expansive, direct/hedged; surface: emoji rules, signature line, sentence quirks; NEVERs: phrases-to-never-write, format rules).
   - (d) → write a TODO starter template to `memory/writing-style.md` and skip the rest of this step. *(Sections: Voice character / Structure preferences / Word choice quirks / Emoji rules / Hard NEVERs / Signature / Sample phrases / Sentence patterns — each as a single TODO line.)*

2. **Synthesize a draft profile** with these sections (skip any section the input doesn't cover — never fabricate):
   - **Voice character** — one paragraph distilled from input
   - **Structure preferences** — paragraph length, list/prose ratio, hierarchy
   - **Word choice quirks** — distinctive phrases used; hedges; phrases explicitly avoided
   - **Emoji rules** — explicit from (c), or inferred from (a)/(b)
   - **Hard NEVERs** — only if explicit
   - **Signature** — only if present in sample or provided
   - **Source** — `inline paste of N words` / `file: <path>, N lines` / `descriptive answers, no sample`

3. **PREVIEW the synthesized profile to the user before writing.** This preview-before-write gate is THE affective moment of Step 4b — never skip it. After the preview, `AskUserQuestion`:

| Question | Options |
|----------|---------|
| "Here's the writing voice profile I'd save. Look right?" | (a) **Yes, save it** → write to `memory/writing-style.md` / (b) **Give me a second sample first** — re-ask for another paste/path, merge / (c) **Edit one section** / (d) **Save it but I'll hand-edit later** |

4. **Write** to `memory/writing-style.md`. Surface: *"Saved to `memory/writing-style.md`. <assistant.name> reads this whenever drafting in your voice. Edit any time."*

---

### Step 5: Apply — persona files + workspace skeleton + design + TOOLS.md (T1 — never overwrite user-edited files)

Three sub-blocks; narrate before each.

#### 5a: Persona file regeneration (T1 invariant — per-file git-diff guard)

**Narrate:** *"Time to make your assistant real on disk. I'll take the templates at `<workspace.root>/3-Resources/templates/persona/` and substitute in everything you've told me — your name, your assistant's name, the vibe, the role, the pronoun — to regenerate `SOUL.md`, `IDENTITY.md`, `USER.md`, and `README.md` at the repo root. Before each overwrite I check `git diff HEAD -- <file>`; if you've hand-edited, I default to skipping."*

For each file in scope (or skip ALL if Step 4a (b) was chosen):

```bash
git diff --quiet HEAD -- <file> && STATE=CLEAN || STATE=MODIFIED
```

- **CLEAN** → substitute placeholders (one `sed` call resolving `<user.*>`, `<assistant.*>` including `<assistant.pronoun>`, `<workspace.root>`, and any legacy pronoun placeholders) and write. *"✅ Wrote `<file>`."*
- **MODIFIED** (T1 triggers) → `AskUserQuestion`: (a) **Skip — preserve edits** (recommended) / (b) **Show diff** / (c) **Overwrite** / (d) **Save regenerated copy to `<file>.bootstrap-suggested`**. Default = (a).

After all files processed: *"Persona files: wrote `<list>`, skipped `<list>`."*

#### 5b: Workspace skeleton (idempotent — T4 safe)

**Narrate:** *"Now the workspace folder skeleton — the PARA structure that every project-lifecycle skill reads from. `mkdir -p` only — never destructive."*

```bash
if [[ -d workspace && ! -d "${WORKSPACE_ROOT}" ]]; then
  mv workspace "${WORKSPACE_ROOT}"
fi
mkdir -p "${WORKSPACE_ROOT}"/{0-Inbox,1-Projects,2-Coding,3-Resources/{templates,research,reference,meetings,contacts,design-systems,onboarding},4-Archive}
```

Surface which subdirs were newly created vs already existed.

#### 5c: Design system pick + TOOLS.md generation (T1 invariant on TOOLS.md)

**Design pick:** AskUserQuestion category-first (AI & LLM / Developer Tools / Productivity & SaaS / More). After pick, run `cp <selected-brand>/DESIGN.md DESIGN.md` (back up existing to `.DESIGN.md.previous`). Meta-options: `(default)`, `(keep current)`, `(magenta placeholder)`.

**TOOLS.md generation:** build content from `detection_report` — every ✅/⏳/⚪/⚠️/❌ flag traces to a real probe. **T1 check** on TOOLS.md before writing:

```bash
git diff --quiet HEAD -- TOOLS.md && echo CLEAN || echo MODIFIED
```

**Preview the full generated content, then gate:**

| Question | Options |
|----------|---------|
| "Here's the TOOLS.md I'd write. What now?" | (a) **Write it** (downgrades to (b) automatically if T1 is MODIFIED) / (b) **Write to `TOOLS.md.bootstrap-suggested`** — side-file / (c) **Skip entirely** — keep current |

---

### Step 6: Lock in + verify (T3 — never auto-commit)

Two sub-blocks: write the Configuration block, then run a smoke test.

#### 6a: Configuration write to CLAUDE.md

**Narrate:** *"Last write. The Configuration block in `CLAUDE.md` is the single source of truth — every skill reads `<user.name>`, `<assistant.name>`, `<assistant.pronoun>`, `<workspace.root>` from it."*

Edit the Configuration section: write the 13 tokens (`user.*` × 7, `assistant.*` × 5 *including pronoun*, `workspace.root`) and append `setup_completed: <YYYY-MM-DD>` to the `### lifecycle` block (the T2 re-run gate).

Configuration block template (the exact lines that go into CLAUDE.md):

```
### user
- `user.name` = `<value>`
- `user.full_name` = `<value>`
- `user.email` = `<value>`
- `user.timezone` = `<value>`
- `user.github` = `<value>`
- `user.email_signature` = `<value>`
- `user.company` = `<value>`

### assistant
- `assistant.name` = `<value>`
- `assistant.role` = `<value>`
- `assistant.vibe` = `<value>`
- `assistant.pronoun` = `<value>`
- `assistant.emoji` = `<value>`

### workspace
- `workspace.root` = `<value>`

### lifecycle
- `setup_completed` = `<YYYY-MM-DD>`
```

**Show diff, then `AskUserQuestion`:** (a) **Write** / (b) **Show diff again** / (c) **Skip — abort** (blocks smoke test). Append a daily-log entry to `memory/<YYYY-MM-DD>.md` with the config snapshot.

#### 6b: Smoke test via `/new-project`

**Narrate:** *"Running the smoke test — invoking `/new-project` with a throwaway name to verify placeholder substitution. If it fails (literal `<user.name>` still in scaffolded files), I leave the artifact for debugging."*

Invoke `/new-project` (type: `design`, name: `bootstrap-smoke-test-<HHMMSS>`). Verify:
1. Folder exists under `<workspace.root>/<workspace.projects>/`
2. `CLAUDE.md` inside contains the resolved `<user.name>` value
3. `memory.md` has today's date

- **PASS** → `rm -rf <smoke-test-path>`. *"✅ Smoke test passed. Placeholder resolution working end-to-end."*
- **FAIL** → leave artifact for debugging. *"⚠️ Smoke test FAILED — inspect `<path>`. Configuration may need manual review."*

#### 6c: Closing summary — what to do in the next 10 minutes + files changed + commit cmd (T3)

The closing message has two sections — keep it short. Day 2+ rhythms live in `<workspace.root>/3-Resources/onboarding/day-2-plus.md` (read at leisure).

**Section A — What to do in the next 10 minutes:**

```
Day 1 — start here (in this order):

1. Authorize MCPs flagged ⏳ in the env panel
     Run /mcp → walk through the OAuth flow for each.
     Skip if Section 2 of the env panel was empty.

2. (Optional) Enable per-feature API keys
     The installer wrote .env.example with 5 optional keys (EXA, NIA, HF,
     ATLASSIAN, ANTHROPIC). Claude Code itself uses OAuth — none required.
     cp .env.example .env  &&  edit only what you need.

3. Fill in USER.md (and writing-style.md if you skipped Step 4b)
     Step 5a left <TBD> placeholders for team / priority signals / Slack
     channels. /briefing reads these — without them the brief still works
     but surfaces less. ~5 minutes.

4. Try /briefing
     First run will be sparse on a fresh fork (empty contacts, half-full
     USER.md). The point is to see the shape and confirm MCPs return data.

5. Scaffold your first project
     /new-project <name>  → creates the PARA folder with CLAUDE.md + memory.md.
```

**Section B — Files changed + commit (T3 — surface as text, NEVER `git add`):**

```
Files written or modified:
- SOUL.md, IDENTITY.md, USER.md, README.md — regenerated from templates (or kept as-is — your edits preserved)
- TOOLS.md — regenerated from live probes (or saved to TOOLS.md.bootstrap-suggested if T1 flagged)
- CLAUDE.md — Configuration section tokenized
- DESIGN.md — swapped to <brand> (.DESIGN.md.previous backed up)
- memory/writing-style.md — <created from sample / descriptive / starter TODO>
- <workspace.root>/<para subdirs> — created (or already-existed)
- memory/<YYYY-MM-DD>.md — new daily log entry

Your assistant: <assistant.name> <assistant.emoji> (<assistant.role>) — voice: <one-line vibe>
Active design: <brand> — swap anytime with /use-design <brand>

/bootstrap did NOT auto-commit (T3). Review and commit when ready:

  git status
  git diff
  git add SOUL.md IDENTITY.md USER.md README.md TOOLS.md CLAUDE.md DESIGN.md memory/<YYYY-MM-DD>.md memory/writing-style.md <workspace.root>/
  git commit -m "fork bootstrap: configure as <user.name> / <assistant.name> / <brand>"

For Day 2+ natural rhythms (the /find, /contact-log, /thinking-partner, /prune-projects loop), see:
  <workspace.root>/3-Resources/onboarding/day-2-plus.md

To re-run /bootstrap later: delete the `setup_completed: <date>` line in CLAUDE.md,
then invoke /bootstrap again.

That's the lay of the land. Where do you want to start?
```

---

## Failure modes (consolidated — 10 rows, T-invariants live in canonical section above)

| Symptom | Cause | Fix |
|---------|-------|-----|
| Skill runs on already-configured fork | T2 detection failed | Step 1 MUST grep for `setup_completed:` and refuse if found |
| Persona files overwritten despite user edits | T1 detection mechanism not concrete | Step 5a uses `git diff --quiet HEAD -- <file>` — concrete + repeatable. Default to skip on MODIFIED. |
| Skill auto-committed | T3 violation | NEVER `git add` or `git commit` — Step 6c surfaces commands as text only. |
| Skill tried to install gws/gh/binaries | T4 violation | Step 2 is READ-ONLY probes; Step 6c surfaces install hints — never runs them. |
| Bootstrap surfaced a CCv4-missing warning on a minimal-tier fork | W2c regression — tier branch not honored | Step 2 MUST read SBOS_TIER first and skip CCv4 probes when `minimal`. The "skipped, not missing" panel replaces the warning. |
| Smoke test passed but new project still has placeholder | Step 6b ran before Step 6a | Step order is FIXED: 6a (Configuration write) → 6b (smoke test). |
| Workspace skeleton clobbered existing content | Step 5b was destructive | `mkdir -p` only — never `rm -rf`. |
| MCP probe failed and skill aborted | Probes treated as fatal | Probes are informational (`2>&1 \|\| true`). Surface ⚠️ and continue. |
| TOOLS.md generated with wrong status flags | Fabricated ⏳/✅ for unconnected MCPs | Status MUST trace to a real Step 2 probe. Honesty rule: `ℹ️ unverified` when unsure. |
| Writing-voice profile fabricated phrases the user never said | Step 4b synthesis hallucinated | Voice synthesis only writes what's in the input. The preview-before-write gate is the catch. |

## Boundaries

- **NEVER auto-commit** (T3).
- **NEVER install tools** (T4) — surface hints, don't run them.
- **NEVER overwrite user-edited persona files without explicit confirmation** (T1) — default = skip.
- **NEVER re-run on already-configured fork** without `setup_completed:` being deleted first (T2).
- **NEVER alter `2-Coding/` repos.** Independent gits.
- **NEVER write to `memory/`** other than today's daily log. Append-only.
- **NEVER call Exa / WebSearch / WebFetch.** Bootstrap is local.
- **NEVER fabricate detection results.** Every ✅/⏳/⚪/⚠️/❌ traces to a real Step 2 probe; when unsure, `ℹ️ unverified`.
- **NEVER fabricate writing-voice content.** Only what's in the input sample or descriptive answers.
- **NEVER default the assistant to "Beru"** or any name from the original repo. Step 4a always collects a fresh name (or honors the user's hand-edited persona files).
- **NEVER skip the narration.** Each step's "Narrate" block is user-visible text, not internal thinking.

## Re-run mechanism

Re-run gate = `setup_completed: <date>` line in CLAUDE.md's `### lifecycle` section. Presence = configured (refuse, point at `/update-config`). Absence = fresh fork (proceed).

To re-run: edit CLAUDE.md, delete the `setup_completed` line, invoke `/bootstrap`. Steps 2, 5b are idempotent. Step 4b protects `memory/writing-style.md` via T1-style pre-check. Step 5a protects user-edited persona files via T1. Step 6a overwrites the Configuration section with fresh values; Step 6b's smoke test runs again.

For lighter partial edits (just changing your name, swapping the brand, updating one persona file) — use `/update-config` instead.
