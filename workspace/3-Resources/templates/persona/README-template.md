# Second-Brain Harness

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

## Quick start

```bash
git clone <this-repo>
cd <repo-name>
./scripts/install.sh
```

The installer is idempotent — safe to re-run. It detects existing tooling (Homebrew, Claude Code, etc.) and skips what's already present. See `INSTALL.md` for manual install steps if you prefer step-by-step control.

After install, open Claude Code in the cloned folder and run `/bootstrap` to configure your identity, persona, and workspace (see the full walkthrough below).

---

## Install in 5 minutes

### What you need

- A Mac (Linux and Windows also work — commands shown are for Mac)
- **[Claude Code](https://claude.com/claude-code)** installed (free terminal app from Anthropic — install it first if you haven't)
- **Git** — already on most Macs. Open Terminal and run `git --version` to check. If you see "command not found", run `xcode-select --install` and follow the prompts.

That's it. You don't need to be a developer.

### Quick start — three commands

Open **Terminal.app** (in Applications → Utilities, or hit ⌘-Space and type "Terminal"), then run these three commands:

```bash
git clone https://github.com/the-sid-dani/second-brain-harness ~/Desktop/second-brain-harness
cd ~/Desktop/second-brain-harness
claude
```

That clones the harness to your Desktop and opens Claude Code in that folder. The new Claude Code session you just opened will load all the harness skills automatically.

**Then, in the Claude Code session that just opened, type:**

```
/bootstrap
```

`/bootstrap` is an interactive setup that walks you through identity, persona, design system, and workspace configuration (~10 minutes). Answer its questions and you're done.

When it finishes, try one of these in the same Claude Code session:
- *"morning, what's on my plate today?"* → your first briefing
- *"let's start a new project for [whatever you're working on]"* → your first project scaffold

### Why the order matters (one technical note)

Claude Code loads its skills at session-start by scanning the directory it was launched from. That's why you need to `cd` into the cloned folder **before** running `claude` — otherwise the new session won't see `/bootstrap` or the other harness skills.

If you forget and run `claude` first, just type `exit`, then `cd` to the cloned folder, then `claude` again.

### Alternative — chat through it with Claude

If you'd rather have a conversation than run terminal commands, here's a prompt to paste into any Claude Code session. **Note**: Claude can clone the repo and tell you the next step, but it can't run `/bootstrap` for you — you'll need to quit Claude Code after the clone and re-open it in the cloned folder. This is a fundamental Claude Code constraint (skills load at session-start, not on `cd`), not a limitation of the prompt.

1. Open Terminal and run `claude` to start any Claude Code session.

2. Paste this into Claude Code and hit Enter:

   ```
   Hi! I want to install the second-brain-harness — a personal AI workspace.
   The public template is at: https://github.com/the-sid-dani/second-brain-harness

   Please help me set this up. Walk me through these steps:

   1. Check what I have installed by running `git --version` and `claude --version`.
      If anything's missing, tell me how to install it on a Mac and pause until I confirm.

   2. Ask me where I want to clone the repo (default: ~/Desktop/second-brain-harness).
      Clone it there for me, then cd into it.

   3. **Important honest handoff**: tell me you can't invoke /bootstrap from this
      session because Claude Code loads skills at session-start. Tell me to:
        - type `exit` to quit this Claude Code session
        - re-open Claude Code from the cloned folder (the path you just cloned into)
        - then type `/bootstrap` in that new session

      Don't pretend to run /bootstrap. The skill literally isn't available here.

   Treat me like a smart non-technical person — explain what each step does
   briefly, don't over-explain, and ask before doing anything destructive.
   ```

3. **Follow Claude's instructions** to clone the repo. After the clone, Claude will tell you to quit and re-open Claude Code in the cloned folder.

4. **Re-open Claude Code** in the cloned folder (Terminal: `cd ~/Desktop/second-brain-harness && claude`), then type `/bootstrap`.

---

## What is this?

A workspace skeleton that turns Claude Code into your personal chief-of-staff (or research companion, engineering co-pilot, sales-ops assistant — you pick the persona during setup). You configure it once with your identity, then talk to the assistant normally. It routes your intent to the right pre-built workflow.

**Three pieces make this work:**

1. **Skills** — 57 pre-built workflows shipped in `.claude/skills/`. Each one has a description that tells Claude when to use it, so your natural-language prompts automatically route to the right skill.
2. **A PARA workspace** at `workspace/` — Inbox, Projects, Coding, Resources, Archive. Your work lives here; skills know how to navigate it.
3. **Configuration tokens** in `CLAUDE.md` — your name, your role, your workspace paths. Skills reference these symbolically so the workspace adapts to your setup.

PARA is a personal-knowledge-management system invented by Tiago Forte — short for **P**rojects, **A**reas, **R**esources, **A**rchive. The workspace borrows the same idea.

---

## What you can ask it to do

You don't have to memorize slash commands. Claude reads your prompt and the description of every installed skill, then picks the best match.

| You say | Auto-routes to |
|---|---|
| "morning, what's on my plate today?" | `/briefing` |
| "do I have research on prompt caching?" | `/find` |
| "what did I save about Hyperframes?" | `/find` |
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

You can also type `/skill-name` directly if you know it — both work.

---

## What's included

**Skills (57 total).**

| Category | Skills |
|---|---|
| Chief-of-staff (everyday workflows) | `archive-project`, `briefing`, `budget-tracker`, `contact`, `contact-log`, `desktop-organizer`, `find`, `inbox-process`, `new-project`, `prune-projects`, `save-resource`, `sync-indexes`, `thinking-partner` |
| Setup & meta | `bootstrap`, `skill-creator` |
| Research | `company-research`, `people-research` |
| Project tracking | `confluence-publish-markdown`, `jira-decompose-epic`, `scaffold-engineering-project` |
| Design (26 skills) | landing pages, dashboards, decks, mobile apps, blog posts, social carousels, videos, posters, wireframes, OKR trackers, and more |
| Persona templates (10) | `persona-exec-assistant`, `persona-sales-ops`, `persona-researcher`, `persona-project-manager`, `persona-team-lead`, `persona-content-creator`, `persona-customer-support`, `persona-event-coordinator`, `persona-hr-coordinator`, `persona-it-admin` |
| Reference (with adapt-before-fork disclaimer) | `samba-publish` — internal-company URL deployment via Cloudflare Pages |

Each skill has its own `.claude/skills/<name>/SKILL.md` file documenting what it does, trigger phrases, and process steps. Browse `.claude/skills/` to look around.

**MCPs (5 pre-configured in `.mcp.json`).**

These are connectors to external services. After install, run `/mcp` in Claude Code to authorize each one (standard browser OAuth — no app registration needed):

- `gemini-vision` — local image/video/document analysis using Google's free Gemini tier. Needs `GEMINI_API_KEY` in your shell env ([get one free](https://aistudio.google.com/apikey)).
- `exa` — web search.
- `slack` — read, send, search Slack messages.
- `atlassian` — Jira tickets + Confluence pages.
- `figma` — read Figma designs and convert to code.

**Brand presets (73).** Pre-built design systems at `workspace/3-Resources/design-systems/` — Airbnb, Stripe, Linear, Notion, Claude, Vercel, Tesla, BMW, Lamborghini, Spotify, and 63 others. Switch the active brand with `/use-design <brand>` and every design-* skill renders in that style.

**Persona templates (6).** Generic SOUL / USER / IDENTITY / CLAUDE / README / TOOLS templates that `/bootstrap` fills in with your values.

**Workspace skeleton.** PARA-style under `workspace/`:
- `0-Inbox/` — capture / undecided
- `1-Projects/` — active projects (each gets its own folder with `CLAUDE.md` + `memory.md`)
- `2-Coding/` — code repos (each its own git; gitignored from this repo)
- `3-Resources/` — templates, contacts, meetings, briefings, research, reference, design-systems
- `4-Archive/` — finished work (move, never delete)

---

## Project map

```
second-brain-harness/
├── README.md              ← you are here
├── CLAUDE.md              ← project instructions + Configuration section
├── SOUL.md                ← <assistant.name>'s persona, voice, boundaries
├── USER.md                ← <user.name>'s profile, role, preferences
├── IDENTITY.md            ← <assistant.name>'s name, version, origin
├── TOOLS.md               ← tool inventory (regenerated by /bootstrap)
├── DESIGN.md              ← active design system (swap with /use-design <brand>)
├── EXAMPLE-CONFIG.md      ← worked example of the Configuration section
├── agent-config.json      ← runtime config
├── .mcp.json              ← MCP server registration
├── .env.example
├── CHANGELOG.md
│
├── memory/                ← curated long-form memory (git-tracked)
│   └── YYYY-MM-DD.md      ← append-only daily logs
│
│   (parallel: ~/.claude/projects/.../memory/MEMORY.md — auto-managed, per-machine, NOT in git)
│
├── <workspace.root>/      ← your PARA workspace
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
│   │   └── design-systems/           ← 73 brand presets
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
- New code repo? → `/new-project`, choose `code-repo` as project-type. Creates at `<workspace.root>/<workspace.coding>/<scope>/<name>/`. Auto-appends to a `code-projects.md` index (which the skill creates on first invocation — fresh forks don't ship one)
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
gh repo fork the-sid-dani/second-brain-harness --clone --remote
cd second-brain-harness
claude
/bootstrap

# Option 2: via the web
# Visit https://github.com/the-sid-dani/second-brain-harness/fork and click "Create fork"
# Then clone YOUR fork:
git clone https://github.com/YOUR-GITHUB-USERNAME/second-brain-harness ~/Desktop/second-brain-harness
cd ~/Desktop/second-brain-harness
claude
/bootstrap
```

If you skipped this and want to add backup later, you can — just create a new private repo on GitHub and push your local copy to it.

---

## Cleanup history

- **<YYYY-MM-DD>** — Initial fork. Configured via `/bootstrap`.
