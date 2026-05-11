# Daily Agents

<user.name>'s personal <assistant.role> workspace. <assistant.name> lives here.

This is **the canonical home** for everything related to <assistant.name>: persona, memory, active projects, briefings, agents, skills.

---

## Project Map

```
daily-agents/
├── README.md              ← you are here. Project map + update rules.
├── CLAUDE.md              ← project instructions for Claude/<assistant.name> (slim, references others)
├── SOUL.md                ← <assistant.name>'s persona, voice, boundaries
├── USER.md                ← <user.name>'s profile, role, team, preferences
├── IDENTITY.md            ← <assistant.name>'s name, version, origin
├── TOOLS.md               ← tool inventory
├── DESIGN.md              ← active design-system selection (read by design:* skills); swap with /use-design <brand>
├── agent-config.json      ← runtime config
│
├── memory/                ← Folder B: project memory (in git, curated long-form)
│   ├── memory.md            project-memory index (note: lowercase — distinct from Folder A)
│   ├── YYYY-MM-DD.md        daily logs (append-only)
│   ├── writing-style.md     <user.name>'s writing style profile (optional)
│   └── learned-preferences.md
│
│   Folder A — auto-memory (live, per-machine, NOT in git):
│   ~/.claude/projects/-Users-<your-username>-<your-path>-daily-agents/memory/
│   └── MEMORY.md (uppercase) + per-fact memory files; managed by Claude Code
│
├── <workspace.root>/      ← PARA-style work area
│   ├── 0-Inbox/             ad-hoc / not-yet-decided capture zone
│   ├── 1-Projects/          active projects (YYYY-MM-name/, each with CLAUDE.md + memory.md)
│   ├── 2-Coding/            code repos (each own git): work/personal/forks/archive
│   ├── 3-Resources/         templates/, meetings/, reference/, research/, design-systems/, contacts/
│   └── 4-Archive/           completed/stale (move, never delete)
│
├── docs/                  ← <assistant.name>'s outputs (briefings, reports, prep)
│   ├── briefings/
│   ├── meeting-prep/
│   └── organization-reports/
│
├── .claude/skills/        ← project-local skills
├── .claude/               ← Claude Code config (commands, hooks, settings)
└── thoughts/              ← scratch / exploratory notes
```

---

## Forking this repo

If you just cloned this and you're not <user.name>: run `/bootstrap` in Claude Code from the repo root. It walks through identity, persona, workspace skeleton, tool connectivity check, and a smoke test in ~5–10 minutes. See `EXAMPLE-CONFIG.md` for what a filled-in Configuration section looks like for a non-default user.

The persona templates `/bootstrap` reads from live at `<workspace.root>/<workspace.resources>/templates/persona/` (SOUL, USER, IDENTITY, CLAUDE, README, TOOLS templates). Skip `/bootstrap` and edit the Configuration section in `CLAUDE.md` directly if you prefer manual setup.

---

## Update Rules — "What goes where, when"

### Identity / Persona Files (root)

| File | When to update |
|------|----------------|
| `SOUL.md` | <assistant.name>'s voice, boundaries, or "how to be helpful" rules change. Tell <user.name> when you do. |
| `USER.md` | <user.name>'s role, team, preferences shift. Always convert relative dates to absolute. |
| `IDENTITY.md` | Version bumps, name changes. Rare. |
| `CLAUDE.md` | Project-specific context only (Drive IDs, output paths, briefing rules). **Never restate SOUL/USER content here.** |
| `TOOLS.md` | When the toolchain changes (MCP servers, hooks, skills inventory). |

### Memory — dual-folder model

Two memory folders, distinct roles. Both load at session start.

**Folder A — `~/.claude/projects/.../memory/`** (auto-managed)
- Claude Code writes here automatically when it learns a live preference, fact, or rule
- Indexed by `MEMORY.md` (uppercase)
- Per-machine; NOT in git

**Folder B — `memory/`** (in git, curated by <assistant.name> + <user.name>)
- `memory/YYYY-MM-DD.md` — append-only daily log
- `memory/memory.md` (lowercase) — index of project memory contents
- `memory/writing-style.md` — <user.name>'s writing style profile (optional)
- `memory/learned-preferences.md` — durable preferences

**Save rule:** live preference → Folder A. Daily journal entry or curated long-form → Folder B.

**Never** create a third memory location.

### Workspace (`<workspace.root>/`)

- New <assistant.name> project? → `/new-project` skill scaffolds at `<workspace.root>/<workspace.projects>/YYYY-MM-project-name/` from `<workspace.resources>/templates/`
- New code project? → `/new-project` skill, choose `code-repo` as project-type. Creates at `<workspace.root>/<workspace.coding>/<scope>/<name>/` and appends a row to `code-projects.md`.
- Reference doc, template, meeting prep, research dump? → `<workspace.root>/<workspace.resources>/<topic>/`
- Ad-hoc / undecided capture? → `<workspace.root>/<workspace.inbox>/`
- Project complete? → `/archive-project` skill moves it to `<workspace.archive>/` and flips status frontmatter
- Stale projects need review? → `/prune-projects` skill (Friday-batch staleness review)

### Outputs (`docs/`)

<assistant.name> writes briefings, prep docs, and reports here. Naming:
- `docs/briefings/morning-briefing-YYYY-MM-DD.md`
- `docs/meeting-prep/YYYY-MM-DD-<who-or-what>.md`
- `docs/organization-reports/YYYY-MM-DD-<topic>.md`

Never write outputs at the root.

### What does NOT belong at root

- ❌ Project-specific drafts — those go in `<workspace.root>/<workspace.projects>/<project>/`
- ❌ One-off scripts — those go in `<workspace.root>/<workspace.archive>/<context>/` or a code repo
- ❌ Reference data (CSVs, employee directories) — `<workspace.root>/<workspace.resources>/reference/`
- ❌ Junk (`.DS_Store`, zips, log dumps) — delete

---

## Recurring Work

Plain Claude Code primitives:

- **CronCreate / CronList / CronDelete** — schedule recurring agent runs at cron expressions
- **`/schedule`** skill — set up scheduled remote agents on a cron
- **`/loop`** skill — self-paced or interval-based recurring tasks
- **Hooks** (`.claude/hooks/`) — event-driven automation (PreToolUse, PostToolUse, Stop, PreCompact)

---

## Quick Reference

| I want to... | How |
|--------------|-----|
| Know who <user.name> is | `USER.md` |
| Know who <assistant.name> is | `SOUL.md`, `IDENTITY.md` |
| See active projects (live, with staleness) | `bash <workspace.root>/<workspace.resources>/templates/project-query.sh` |
| See unmigrated projects | `bash <workspace.root>/<workspace.resources>/templates/project-query.sh --status all` |
| See code repos | `cat <workspace.root>/<workspace.resources>/code-projects.md` |
| Scaffold a new project | `/new-project` skill |
| Archive a finished project | `/archive-project` skill |
| Friday review of stale projects | `/prune-projects` skill |
| Find a meeting transcript | `<workspace.root>/<workspace.resources>/meetings/` |
| Write a briefing | `/briefing` skill (writes to `docs/briefings/`) |
| Recall existing knowledge | `/find <topic>` skill |
| Look up a person | `/contact <name>` skill |
| Log an interaction | `/contact-log <name>` skill |
| Add a recurring task | `CronCreate` or `/schedule` skill |
| See what <assistant.name> did today | `memory/YYYY-MM-DD.md` |
| Reconfigure identity / persona | `/bootstrap` (re-runnable) |

---

## Cleanup History

- **<YYYY-MM-DD>** — Initial fork. Configured via `/bootstrap`.
