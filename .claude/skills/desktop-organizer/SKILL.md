---
name: desktop-organizer
description: Sweep loose files off the Mac Desktop (and optionally ~/Downloads) into the right home inside <workspace.root>. Screenshots and images go to a Resources media folder; anything uncertain goes to the Inbox for later triage. Native Bash only, confirmation-gated, never deletes without asking. Use when <user.name> says "organize my desktop", "clean up my desktop", "mac cleanup", "clean up downloads", "sort my screenshots", "tidy the desktop", or any desktop/downloads file-sweep intent.
---

# Desktop Organizer

## What this does

Sweeps **loose files** off `~/Desktop` (and `~/Downloads` if asked) and routes them into `<workspace.root>/`. It does NOT build a parallel PARA tree on the Desktop — the workspace is the home. Folders on the Desktop are left untouched; only loose files move.

Routing model (locked with <user.name> 2026-05-29):
- **Screenshots + images** → `<workspace.root>/<workspace.resources>/screenshots/`
- **Confidently-typed files** → their real home in the workspace (see routing table)
- **Anything uncertain** → `<workspace.root>/<workspace.inbox>/` (capture-before-commit; triage later via `/inbox-process`)

## Hard rules

1. **Native Bash only.** Use `ls`, `find`, `file`, `mv` via the Bash tool. No "filesystem MCP" — it doesn't exist in this environment and was why the old version was broken.
2. **Files only, never folders.** Top-level folders on the Desktop (`2-Coding`, `3-Resources`, the OS repo folder, etc.) are out of scope — only move loose files.
3. **Confirmation gate before any move.** Always show the full plan and get an explicit yes before running a single `mv`.
4. **Never delete without asking.** Default disposition for junk/old archives is "move to Inbox", not delete. Deletion requires a separate explicit yes per the workspace destructive-ops boundary.
5. **No overwrites.** If a destination file with the same name exists, rename the incoming file with a `-1`/`-2` suffix rather than clobbering.
6. **Resolve paths from Configuration tokens.** `<workspace.root>`, `<workspace.inbox>`, `<workspace.resources>` come from the Configuration section of root `CLAUDE.md`. Don't hardcode the literal workspace folder name.

## Workflow

### Step 1: Scan

```bash
# loose files on Desktop (depth 1, files only)
find ~/Desktop -maxdepth 1 -type f -not -name '.*' -print
```

If <user.name> also asked for Downloads, scan `~/Downloads` the same way. For each file, capture extension, size, and modified date (`ls -la`, `file <path>` when extension is ambiguous).

If zero loose files: report "Desktop's already clean — nothing loose to sweep" and stop. Don't scaffold folders or invent work.

### Step 2: Categorize

| File signal | Destination |
|---|---|
| Images: `.png .jpg .jpeg .gif .heic .webp .tiff`, or name starts with `Screenshot`/`CleanShot`/`Screen Shot` | `<workspace.resources>/screenshots/` |
| Handoff/backup archives (`.zip .tar.gz .tgz`) with a clear project name | `<workspace.inbox>/` (let `/inbox-process` decide final home — don't guess a project) |
| Documents tied to an obvious active project (filename matches a known project slug) | that project folder under `<workspace.projects>/` — but only if the match is unambiguous |
| Anything else / uncertain | `<workspace.inbox>/` |

When unsure, the answer is always Inbox. Don't over-route. A wrong confident move is worse than a correct "I wasn't sure, it's in the Inbox."

### Step 3: Present the plan

Show a table: each file → proposed destination → reason. Group by destination. Call out anything you're routing to Inbox because you weren't sure. Then ask:

> Ready to sweep these? [yes / adjust / cancel]

If `adjust`, take corrections and re-show the plan.

### Step 4: Execute

On `yes`:
1. Create only the destination folders that are actually needed (e.g. `mkdir -p <workspace.resources>/screenshots`) — lazily, never empty scaffolding.
2. `mv` each file. On name collision, suffix `-1`/`-2`.
3. Track moved / skipped / errored. On any `mv` error, log it and continue with the rest.

### Step 5: Report

Write a short report to `<workspace.root>/<workspace.resources>/organization-reports/desktop-org-YYYY-MM-DD.md`:
- Counts (moved, by destination)
- Anything sent to Inbox that needs `/inbox-process`
- Any errors

Then give <user.name> a one-line summary in chat (e.g. "Swept 4 files: 2 screenshots → Resources, 1 backup + 1 unknown → Inbox. Report saved.").

## Boundaries

- Drafts the plan, waits for yes — never moves files autonomously.
- Never touches the OS repo folder's internals or any Desktop folder's contents — loose files only.
- Deletion is opt-in per-file, never batch, never default.
- If a file looks personal/sensitive (names like `passwords`, `.env`, financial docs), flag it and route to Inbox rather than guessing — let <user.name> decide.
