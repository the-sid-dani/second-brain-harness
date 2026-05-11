---
name: sync-indexes
description: Repairs drift between the on-disk state of `<workspace.root>/<workspace.coding>/{work,personal,forks,archive}/` and `<indexes.code_projects>` (the canonical code-repos index file). Scans the actual code folders, parses the index, computes a three-way diff (repos present on disk but missing from index → propose ADD; rows in index but folder gone from disk → propose FLAG/remove; matches → ok), shows the diff to the user via `AskUserQuestion`, applies only the approved changes. Read-only by default; mutates `<indexes.code_projects>` only after explicit approval. Use this whenever the user wants to audit code-repo bookkeeping — phrases like "sync indexes", "repair code-projects", "check for orphan repos", "what's in 2-Coding that's not in the index", "audit code repos", "is my index up to date?", "/sync-indexes". Trigger broadly on audit/sync/drift/orphan language about code repos. The index matters because `<workspace.coding>/` is gitignored — without a maintained index, no fork-portable record of what code lives where exists. Sister skill to `/prune-projects` (same iterator-multiselect-act shape, different domain).
allowed-tools: Read Edit Bash AskUserQuestion
---

# sync-indexes

Repair drift in `<indexes.code_projects>`. The code folder (`<workspace.root>/<workspace.coding>/`) is gitignored, so the index file is the only fork-portable record of what repos exist. Without periodic sync, reality and the index diverge — repos get manually `mv`'d in, repos get deleted, and the index goes stale.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.coding>` and `<indexes.code_projects>` resolve to whatever's defined there — never hardcode.

## Why this exists

