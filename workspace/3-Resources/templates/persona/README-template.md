# Second-Brain OS

A personal AI workspace that runs on your computer. You talk to it naturally — it handles morning briefings, contacts, projects, meeting prep, research recall, design output, and more.

```
You:  "morning, what's on my plate today?"
You:  "tell me about Sarah"
You:  "I just spoke with Sarah about the launch"
You:  "do I have any notes on Q3 planning?"
You:  "let's start a new project for the product launch"
```

All routed automatically to the right pre-built workflow. No commands to memorize.

---

## What is this?

A workspace skeleton that turns Claude Code into your personal chief-of-staff (or research companion, engineering co-pilot, sales-ops assistant — you pick the persona during setup). You configure it once with your identity, then talk to the assistant normally. It routes your intent to the right pre-built workflow.

It's NOT a SaaS product, hosted service, or app. It's a folder on your Mac that Claude Code reads from. Your data never leaves your machine unless YOU send it somewhere (e.g., when you ask it to publish a Slack message, you're authorizing that one send).

---

## How it works

Three pieces fit together:

### 1. **Skills** — pre-built workflows in `.claude/skills/`

A skill is just a markdown file with frontmatter that tells Claude when to use it. The bundle ships 45 of them: `briefing` runs morning briefs, `contact` looks up people, `new-project` scaffolds projects, `design-saas-landing` renders HTML mockups, and so on. When you type *"morning, what's on my plate?"*, Claude reads every skill's description and picks the best match. You can also invoke a skill explicitly with `/briefing`, `/contact <name>`, etc.

**The one skill you'll always run first is `/bootstrap`.** It's the interactive setup that personalizes the OS to you — collects your name, role, workspace paths, persona name, design brand, then writes that into the Configuration section of `CLAUDE.md`. Everything else assumes `/bootstrap` has been run.

### 2. **A PARA workspace** at `<workspace.root>/`

PARA is a folder convention (Projects / Areas / Resources / Archive) borrowed from Tiago Forte. In this OS it means a fixed 5-folder layout under one root directory — that's where YOUR data lives (briefings, contacts, project notes, research, design files). The skills know how to navigate it because the folder names are referenced symbolically (`<workspace.projects>`, `<workspace.resources>`, etc.) in Configuration. See "[The PARA workspace](#the-para-workspace)" below for what each folder is for and why.

### 3. **Configuration tokens** in `CLAUDE.md`

One section in root `CLAUDE.md` holds your identity + paths as symbolic tokens (`<user.name>`, `<assistant.name>`, `<workspace.root>`, etc.). Skills resolve them at runtime. This is what makes the bundle portable — fork it, run `/bootstrap`, the tokens get filled in with YOUR values, and every skill adapts. No code changes needed.

### Two-stage setup — why there are two install steps

You may notice the install instructions below have a **shell command** (`./scripts/install.sh`) AND a **Claude Code command** (`/bootstrap`). That's intentional:

- **`./scripts/install.sh`** (shell, OPTIONAL) — installs OS-level tooling needed only by the power-user skills (`/research`, `/autonomous`, `/premortem`, `/review`). Skip it if you only want the chief-of-staff + design skills.
- **`/bootstrap`** (inside Claude Code, REQUIRED) — personalizes the OS to you. This is the meaningful setup step.

`/bootstrap` can't run in your shell — it's a Claude Code slash command, only available inside a Claude session. So the sequence is always: get to a Claude session in the right folder, then run `/bootstrap` from there.

---

## Install

The thing you're trying to reach is `/bootstrap` inside Claude Code. Everything before that is plumbing.

### Prerequisites (all paths)

- macOS 11+ (WSL2/Linux compatibility deferred)
- [Claude Code](https://claude.com/claude-code) installed
- `git` on PATH (`xcode-select --install` if missing)
- Internet access

### Path A — Minimal (~5 min) — chief-of-staff + design only

For most fork users. Skip the shell installer entirely.

```bash
git clone https://github.com/the-sid-dani/second-brain-os ~/Desktop/second-brain-os
cd ~/Desktop/second-brain-os
claude
```

Inside the Claude Code session that opens, type `/bootstrap`. ~10 min interactive walkthrough (identity, persona, design brand, workspace folders).

You're done. Try *"morning, what's on my plate today?"* or *"let's start a new project for X"* to confirm.

### Path B — Lite CCv4 (~10-15 min) — adds `/research`, `/autonomous`, knowledge graph

If you want the power-user skills, install the supporting toolchain BEFORE opening Claude (hooks and binaries need to be in place at session-start):

```bash
git clone https://github.com/the-sid-dani/second-brain-os ~/Desktop/second-brain-os
cd ~/Desktop/second-brain-os
./scripts/install.sh --no-fastedit-model
claude
```

The installer adds Rust, uv, bloks, tldr-cli, Python deps for the Ouros harness, plus ripgrep/ffmpeg/yt-dlp. The `--no-fastedit-model` flag skips the 3 GB MLX merge model (you can add it later by re-running without the flag).

**API keys**: the installer prompts for ANTHROPIC, EXA, NIA, HF, ATLASSIAN. Pass `--skip-api-keys` to write empty `.env` stubs you fill in later.

Then inside Claude: `/bootstrap` for identity setup, then `/mcp` to OAuth into the HTTP MCPs (Slack, Atlassian, Figma, Exa) — standard browser flow, no app registration needed.

### Path C — Full (~20-40 min) — adds FastEdit MCP

Same as Lite but includes the FastEdit MLX merge model (~3 GB) for AST-aware code edits with ~45% fewer tokens than diff-based edits:

```bash
git clone https://github.com/the-sid-dani/second-brain-os ~/Desktop/second-brain-os
cd ~/Desktop/second-brain-os
./scripts/install.sh
claude
```

On Apple Silicon, FastEdit runs locally via MLX. On Intel Macs, the MLX backend won't be hardware-accelerated.

Then inside Claude: `/bootstrap`, then `/mcp`.

### Tier comparison

| Path | What you get | Disk | Wall time |
|---|---|---|---|
| **A: Minimal** | 36 chief-of-staff + design skills, persona templates, MCP research (Slack/Atlassian/Figma via OAuth) | ~5 MB | ~5 min |
| **B: Lite CCv4** | Above + `/research`, `/autonomous`, `/premortem`, `/review`, bloks, tldr, Ouros REPL harness | ~500 MB | ~10–15 min |
| **C: Full** | Above + FastEdit MCP (AST-aware code edits) | ~5 GB | ~20–40 min |

You can upgrade later — re-run `./scripts/install.sh` and it picks up where you left off (idempotent).

### Why `cd` before `claude`

Claude Code loads skills + hooks by scanning the directory it was launched from. You must `cd` into the cloned folder **before** running `claude` — otherwise the session won't see `/bootstrap` or the other harness skills. If you forget, type `exit`, `cd` into the folder, run `claude` again.

### Re-running, upgrading, downgrading

```bash
./scripts/install.sh --reconfigure        # re-prompt API keys (rotate)
./scripts/install.sh --no-fastedit-model  # skip the 3 GB model
./scripts/install.sh --skip-api-keys      # write empty .env stubs
./scripts/install.sh --verbose            # stream sub-command output
./scripts/install.sh --help               # full flag list
```

See `INSTALL.md` for step-by-step manual install (use if the installer fails mid-way or you maintain a non-standard toolchain).

### Alternative — chat through it with Claude

If you'd rather have a conversation than run terminal commands, here's a prompt to paste into any Claude Code session. **Note**: Claude can clone the repo and run `install.sh` for you, but it can't invoke `/bootstrap` — that's a slash command bound to the new session you'll open after install. This is a fundamental Claude Code constraint (skills load at session-start), not a limitation of the prompt.

1. Open Terminal and run `claude` to start any Claude Code session.

2. Paste this into Claude Code and hit Enter:

   ```
   Hi! I want to install the second-brain-os — a personal AI workspace.
   The public template is at: https://github.com/the-sid-dani/second-brain-os

   Please help me set this up. Walk me through these steps:

   1. Check what I have installed by running `git --version` and `claude --version`.
      If anything's missing, tell me how to install it on a Mac and pause until I confirm.

   2. Ask me which install tier I want — Minimal, Lite CCv4, or Full. Briefly
      explain the trade-offs (chief-of-staff + design only vs. + /research and
      /autonomous vs. + FastEdit MCP) and the disk/time cost of each tier.

   3. Ask me where I want to clone the repo (default: ~/Desktop/second-brain-os).
      Clone it there for me, then cd into it.

   4. If I picked Lite CCv4 or Full, run the installer for me:
        - Lite CCv4:  `./scripts/install.sh --no-fastedit-model --skip-api-keys`
        - Full:        `./scripts/install.sh --skip-api-keys`

      The `--skip-api-keys` flag writes empty `.env` stubs instead of prompting
      interactively (you can't enter keys for me anyway). Tell me afterward
      that I need to open `.env` and fill in the 5 keys (ANTHROPIC, EXA, NIA,
      HF, ATLASSIAN) before running CCv4 skills like /research or /autonomous.

      Heads up: install.sh may ask for my sudo password ONCE (if Homebrew isn't
      installed yet) and will run many sub-commands (brew, npm, cargo, pip, uv).
      Claude Code may prompt me to approve each Bash command. That's expected.

   5. If I picked Minimal, skip step 4 — just hand off to step 6.

   6. **Important honest handoff**: tell me you can't invoke /bootstrap from this
      session because Claude Code loads skills at session-start. Tell me to:
        - type `exit` to quit this Claude Code session
        - re-open Claude Code from the cloned folder (the path you just cloned into)
        - then type `/bootstrap` in that new session
        - and if I picked Lite CCv4 or Full, also run `/mcp` to OAuth Slack/Figma/Atlassian

      Don't pretend to run /bootstrap. The skill literally isn't available here.

   Treat me like a smart non-technical person — explain what each step does
   briefly, don't over-explain, and ask before doing anything destructive.
   ```

3. **Follow Claude's instructions** to clone the repo and (optionally) run the installer. When it's done, Claude will tell you to quit and re-open Claude Code in the cloned folder.

4. **Re-open Claude Code** in the cloned folder (Terminal: `cd ~/Desktop/second-brain-os && claude`), then type `/bootstrap`. If you picked Lite CCv4 or Full, also run `/mcp` to authorize Slack, Figma, and Atlassian.

5. **Fill in `.env`** if you used `--skip-api-keys` — open it in your editor and paste each key. The file has comments pointing at where to get each one.

---

## The PARA workspace

When `/bootstrap` runs, it creates a folder tree at `<workspace.root>/` (default: `workspace/`). This is where YOUR content lives — projects, contacts, briefings, research, design files. The skills know how to navigate it.

### Why these folders, in this layout

PARA is Tiago Forte's framework (Projects / Areas / Resources / Archive) — see his book *Building a Second Brain* or Wikipedia for the generic theory. **In this OS specifically**, PARA means a fixed 5-folder layout:

| Folder | What goes in it | Why it exists |
|---|---|---|
| `0-Inbox/` | Ad-hoc capture — anything not yet decided where it belongs | The friction-free landing zone. Stuff comes in here when you don't know if it's a project, a reference, or trash yet. `/inbox-process` triages it periodically (e.g., a Friday habit). |
| `1-Projects/` | Active projects — one folder per project | Time-bounded things with a defined outcome. Each gets its own `CLAUDE.md` + `memory.md`. Status frontmatter (`active`/`done`/`stale`) drives `/prune-projects` and `/archive-project`. |
| `2-Coding/` | Code repos — one folder per repo | Each its own git repo, gitignored from outer git so dev work stays isolated. The one allowed INDEX file lives at `<workspace.resources>/code-projects.md` (auto-created by `/new-project`) because gitignored repos can't be discovered by frontmatter-grep. |
| `3-Resources/` | Inputs AND outputs colocated by type — templates, contacts, meetings, briefings, research, design-systems | The "library + filing cabinet" — reference material you didn't create + generated outputs (briefings, organization reports). Subfolders are domain-typed (`meetings/`, `briefings/`, `contacts/`, etc.) so outputs sit next to their inputs. |
| `4-Archive/` | Completed or stale work | The move-don't-delete graveyard. Old projects keep their `memory.md` so decision history survives. `/archive-project` moves things here and flips status frontmatter. |

The folder names are not arbitrary — they're referenced symbolically across every skill as Configuration tokens (`<workspace.projects>` resolves to `1-Projects/`, etc. — see `CLAUDE.md` Configuration section). If you fork this and rename them, edit the Configuration section to match; the skills will adapt.

**Areas was deliberately cut** from the original 5-letter PARA. Ongoing responsibilities live in `3-Resources/` instead of a separate Areas folder. One less folder to maintain.

### What `/bootstrap` does NOT touch

`/bootstrap` only creates the EMPTY folder skeleton + scaffolds the templates. It never writes content into `1-Projects/` (those come from `/new-project`) or `3-Resources/briefings/` (those come from `/briefing`). The skills own the content; `/bootstrap` owns the structure.

---

## What you can ask it to do

You don't have to memorize slash commands. Claude reads your prompt and the description of every installed skill, then picks the best match.

| You say | Auto-routes to |
|---|---|
| "morning, what's on my plate today?" | `/briefing` |
| "do I have research on prompt caching?" | `/find` |
| "what did I save about prompt caching?" | `/find` |
| "tell me about Alex" | `/contact` |
| "what's my context with Sarah again?" | `/contact` |
| "I just spoke with Alex about the launch" | `/contact-log` |
| "let's start a new project for Q3 planning" | `/new-project` |
| "spin up a repo for a new MCP server" | `/new-project` (code-repo branch) |
| "I'm done with the launch project" | `/archive-project` |
| "what's stale right now?" | `/prune-projects` |
| "make me a landing page for the launch" | `/design-saas-landing` |
| "draft a deck about the AI strategy" | `/design-simple-deck` |
| "build a dashboard mockup" | `/design-dashboard` |
| "be a thinking partner — I'm stuck on X" | `/thinking-partner` |
| "save this article for later" | `/save-resource` |
| "process my inbox" | `/inbox-process` |
| "how does X work in this OS?" | `/os-guide` |

You can also type `/skill-name` directly if you know it — both work.

---

## Project map

```
second-brain-os/
├── README.md              ← you are here
├── CLAUDE.md              ← project instructions + Configuration section (your identity + paths)
├── SOUL.md                ← <assistant.name>'s persona, voice, boundaries
├── USER.md                ← <user.name>'s profile, role, preferences
├── IDENTITY.md            ← <assistant.name>'s name, version, origin
├── TOOLS.md               ← tool inventory (regenerated by /bootstrap from live probes)
├── DESIGN.md              ← active design system (swap with /use-design <brand>)
├── EXAMPLE-CONFIG.md      ← worked example of the Configuration section
├── agent-config.json      ← runtime config
├── .mcp.json              ← MCP server registration
├── .env.example           ← API key stub
├── CHANGELOG.md           ← release notes
│
├── memory/                ← curated long-form memory (git-tracked)
│   └── YYYY-MM-DD.md      ← append-only daily logs (you write these)
│
│   (parallel: ~/.claude/projects/.../memory/MEMORY.md — auto-managed, per-machine, NOT in git)
│
├── <workspace.root>/      ← your PARA workspace (gitignored at 2-Coding/)
│   ├── 0-Inbox/
│   ├── 1-Projects/        ← each project: CLAUDE.md + memory.md + status frontmatter
│   ├── 2-Coding/          ← code repos (gitignored)
│   ├── 3-Resources/
│   │   ├── templates/                ← project + persona templates
│   │   ├── contacts/                 ← per-person profiles (schema in README.md)
│   │   ├── meetings/                 ← raw transcripts, recordings
│   │   ├── briefings/                ← morning briefings (assistant output)
│   │   ├── meeting-prep/             ← per-meeting prep notes (assistant output)
│   │   ├── organization-reports/     ← workspace cleanup / audit reports
│   │   ├── research/                 ← user-saved research
│   │   ├── reference/                ← user-saved reference material
│   │   └── design-systems/           ← 72 brand presets
│   └── 4-Archive/
│
└── .claude/
    ├── skills/            ← skills (chief-of-staff + design + ContinuousClaude V4.7 pipeline)
    ├── hooks/             ← intent-detector + ContinuousClaude V4.7 hooks (status, pre-compact, etc.)
    ├── tools/             ← ContinuousClaude V4.7 Python tools (ouros_harness, exa_search, nia_docs)
    ├── commands/          ← /use-design slash command
    ├── mcp-servers/       ← local gemini-vision MCP
    ├── settings.json      ← hook registration
    └── settings.local.json ← per-machine permissions (gitignored)
```

---

## Configuration — one section, all tokens

All identity + path values live in **one place** — the `## Configuration` section of `CLAUDE.md`. Skills read these tokens (`<user.name>`, `<workspace.root>`, etc.) symbolically and resolve them at runtime.

| Token | Purpose |
|---|---|
| `user.name` | Short name — "Morning Alex!", default stakeholder for new projects |
| `user.full_name` | Display name in formal docs |
| `user.email` | Email signature, calendar invites |
| `user.github` | Used by `/new-project` code-repo branch for `gh repo create` |
| `user.timezone` | Briefing date math, calendar formatting |
| `user.email_signature` | Block appended to emails the assistant drafts |
| `user.company` | Used in formal documents |
| `assistant.name` | Persona name — `<agent>` by default, customize to anything (Atlas, Echo, Sage, etc.) |
| `assistant.role` | "Chief of Staff" / "Research Companion" / "Engineering Co-Pilot" |
| `assistant.vibe` | One-line vibe descriptor for SOUL.md voice cues |
| `assistant.emoji` | Optional emoji for the persona |
| `workspace.root` | Default `workspace`; rename to `brain`, `<name>-workspace`, etc. |
| `workspace.inbox / projects / coding / resources / archive` | Subfolder names — defaults are 0-Inbox, 1-Projects, etc. |
| `setup_completed` | Date `/bootstrap` ran (presence = configured; absence = fresh fork) |

`/bootstrap` fills these in interactively. See `EXAMPLE-CONFIG.md` for what a completed Configuration looks like.

---

## Update Rules — "What goes where, when"

### Identity / persona files (root)

| File | When to update |
|------|----------------|
| `SOUL.md` | <assistant.name>'s voice, boundaries, or "how to be helpful" rules change |
| `USER.md` | <user.name>'s role, team, preferences shift. Always convert relative dates to absolute |
| `IDENTITY.md` | Version bumps, name changes. Rare |
| `CLAUDE.md` | Project-specific context only (output paths, briefing rules, Configuration tokens). Never restate SOUL/USER content |
| `TOOLS.md` | When the toolchain changes (new MCPs, new skills, CLI auth state shifts) |

### Memory — dual-folder model

Two memory folders, distinct roles. Both load at session start.

**Folder A — `~/.claude/projects/.../memory/`** (auto-managed by Claude Code)
- Claude Code writes here when it learns a live preference, fact, or rule
- Indexed by `MEMORY.md` (uppercase)
- Per-machine; NOT in git

**Folder B — `memory/`** (in git, curated by <assistant.name> + <user.name>)
- `memory/YYYY-MM-DD.md` — append-only daily log
- `memory/memory.md` (lowercase) — index of project memory contents (optional)
- `memory/writing-style.md` — <user.name>'s writing style profile (optional)
- `memory/learned-preferences.md` — durable preferences (optional)

**Save rule:** live preference → Folder A. Daily journal entry or curated long-form → Folder B. Never create a third memory location.

### Workspace (`<workspace.root>/`)

- New project (planning, strategy, content, research)? → `/new-project` scaffolds at `<workspace.root>/<workspace.projects>/YYYY-MM-slug/`
- New code repo? → `/new-project`, choose `code-repo` as project-type. Creates at `<workspace.root>/<workspace.coding>/<name>/`. Auto-appends to a `code-projects.md` index (which the skill creates on first invocation — fresh forks don't ship one)
- Reference doc, template, meeting prep, research dump? → `<workspace.root>/<workspace.resources>/<topic>/`
- Ad-hoc / undecided capture? → `<workspace.root>/<workspace.inbox>/`
- Project complete? → `/archive-project` moves it to `<workspace.archive>/` and flips status frontmatter
- Stale projects need review? → `/prune-projects` (Friday-batch staleness review)

### Outputs

<assistant.name> writes briefings, meeting-prep, and organization-reports into dedicated subdirs of Resources (alongside `meetings/` raw transcripts — synthesis next to source). Naming:
- `<workspace.root>/<workspace.resources>/briefings/morning-briefing-YYYY-MM-DD.md`
- `<workspace.root>/<workspace.resources>/meeting-prep/YYYY-MM-DD-<who-or-what>.md`
- `<workspace.root>/<workspace.resources>/organization-reports/YYYY-MM-DD-<topic>.md`

Never write outputs at the workspace root.

### What does NOT belong at root

- Project-specific drafts → `<workspace.root>/<workspace.projects>/<project>/`
- One-off scripts → `<workspace.root>/<workspace.archive>/<context>/` or a code repo
- Reference data (CSVs, employee directories) → `<workspace.root>/<workspace.resources>/reference/`
- Junk (`.DS_Store`, zips, log dumps) → delete

---

## What's included

**Skills (45 total).**

| Category | Skills |
|---|---|
| Chief-of-staff (everyday workflows) | `archive-project`, `briefing`, `budget-tracker`, `contact`, `contact-log`, `desktop-organizer`, `find`, `inbox-process`, `new-project`, `os-guide`, `prune-projects`, `save-resource`, `sync-indexes`, `thinking-partner` |
| Setup & meta | `bootstrap`, `skill-creator` |
| ContinuousClaude V4.7 pipeline (9) | `autonomous`, `autonomous-research`, `bootup`, `create-handoff`, `premortem`, `research`, `resume-handoff`, `review`, `upgrade-harness` |
| Research | `company-research`, `people-research` |
| Project tracking | `confluence-publish-markdown`, `jira-decompose-epic`, `scaffold-engineering-project` |
| Design (14 workhorse skills) | `design-saas-landing`, `design-simple-deck`, `design-dashboard`, `design-web-prototype`, `design-blog-post`, `design-meeting-notes`, `design-pm-spec`, `design-docs-page`, `design-pricing-page`, `design-team-okrs`, `design-weekly-update`, `design-finance-report`, `design-tweaks`, `design-critique`. All read brand tokens from root `DESIGN.md` — swap with `/use-design <brand>` (72+ presets shipped). |
| Reference (with adapt-before-fork disclaimer) | `samba-publish` — internal-company URL deployment via Cloudflare Pages |

Each skill has its own `.claude/skills/<name>/SKILL.md` file documenting what it does, trigger phrases, and process steps. Browse `.claude/skills/` to look around.

**MCPs (5 pre-configured in `.mcp.json`).**

These are connectors to external services. After install, run `/mcp` in Claude Code to authorize each one (standard browser OAuth — no app registration needed):

- `gemini-vision` — local image/video/document analysis using Google's free Gemini tier. Needs `GEMINI_API_KEY` in your shell env ([get one free](https://aistudio.google.com/apikey)).
- `exa` — web search.
- `slack` — read, send, search Slack messages.
- `atlassian` — Jira tickets + Confluence pages.
- `figma` — read Figma designs and convert to code.

**Brand presets (72+).** Pre-built design systems at `workspace/3-Resources/design-systems/` — Airbnb, Stripe, Linear, Notion, Claude, Vercel, Tesla, BMW, Lamborghini, Spotify, and 60+ others. Switch the active brand with `/use-design <brand>` and every design-* skill renders in that style.

**Persona templates (6).** Generic SOUL / USER / IDENTITY / CLAUDE / README / TOOLS templates that `/bootstrap` fills in with your values.

**Hooks (7 + 2 libs).** PreToolUse, PostToolUse, UserPromptSubmit, PreCompact, Stop hooks wired in `.claude/settings.json`. Handle status line, structural code reads, post-edit diagnostics, auto-handoff on compaction, intent routing, external-action friction (Slack send, force-push, Atlassian writes, `rm -rf`).

---

## Recurring Work

Plain Claude Code primitives:

- **`CronCreate` / `CronList` / `CronDelete`** — schedule recurring agent runs at cron expressions
- **`/schedule`** — set up scheduled remote agents on a cron
- **`/loop`** — self-paced or interval-based recurring tasks
- **Hooks** (`.claude/hooks/`) — event-driven automation (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `PreCompact`)

---

## Quick reference

| I want to... | How |
|---|---|
| Understand how X works in this OS (PARA, Configuration, tools, skills, decisions) | `/os-guide` skill — reads canonical files live with file:line citations |
| Refresh `/os-guide` after adding new tools / skills / brands / decisions | `/os-guide --sync` — diffs filesystem against last sync, proposes routing updates, asks before applying |
| Know who <user.name> is | `USER.md` |
| Know who <assistant.name> is | `SOUL.md`, `IDENTITY.md` |
| See active projects (live, with staleness) | `bash <workspace.root>/<workspace.resources>/templates/project-query.sh` |
| See unmigrated projects | `... project-query.sh --status all` |
| Scaffold a new project (work or code repo) | `/new-project` |
| Archive a finished project | `/archive-project` |
| Friday review of stale projects | `/prune-projects` |
| Find existing knowledge | `/find <topic>` |
| Look up a person | `/contact <name>` |
| Log an interaction | `/contact-log <name>` |
| Write a morning briefing | `/briefing` |
| Process the inbox | `/inbox-process` |
| Save something for later | `/save-resource` |
| Think through a problem first | `/thinking-partner` |
| Swap the active design brand | `/use-design <brand>` |
| Add a recurring task | `CronCreate` or `/schedule` |
| Reconfigure identity / persona | `/bootstrap` (delete `setup_completed:` line in CLAUDE.md first) |
| See what <assistant.name> did today | `memory/YYYY-MM-DD.md` |

---

## Want to back up your work to GitHub? (optional)

The simple install instructions above just clone the public repo to your computer. Your personal data (memory logs, briefings, contacts, projects) lives only on your Mac.

If you want a GitHub backup or want to use this on multiple computers, **fork** the repo instead. A fork is your own copy on GitHub that you can push to.

```bash
# Option 1: via the GitHub CLI
gh repo fork the-sid-dani/second-brain-os --clone --remote
cd second-brain-os
claude
/bootstrap

# Option 2: via the web
# Visit https://github.com/the-sid-dani/second-brain-os/fork and click "Create fork"
# Then clone YOUR fork:
git clone https://github.com/YOUR-GITHUB-USERNAME/second-brain-os ~/Desktop/second-brain-os
cd ~/Desktop/second-brain-os
claude
/bootstrap
```

If you skipped this and want to add backup later, you can — just create a new private repo on GitHub and push your local copy to it.

---

## Cleanup history

- **<YYYY-MM-DD>** — Initial fork. Configured via `/bootstrap`.
