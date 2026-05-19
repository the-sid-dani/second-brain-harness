# EXAMPLE-CONFIG.md

This file shows what a filled-in Configuration section in `CLAUDE.md` looks like for a non-default user, along with brief context for each field. Use this as a reference when running `/bootstrap` or when manually editing `CLAUDE.md`.

The actual Configuration section lives in **root `CLAUDE.md`** under the `## Configuration — source of truth for skills` heading. Skills (`/new-project`, `/archive-project`, `/briefing`, etc.) read those values at runtime to resolve placeholder tokens like `<workspace.root>` and `<user.name>`.

---

## Example: a fictional user "Alex Rivera" forking this repo

Imagine Alex is a Senior Product Manager at Acme Corp who just cloned the second-brain-os repo to use as their own second-brain template. Alex chose to:
- Keep the workspace folder name as `workspace` (the harness ships with this default)
- Customize the assistant persona — picked the name "Atlas" with a research-companion vibe

Their Configuration section would look like:

```markdown
## Configuration — source of truth for skills

### workspace
- `workspace.root` = `workspace`
- `workspace.inbox` = `0-Inbox`
- `workspace.projects` = `1-Projects`
- `workspace.coding` = `2-Coding`
- `workspace.resources` = `3-Resources`
- `workspace.archive` = `4-Archive`

### templates (under `<workspace.root>/<workspace.resources>/templates/`)
- `templates.project_claude` = `project-claude-template.md`
- `templates.project_memory` = `project-memory-template.md`
- `templates.code_claude` = `code-project-claude-template.md`
- `templates.persona` = `persona/`

### indexes
- `indexes.code_projects` = `<workspace.root>/<workspace.resources>/code-projects.md`

### scripts
- `scripts.project_query` = `<workspace.root>/<workspace.resources>/templates/project-query.sh`

### user
- `user.name` = `Alex`
- `user.full_name` = `Alex Rivera`
- `user.email` = `alex@example.com`
- `user.timezone` = `America/New_York`
- `user.github` = `alex-rivera`
- `user.email_signature` = `Alex Rivera | Senior PM, Acme`
- `user.company` = `Acme Corp`

### assistant
- `assistant.name` = `Atlas`
- `assistant.role` = `Research Companion`
- `assistant.vibe` = `Curious and methodical — like a research partner who's read the field deeply and helps you build on it.`
- `assistant.emoji` = `📚`

### setup_completed
- `setup_completed` = `2026-XX-XX`  ← used by /bootstrap as the re-run gate (T2)
```

---

## What each field controls

| Field | Used by | Example value |
|-------|---------|---------------|
| `workspace.root` | All skills resolve `<workspace.root>` to this when reading paths | `workspace` (default), `brain`, `<assistant>-workspace`, `vault` |
| `workspace.inbox` / `projects` / `coding` / `resources` / `archive` | Skills resolve `<workspace.inbox>` etc. — almost never changed from defaults | `0-Inbox`, `1-Projects`, `2-Coding`, `3-Resources`, `4-Archive` |
| `templates.persona` | `/bootstrap` reads from this folder for SOUL/USER/IDENTITY templates | `persona/` (default; lives at `<workspace.root>/<workspace.resources>/templates/persona/`) |
| `indexes.code_projects` | `/new-project` (code-repo branch) appends rows here; `/sync-indexes` audits drift | `<workspace.root>/<workspace.resources>/code-projects.md` |
| `scripts.project_query` | `/briefing`, `/prune-projects`, root CLAUDE.md docs reference this for live project list | `<workspace.root>/<workspace.resources>/templates/project-query.sh` |
| `user.name` | Display name in scaffolds, signatures, voice ("Morning <user.name>!") | `Alex`, `Riley`, `Sam` |
| `user.full_name` | Full legal/display name (e.g., for email signature variants) | `Alex Rivera`, `Riley T. Chen` |
| `user.email` | Used in some skill prompts to identify the user; not auto-sent anywhere | `alex.rivera@example.com` |
| `user.timezone` | `/briefing` calendar agenda; `/find` recency weighting | `America/Los_Angeles`, `America/New_York`, `Europe/London` |
| `user.github` | `/new-project` code-repo branch: `gh repo create <user.github>/<name> --private` | `alex-rivera`, `r-chen` |
| `user.email_signature` | Used by skills that draft outbound emails | `Alex Rivera \| Senior PM, Acme Corp`, `Riley Chen \| Engineering Lead` |
| `user.company` | Surfaced in briefings, contact filtering ("status: external" = not at company) | `Acme Corp`, `Globex`, `Anthropic` |
| `assistant.name` | Persona name — pick anything you like; referenced everywhere in skills via `<assistant.name>` | `Atlas`, `Echo`, `Pierre`, `Cortex`, `Sage` |
| `assistant.role` | Short role descriptor (used in SOUL.md, IDENTITY.md, voice cues) | `Chief of Staff`, `Research Companion`, `Engineering Co-Pilot` |
| `assistant.vibe` | One-line voice/tone descriptor used in SOUL.md and persona regeneration | `Professional but warm — like an exec assistant who's been with you for years`, `Curious and methodical — like a research partner` |
| `assistant.emoji` | Used in greetings, output headers, status indicators | `🎯`, `📚`, `⚙️`, `🧠` |
| `setup_completed` | Date `/bootstrap` ran successfully — re-run gate (T2) | `2026-05-06` |

---

## When you don't run `/bootstrap`

If you prefer to manually configure (skipping the smoke test, persona regeneration, etc.):

1. Edit the Configuration section in `CLAUDE.md` with your values
2. Edit `SOUL.md`, `USER.md`, `IDENTITY.md`, `README.md`, `TOOLS.md` directly to fill in your `<assistant.name>` and `<user.name>` everywhere
3. Create the workspace folder skeleton via `mkdir -p <workspace.root>/{0-Inbox,1-Projects,2-Coding,3-Resources/{templates,research,reference,meetings,contacts,design-systems,onboarding},4-Archive}` (2-Coding is flat — one folder per repo, no work/personal/forks/archive sub-tree)
4. Copy templates to make them available: `cp -r workspace/3-Resources/templates/persona <workspace.root>/3-Resources/templates/`

The skills will work either way — they only depend on the Configuration section being filled in correctly.

---

## Re-running `/bootstrap`

By default, `/bootstrap` refuses to run if `setup_completed` is set (T2 invariant — protects against accidental data loss). To genuinely redo setup:

```
/bootstrap --reconfigure
```

Even with `--reconfigure`, T1 still applies — persona files with user edits will prompt for confirmation before overwriting.
