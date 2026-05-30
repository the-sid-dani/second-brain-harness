# Second-Brain OS — Project Instructions for <assistant.name>

This file is project-scoped instructions only. **Persona, user, and tooling context live in dedicated files** — do not duplicate them here.

## Load Order at Session Start

1. **@SOUL.md** — <assistant.name>'s persona, voice, boundaries
2. **@USER.md** — <user.name>'s profile, role, communication preferences, team
3. **@IDENTITY.md** — <assistant.name>'s name, version, origin
4. **@TOOLS.md** — Available tools and capabilities
5. **@README.md** — Project map and update rules

If anything below conflicts with those files, those files win.

---

## Configuration — source of truth for skills

Skills (`/new-project`, `/archive-project`, `/prune-projects`, the intent-detector hook) read the values below as the source of truth. **To fork this workspace for your own use, run `/bootstrap`** — it walks through these values interactively and rewrites this section. Every skill references these paths and identity values symbolically (e.g., `<workspace.projects>`) and adapts automatically.

### workspace
- `workspace.root` = `<workspace.root>` (default: `workspace`; rename to `workspace`, `brain`, `<assistant>-workspace`, etc.)
- `workspace.inbox` = `0-Inbox`
- `workspace.projects` = `1-Projects`
- `workspace.coding` = `2-Coding`
- `workspace.resources` = `3-Resources`
- `workspace.archive` = `4-Archive`

Resolved paths (combine the above): `<workspace.root>/<workspace.projects>` → e.g., `workspace/1-Projects`.

### templates (under `<workspace.root>/<workspace.resources>/templates/`)
- `templates.project_claude` = `project-claude-template.md` — for non-code project CLAUDE.md
- `templates.project_memory` = `project-memory-template.md` — for any project's memory.md
- `templates.code_claude` = `code-project-claude-template.md` — for code-repo project CLAUDE.md
- `templates.persona` = `persona/` — for persona file templates (used by `/bootstrap`)

### indexes
- `indexes.code_projects` = `<workspace.root>/<workspace.resources>/code-projects.md` — the one allowed index file

### scripts
- `scripts.project_query` = `<workspace.root>/<workspace.resources>/templates/project-query.sh`

### user
- `user.name` = `<user.name>` — short name; default stakeholder for new projects, voice cues ("Morning <user.name>!")
- `user.full_name` = `<user.full_name>` — full display name
- `user.email` = `<user.email>`
- `user.timezone` = `<user.timezone>`
- `user.github` = `<user.github>` — used by `/new-project`'s code-repo branch for `gh repo create <user.github>/<name> --private`
- `user.email_signature` = `<user.email_signature>`
- `user.company` = `<user.company>`

### assistant
- `assistant.name` = `<assistant.name>` — referenced in SKILL.md prose via `<assistant.name>` placeholder so skills don't hardcode the persona name. Skills auto-substitute when SKILL.md auto-loads.
- `assistant.role` = `<assistant.role>` — short role descriptor (e.g., "Chief of Staff", "Research Companion", "Engineering Co-Pilot")
- `assistant.vibe` = `<assistant.vibe>` — one-line vibe descriptor used in SOUL.md voice cues
- `assistant.emoji` = `<assistant.emoji>`

### lifecycle
- `setup_completed` = `<YYYY-MM-DD>` — date `/bootstrap` ran successfully. Used as the re-run gate (presence = configured; missing/empty = fresh fork). To re-run `/bootstrap`, delete this line first.

### Forking note

When someone clones this repo to use as their own second-brain OS:
1. Run `/bootstrap` — interactive setup that fills in the values above and (optionally) rewrites the persona files (SOUL, USER, IDENTITY) from templates at `<workspace.root>/<workspace.resources>/templates/persona/`
2. Optionally rename `<workspace.root>/` to whatever feels right and update `workspace.root` to match
3. After `/bootstrap`: try `/briefing` for a morning brief, `/find <topic>` to recall, `/help` for the full skill list

The skills themselves shouldn't need code changes for a fork — the only hardcoded paths in them are Claude Code's own (`.claude/hooks/`, `~/.claude/projects/...`), which are framework-level.

---

## HQ / Active Project model (optional organizational pattern)

An optional pattern for scaling the OS as your work grows. A fresh fork ships with none of these — adopt it once you have recurring, long-running workstreams.