The code index is the single allowed INDEX file in this workspace (decision #15 exception). It's justified because `<workspace.coding>/` is gitignored and the frontmatter-grep approach used everywhere else (`<scripts.project_query>` over `1-Projects/`) doesn't work for code repos that aren't visible to outer git.

The index is maintained primarily by `/new-project`'s code-repo branch (which appends a row when a code repo is scaffolded). But three things cause drift:
- Repos cloned manually into `<workspace.coding>/` (skipping `/new-project`)
- Repos deleted or moved without updating the index
- Repos archived, where status field never gets flipped

This skill does the *detection* — fast, deterministic, scriptable — and the user does the *judgment* in one multiselect. Same shape as `/prune-projects`. Read-only by default; only mutates the index after explicit approval.

## When to use

Trigger phrases (intentionally broad):
- "sync indexes" / "repair code-projects" / "audit code repos"
- "check for orphan repos" / "what's in 2-Coding that's not in the index?"
- "is my index up to date?" / "any code repos drifting?"
- "what code repos do i have?" — if the user is asking from doubt rather than certainty
- "/sync-indexes"

Do NOT trigger for:
- Adding a SPECIFIC new code repo — use `/new-project` with `code-repo` type. That handles the index row append correctly.
- Meta-projects (under `<workspace.projects>/`) — those use frontmatter, not an index. `<scripts.project_query>` is the right tool.
- Reading the index — just `cat <indexes.code_projects>` or open it.

## Process

### Step 1: Scan disk

For each scope under `<workspace.root>/<workspace.coding>/`:

```bash
for scope in work personal forks archive; do
  ls -1 "<workspace.root>/<workspace.coding>/$scope/" 2>/dev/null
done
```

Collect every direct subdirectory. The result is a set of `(scope, repo_name)` pairs. Each represents a code repo on disk. Skip:
- Hidden entries (starting with `.`)
- Files (only directories count as repos)

If `<workspace.coding>/` doesn't exist, abort: *"Coding directory not found at `<workspace.root>/<workspace.coding>/`. Either nothing's been migrated yet, or the path is wrong — check root CLAUDE.md Configuration."*

### Step 2: Parse the index

Read `<indexes.code_projects>`. The schema is a markdown table with header:

```
| Repo | Path | Stack | Status | GitHub | Brief | Last touched |
```

Skip the header row and the separator row (`|------|...`). For each remaining row, extract:
- `repo` (column 1, trimmed)
- `path` (column 2, trimmed) — should be like `<workspace.coding>/<scope>/<repo_name>` or `2-Coding/<scope>/<repo_name>` (legacy)
- `status` (column 4) — `active`, `paused`, `archived`, `MISSING`, etc.

Build a map: `index_paths[<scope>/<repo_name>] = full_row`.

If the index file is missing or has only the header (no data rows), that's a valid "fresh state" — proceed with empty index map. The skill will propose ADDs for everything on disk.

### Step 3: Compute the diff

Three buckets:

- **ADD candidates** — `(scope, repo_name)` on disk that have no matching `index_paths` entry. The skill will propose adding a row.
- **MISSING candidates** — `index_paths` entries whose folder doesn't exist on disk. The skill will propose flagging the row's status to `MISSING` (or removing it entirely — user choice).
- **MATCH** — entries where disk and index agree. No action needed; just count.

If all three buckets are empty except MATCH, print:

```
✨ Index in sync. <N> code repos tracked, all present on disk.
```

…and stop. No questions, no mutations.

### Step 4: Detect git remotes for ADD candidates (optional enrichment)

For each ADD candidate, try to detect its GitHub remote so the index row can be filled in:

```bash
git -C "<workspace.root>/<workspace.coding>/<scope>/<repo_name>" remote get-url origin 2>/dev/null
```

If a URL is returned, parse it to `owner/repo` form (e.g., `git@github.com:<user.github>/<repo-name>.git` → `<user.github>/<repo-name>`). If no remote (or the dir isn't a git repo), leave the GitHub field as `(needs review)`.

Also detect last-commit date for the "Last touched" field:

```bash
git -C "<path>" log -1 --format=%cs 2>/dev/null
```

If not a git repo, fall back to filesystem mtime:

```bash
date -r "<path>" "+%Y-%m-%d"
```

These are best-effort — if the commands fail, just leave fields as `(needs review)`.

### Step 5: Ask which changes to apply

Show the diff and use `AskUserQuestion` with `multiSelect: true`. Each option is one proposed change:

For ADD candidates, label format:
```
ADD: <scope>/<repo_name> · <github-or-(needs review)> · last touched <date>
```

For MISSING candidates, label format:
```
FLAG: <scope>/<repo_name> · status was <old_status>, folder gone
```

Question prompt:
```
Found N changes to <indexes.code_projects>. Pick the ones to apply — uncheck to skip.
```

Default selection: **all pre-selected**. Same reasoning as `/prune-projects` — bookkeeping drift compounds; the safe default leans toward acting.

If the user picks zero, print "Nothing applied. Index unchanged." and stop.

For MISSING items, after the multiselect, ask a follow-up via `AskUserQuestion`:

```
For the N missing-folder rows, choose: (1) flag with status=MISSING (keep row, mark broken),
(2) remove rows entirely (delete from index)
```

Default: flag. Removal is destructive (loses the historical record); flagging preserves it.

### Step 6: Apply approved changes

Mutations to `<indexes.code_projects>`:

**For each approved ADD**, append a new row at the end of the table:
```
| <repo_name> | <workspace.coding>/<scope>/<repo_name> | (needs review) | active | <github> | (needs review) | <date> |
```

The `Stack` and `Brief` fields are `(needs review)` because we can't infer them — the user fills these in later.

**For each approved FLAG (status=MISSING)**, edit the matching row's Status field to `MISSING`. Don't change other columns.

**For each approved REMOVE**, delete the entire row (along with its trailing newline).

Use the `Edit` tool for these — one Edit per change, so the diff is reviewable in commit.

### Step 7: Summary

After all changes apply, print:

```
✅ Sync complete: <indexes.code_projects> updated.

Added (K rows):
  - work/example-repo (github: <user.github>/example-repo)
  - personal/notes-app (github: (needs review))

Flagged MISSING (M rows):
  - personal/old-prototype

Removed (P rows):
  - forks/abandoned-fork

Skipped (Q changes you unchecked):
  - work/private-tool

Now tracked: T total rows in index.
```

Skip empty sections. Always end with the total count so the user has a sanity check.

If the user approved REMOVALS, append a one-line note to today's `memory/<YYYY-MM-DD>.md` (Folder B daily log) — the audit trail matters because removed rows can't be recovered from the index alone.

### Step 8: Suggest manual fill-in

If any new rows have `(needs review)` in Stack or Brief fields, end with:

```
Note: K rows have "(needs review)" in Stack / Brief — open <indexes.code_projects> and fill those in when you have a sec, or invoke /sync-indexes again later (it won't re-prompt for unchanged rows).
```

This nudges follow-through without forcing it. The next sync run treats `(needs review)` as a valid value (no diff), so it doesn't keep flagging the same row.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `<workspace.coding>/` doesn't exist | Fresh fork or path misconfigured | Abort with the resolved path so the user knows what to create or fix |
| `<indexes.code_projects>` doesn't exist | First-run, never created | Treat as empty index — propose ADDs for everything on disk |
| Index has malformed rows (wrong column count) | Manual edit broke the table | Skip the malformed row, surface a warning, continue. Don't auto-rewrite — that's a user judgment call. |
| `git remote get-url` fails | Not a git repo, or no remote | Use `(needs review)` for GitHub field. Best-effort enrichment, never blocks. |
| User unchecks all proposed changes | Audit-only invocation | "Nothing applied. Index unchanged." Exit cleanly. |
| `AskUserQuestion` not available (subagent context) | Worker subagents lack the tool | Treat all detected changes as approved (apply all ADDs, flag all MISSING). Don't remove rows — destructive default is wrong even for automation. |
| Two different repos with the same name in different scopes | e.g., `work/foo/` and `personal/foo/` | Treat them as separate entries. The Path column disambiguates. |
| Configuration values missing | Fresh fork without `/bootstrap` run | Error: *"Configuration section in root CLAUDE.md not populated. Run `/bootstrap` (TBD) or fill it in manually first."* |

## Output format

Standard summary block (see Step 7), then optional fill-in note (Step 8). Keep it tight — this is bookkeeping, not narrative.
