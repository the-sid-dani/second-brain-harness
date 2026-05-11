# templates

Scaffold templates and runtime scripts used by skills. **Don't store user content here** — this folder is operational, not editorial.

## Purpose

`templates/` holds the building blocks that skills compose. `/new-project` reads `project-claude-template.md` and `project-memory-template.md`. `/bootstrap` reads from `persona/`. `project-query.sh` is invoked by `/briefing` Step 0 and root `CLAUDE.md`'s "Active Project Index" section.

If you delete or modify files here without updating the skills that reference them, things break in subtle ways. Treat this as operational infrastructure.

## Contents

```
templates/
├── project-claude-template.md       # used by /new-project for non-code projects
├── project-memory-template.md       # used by /new-project — initial memory.md
├── code-project-claude-template.md  # used by /new-project for code repos
├── project-query.sh                 # runtime script for active-project listing
└── persona/                         # used by /bootstrap to regenerate persona files
    ├── README-template.md
    ├── CLAUDE-template.md
    ├── SOUL-template.md
    ├── USER-template.md
    ├── IDENTITY-template.md
    └── TOOLS-template.md
```

## What belongs here

- ✓ Project scaffold templates (CLAUDE.md, memory.md shapes for `/new-project`)
- ✓ Persona templates (re-generated during `/bootstrap`)
- ✓ Runtime scripts skills invoke (like `project-query.sh`)
- ✓ Future: skill scaffolds, hook templates, MCP server templates

## What doesn't belong here

- ✗ Your own reusable templates (proposal one-pager, weekly review format) → `reference/`
- ✗ Code → `<workspace.root>/../2-Coding/<scope>/<name>/`
- ✗ Research notes → `research/`
- ✗ Anything that isn't read by a skill or a system script

## How `<assistant.name>` uses this folder

- **`/new-project`** — reads `project-claude-template.md` / `code-project-claude-template.md` / `project-memory-template.md`, substitutes placeholders, writes to the new project folder
- **`/bootstrap`** — reads `persona/*-template.md`, substitutes identity tokens from Configuration section, optionally writes to root persona files (only if user-edited detection allows — Tiger T1)
- **`/briefing`** Step 0.3 — invokes `project-query.sh` to get the active-projects list
- **Root `CLAUDE.md`** "Active Project Index" section — also invokes `project-query.sh` as the canonical query

## `project-query.sh`

This script greps active-project frontmatter and emits a tab-separated listing of slug / status / type / created / last-touched / staleness-flag. It exists because:
- Hardcoding an active-project list in `CLAUDE.md` would drift
- `git log` doesn't capture status (which is frontmatter, not commit-level)
- A live query is always accurate

Useful flags: `--status all` (also surface unmigrated projects), `--tsv` (machine-readable), `--stale-days 60` (adjust staleness threshold).

If you're authoring a new skill that needs to know about active projects, **invoke this script** rather than re-implementing the grep. Single source of truth.

## Persona templates (`persona/`)

These ship with placeholder tokens (`<user.name>`, `<assistant.name>`, `<workspace.root>`, etc.). During `/bootstrap`, the user picks identity + persona values, and the templates are rendered to the root with substitutions applied. After `/bootstrap` ships the rendered files, the templates remain here for re-runs (via `--reconfigure`) or for future maintenance.

**Tiger invariant T1 from `/bootstrap`**: never overwrite user-edited persona files without explicit confirmation. The detection is `git show HEAD:FILE` vs current — if divergence detected, skip by default and ask before overwriting.

## Conventions

- **Templates use placeholder tokens** — `<user.name>`, `<assistant.name>`, `<workspace.root>`, etc. — that get substituted by the consuming skill
- **Scripts are POSIX-compatible bash** — `#!/usr/bin/env bash` shebang, no zsh-isms
- **Document what reads each template** — when you add a new template, note (in a comment) which skill consumes it. Drift here is silent and breaks things.

## When editing

- **Test against the consuming skill.** Edit `project-claude-template.md`? Run `/new-project test-project` to verify the substitution still produces a valid file.
- **Don't add personal content.** This isn't a place for your favorite proposal format. That goes in `reference/`.
- **Bump version if you change template shape.** If `project-claude-template.md` adds a new required frontmatter field, that's a breaking change for any existing project that doesn't have the field. Document in `CHANGELOG.md`.

## Boundary

`<assistant.name>` reads from this folder constantly but should **not write here** during normal operation. Writes happen during `/bootstrap` (persona template re-render after edits) and when a maintainer (you) updates the templates by hand.
