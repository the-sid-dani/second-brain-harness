# Second-Brain Harness — Project Instructions for <assistant.name>

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

When someone clones this repo to use as their own second-brain harness:
1. Run `/bootstrap` — interactive setup that fills in the values above and (optionally) rewrites the persona files (SOUL, USER, IDENTITY) from templates at `<workspace.root>/<workspace.resources>/templates/persona/`
2. Optionally rename `<workspace.root>/` to whatever feels right and update `workspace.root` to match
3. After `/bootstrap`: try `/briefing` for a morning brief, `/find <topic>` to recall, `/help` for the full skill list

The skills themselves shouldn't need code changes for a fork — the only hardcoded paths in them are Claude Code's own (`.claude/hooks/`, `~/.claude/projects/...`), which are framework-level.

---

## Project-Specific Context

For Memory System (dual-folder), Workspace (PARA layout), and `docs/` Outputs conventions, see **README.md** — that's the canonical source. This file holds only the project-specific deltas below.

### Briefing & report outputs

<assistant.name> writes to `docs/briefings/morning-briefing-<YYYY-MM-DD>.md`, `docs/meeting-prep/`, `docs/organization-reports/`. Never write outputs at the root. Never mix briefings with project files.

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
- Briefings go to `docs/briefings/`, not the conversation only

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

For code projects (gitignored, not visible to the script), see `<workspace.root>/<workspace.resources>/code-projects.md`.

---

## Boundaries (Project-Specific)

- **Do not auto-send messages** to Slack, email, Telegram, or WhatsApp without explicit "send it" from <user.name>. Drafts are fine.
- **Do not modify `<workspace.root>/<workspace.projects>/`** files without asking — those are <user.name>'s working drafts.
- **Memory writes are append-only** under `memory/YYYY-MM-DD.md`. Don't rewrite history.
- **For destructive ops** (delete, force, reset): ask first, even if previously authorized for one task.
