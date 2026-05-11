# Second-Brain Harness

A Claude Code workspace harness for personal knowledge work — projects, contacts, briefings, meeting prep, design output — driven by natural-language conversation, not memorized slash commands.

---

## What is this?

A forkable workspace skeleton that turns Claude Code into your personal chief-of-staff (or research companion, or engineering co-pilot — you pick the persona during setup). You configure it once with your identity and workspace paths, then talk to the assistant normally. It routes your intent to the right skill.

```
You: "morning, what's on my plate today?"
→ runs /briefing — composes Gmail + Calendar + Slack + Jira + GitHub + your active projects

You: "do I have any notes on Q1 OKRs?"
→ runs /find — searches resources/, projects/, archive/, memory/

You: "tell me about Alex"
→ runs /contact — surfaces Alex's profile, last interaction, open commitments

You: "I just spoke with Alex about the launch"
→ runs /contact-log — appends an interaction entry

You: "let's start a new project for Q3 planning"
→ runs /new-project — scaffolds workspace/1-Projects/YYYY-MM-q3-planning/
```

**Three pieces make this work:**

1. **Skills** — pre-built workflows under `.claude/skills/` (57 in the default install). Each has a thorough `description:` Claude reads to auto-route your prompt.
2. **A PARA workspace** at `<workspace.root>/` — Inbox / Projects / Coding / Resources / Archive. Your work lives here; skills know how to navigate it.
3. **Configuration tokens** in `CLAUDE.md` — your name, your role, your workspace paths. Skills reference these symbolically (`<user.name>`, `<workspace.projects>`) so the harness adapts cleanly to your fork.

---

## Quick start

```bash
git clone https://github.com/<your-username>/second-brain-harness
cd second-brain-harness
claude                       # opens Claude Code in this directory
/bootstrap                   # interactive: walks through identity, persona, design system, workspace
/briefing                    # try it — produces <workspace.root>/3-Resources/briefings/morning-briefing-YYYY-MM-DD.md
```

`/bootstrap` is ~10 minutes and runs only once per fork (it locks itself by writing `setup_completed: <date>` to CLAUDE.md). After that, just talk to the assistant naturally.

If you prefer manual setup, see `EXAMPLE-CONFIG.md` for a worked example of the Configuration section in CLAUDE.md, fill it in by hand, and skip `/bootstrap`.

---

## How it works — the natural-language model

You don't have to memorize slash commands. Claude reads your prompt and the description of every installed skill, then picks the best match. Some examples:

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
| "scaffold an engineering project under Epic-XYZ" | `/scaffold-engineering-project` |
| "save this for later" | `/save-resource` |
| "process my inbox" | `/inbox-process` |

You can still type `/skill-name` directly if you know it — both work.

A second layer, the `UserPromptSubmit` hook at `.claude/hooks/intent-detector.mjs`, logs which natural-language patterns match which skills (to `.claude/intent-detector-log.jsonl`, gitignored). Currently log-only (v1) — a future v2 will inject suggestions inline. Either way the routing above happens via Claude reading skill descriptions, not the hook.

---

## What's included

**Skills (57).**

| Category | Skills |
|---|---|
| Chief-of-staff (first-party) | `archive-project`, `briefing`, `budget-tracker`, `contact`, `contact-log`, `desktop-organizer`, `find`, `inbox-process`, `new-project`, `prune-projects`, `save-resource`, `sync-indexes`, `thinking-partner` |
| Setup & meta | `bootstrap`, `skill-creator` |
| Research | `company-research`, `people-research` |
| Atlassian | `confluence-publish-markdown`, `jira-create-vertical-slices`, `scaffold-engineering-project` |
| Design (26) | `design-blog-post`, `design-dashboard`, `design-docs-page`, `design-email-marketing`, `design-finance-report`, `design-hyperframes` (video), `design-image-poster`, `design-magazine-poster`, `design-meeting-notes`, `design-mobile-app`, `design-pm-spec`, `design-pricing-page`, `design-saas-landing`, `design-simple-deck`, `design-social-carousel`, `design-team-okrs`, `design-video-shortform`, `design-web-prototype`, `design-weekly-update`, `design-wireframe-sketch`, and others |
| Persona (10) | `persona-exec-assistant`, `persona-sales-ops`, `persona-researcher`, `persona-project-manager`, `persona-team-lead`, `persona-content-creator`, `persona-customer-support`, `persona-event-coordinator`, `persona-hr-coordinator`, `persona-it-admin` |
| Reference (with disclaimer) | `samba-publish` — Cloudflare Pages + SSO publishing; adapt before fork use |

Each skill has its own `.claude/skills/<name>/SKILL.md` documenting trigger phrases, inputs, invariants, and process steps. Browse them or `cat .claude/skills/*/SKILL.md | head -3` to scan headers.

**MCPs (5 pre-configured in `.mcp.json`).**

- `gemini-vision` (local — `.claude/mcp-servers/gemini-vision.mjs`). Requires `GEMINI_API_KEY` env var. Free tier 15 req/min.
- `exa` (HTTP) — web search. Use only `web_search_advanced_exa`.
- `slack` (HTTP) — read/send/search messages. **Needs your own Slack client ID** (replace `REPLACE_WITH_YOUR_SLACK_CLIENT_ID` in `.mcp.json`).
- `atlassian` (HTTP) — Jira + Confluence. OAuth via `/mcp authorize`.
- `figma` (HTTP) — read Figma designs into code. OAuth via `/mcp authorize`.

After cloning, run `/mcp` to inspect status and authorize each one.

**Brand presets (73).** Drop-in design systems at `<workspace.root>/<workspace.resources>/design-systems/` — Airbnb, Stripe, Linear, Notion, Claude, Vercel, Tesla, and 66 others. Swap the active brand with `/use-design <brand>` and every design-* skill renders in that style.

**Persona templates (6).** Generic SOUL / USER / IDENTITY / CLAUDE / README / TOOLS templates at `<workspace.root>/<workspace.resources>/templates/persona/`. `/bootstrap` fills these in with your values.

**Workspace skeleton.** PARA-style under `<workspace.root>/`:
- `0-Inbox/` — capture / undecided
- `1-Projects/` — active projects (each with its own `CLAUDE.md` + `memory.md`)
- `2-Coding/` — code repos (each their own git; gitignored from this repo)
- `3-Resources/` — templates / contacts / meetings / research / reference / design-systems
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
    ├── skills/            ← 57 skills
    ├── hooks/             ← intent-detector.mjs
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
| `assistant.name` | Persona name — `<agent>` by default, customize to whatever fits (Atlas, Echo, Sage, etc.) |
| `assistant.role` | "Chief of Staff" / "Research Companion" / "Engineering Co-Pilot" |
| `assistant.vibe` | One-line vibe descriptor for SOUL.md voice cues |
| `assistant.emoji` | Optional emoji for the persona |
| `workspace.root` | Default `workspace`; rename to `brain`, `<name>-workspace`, etc. |
| `workspace.inbox / projects / coding / resources / archive` | Subfolder names — defaults are 0-Inbox, 1-Projects, etc. |
| `setup_completed` | Date `/bootstrap` ran (presence = configured; absence = fresh fork) |

Run `/bootstrap` from a fresh clone to fill these in interactively. See `EXAMPLE-CONFIG.md` for what a completed Configuration looks like.

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

## Cleanup history

- **<YYYY-MM-DD>** — Initial fork. Configured via `/bootstrap`.