**HQ = evergreen workstation.** An `hq-<name>/` folder at repo root (peer to this CLAUDE.md) is a workstation that accumulates monotonically — strategy, playbooks, durable artifacts for one long-running area of responsibility. It grows from completed projects, never empties, and is owned indefinitely. Each HQ holds its own `CLAUDE.md` + `memory.md` + `resources/`.

**Active Project = bounded current execution.** Each `<workspace.projects>/<slug>/` is in-flight tactical work — it has a start, an end, and (recommended) a `parent_hq:` it deposits into when it completes. Tactical state lives here while alive (this week's data, drafts, notes). **If it's in `<workspace.projects>/`, it's active. If it's not active, it's not there.**

**Progressive loading.** If you create HQs, don't pre-load them all at session start. Keep a routing table in `memory.md` that maps task type → HQ, and load only the matched HQ's `CLAUDE.md` + `memory.md` for the task in front of you. When no row matches, work from root context alone.

**Completion ritual** (enforced by `/archive-project`):
1. Promote durable artifacts from the project into the parent HQ — with a freshness check on every file moved (stale-on-promotion pollutes the evergreen OS).
2. Archive the tactical residue (drafts, raw data) to `<workspace.archive>/<slug>/`.
3. Flip project frontmatter `status: active` → `done`.
4. Append a one-line entry to the project's `memory.md` noting what got promoted vs archived.

---

## Documentation maintenance (4 load-bearing rules)

Prevents the stale-doc-graveyard pattern — multiple versions of the same doc coexisting, confusing both you and the assistant.

1. **One canonical filename per artifact. No version suffixes.** Edit `PLAN.md`, never create `PLAN-V2.md`. Git history is the version log. Frozen stakeholder snapshots go to `_snapshots/<doc>-YYYY-MM-DD.md`, named by date, not version number.
2. **Supersede = move out same day.** When a doc is replaced, the predecessor moves to `_archive/` (folder-local) or `<workspace.archive>/` (workspace-level) in the same commit as the lock. No `status: superseded` files sitting next to current canonical ones.
3. **Every folder with 5+ canonical docs gets a `README.md` pointer.** Top of README names the canonical files. Everything else in the folder is reference or history.
4. **The lock ritual updates the index.** Locking a new canonical version in the same commit: (a) edit or rename the canonical file (no version suffixes — rule 1), (b) update the authoritative-docs pointer in the relevant CLAUDE.md/README, (c) move the predecessor per rule 2. If any is missing, the lock isn't done.

**Before citing any doc as canonical**, check (a) the filename is not version-suffixed, (b) frontmatter `status:` is `active` or `locked` (not `superseded`/`draft`), (c) it lives outside `_archive*/` and `<workspace.archive>/`. If any check fails, it's not canonical regardless of how authoritative it sounds.

---

## Naming conventions

Follow these when creating any new file / folder / project — they keep the workspace greppable and prevent drift. Before creating any new path, check it against the list; if a proposed path would violate one, correct it first.

- `lowercase-kebab.md` for working docs, plans, trackers.
- `UPPERCASE-KEBAB.md` ONLY for the closed set of OS files (CLAUDE / SOUL / USER / IDENTITY / README / TOOLS / CHANGELOG). No additions without versioning this standard.
- `YYYY-MM-DD-<topic>.md` date-prefix only when the date is load-bearing (meeting notes, briefings, dated snapshots).
- `YYYY-MM-<slug>/` for project folders in `<workspace.projects>/`.
- `NN-<topic>.md` numeric prefix only when sequence carries meaning.
- `lowercase-kebab/` for code repos in `<workspace.coding>/` — no version suffix in repo names.
- HQ subfolders follow the same rules as the root workspace.
- `_archive/` and `_snapshots/` use the underscore prefix; machine-managed state uses a `.dot-prefix/`.
- Max 3 levels of nesting.
- Projects scaffold with a base 3 subdirs (`inputs/` + `working/` + `outputs/`); type-specific subfolders emerge lazily, not up front.

---

## Project-Specific Context

For Memory System (dual-folder), Workspace (PARA layout), and Outputs conventions, see **README.md** — that's the canonical source. This file holds only the project-specific deltas below.

### Briefing & report outputs

<assistant.name> writes to `<workspace.root>/<workspace.resources>/briefings/morning-briefing-<YYYY-MM-DD>.md`, `<workspace.root>/<workspace.resources>/meeting-prep/`, `<workspace.root>/<workspace.resources>/organization-reports/`. Never write outputs at the workspace root. Never mix briefings with project files.

### OS knowledge skill — consult `/os-guide` before answering OS-shaped questions from memory

When the user asks an OS-shaped question — workspace paths, Configuration token values, what skills exist, how memory works, contacts schema, locked decisions, Operating Principles, tool inventory — **invoke `/os-guide` instead of answering from memory.** Memory drifts; the canonical source files (CLAUDE.md, README.md, SOUL.md, TOOLS.md, etc.) don't. `/os-guide` reads them live, returns the answer with file:line citations, and resolves Configuration tokens at every invocation so paths reflect the actual fork. Specifically — Claude SHOULD self-consult before writing any of the following into a user-facing response: a workspace path, a Configuration value, a schema field, a claim about a skill's behavior, or a claim about a tool's connection state. After adding new tools/skills/brands/decisions to the OS, run `/os-guide --sync` to refresh its routing table. Read-only by default; `--sync` is the only mutation mode, gated behind explicit approval.

### Contacts (per-person reference directory)

Per-person tracking lives at `<workspace.root>/<workspace.resources>/contacts/<slug>.md`. **Schema, frontmatter fields, body sections, and conventions** are documented at `<workspace.root>/<workspace.resources>/contacts/README.md` — single source of truth.

The journal of any specific interaction lands in `memory/YYYY-MM-DD.md`; the durable per-person directory lives in Resources. Skills: `/contact` (read), `/contact-log` (append interaction). Pending: `/contact-add`, `/contact-update`, `/contact-enrich`, `/contact-audit`, `/contact-research`.

### Cross-references — WikiLinks convention

Reference one note from another with `[[topic]]` or `[[path/to/note]]` syntax. Manual convention — no tool enforces it. `/find` follows `[[X]]` links to surface related notes. Future-proof for Obsidian if <user.name> ever opens the vault there. Use the topic slug, not the full filename.

---

## Briefing & Synthesis Rules (<assistant.name>-Specific)

These extend SOUL.md — do not restate SOUL guidance here, only project-specific deltas.

**For morning briefings:**
- Cross-reference email + calendar + meeting notes before writing — don't summarize one source in isolation
- Apply <user.name>'s priority signals (see USER.md): direct collaborators, calendar conflicts, priority topics
- Pull SPECIFIC action items from meeting transcripts — names, timelines, blockers — never "follow up generically"
- Briefings go to `<workspace.root>/<workspace.resources>/briefings/`, not the conversation only

**For meeting prep:**
- Always check the Recordings folder first if `<user.name>` has one configured (Gemini summaries are pre-condensed)
- Fall back to Transcripts folder if no recording exists
- Surface what <user.name> promised in past meetings with the same person

**For writing in <user.name>'s voice:**
- Load `memory/writing-style.md` before drafting strategic docs (if it exists — `<user.name>` writes their style profile here)
- Quantify everything (metrics, percentages, ROI)
- Use 🟢🟡🔴 status indicators in trackers; NO emojis in formal external docs

---

## Active Project Index — query at session start

Don't hardcode the project list here; it goes stale. Run the query script to get a live tabular view (status, project-type, days-since-touched, stale flag):

```bash
bash <workspace.root>/<workspace.resources>/templates/project-query.sh
```

Default lists active projects sorted by staleness. Useful flags:
- `--status all` — also surface unmigrated projects (folders without `CLAUDE.md`) flagged `NEEDS_SCAFFOLD`
- `--tsv` — tab-separated, no header, for piping
- `--stale-days 60` — adjust the staleness threshold

For code projects (gitignored, not visible to the script), see `<workspace.root>/<workspace.resources>/code-projects.md` — this file is auto-created by `/new-project` on first code-repo scaffold; fresh forks do not ship it.

---

## Boundaries (Project-Specific)

- **Do not auto-send messages** to Slack, email, Telegram, or WhatsApp without explicit "send it" from <user.name>. Drafts are fine.
- **Do not modify `<workspace.root>/<workspace.projects>/`** files without asking — those are <user.name>'s working drafts.
- **Memory writes are append-only** under `memory/YYYY-MM-DD.md`. Don't rewrite history.
- **For destructive ops** (delete, force, reset): ask first, even if previously authorized for one task.
