---
name: sync-indexes
description: Audits drift between `<workspace.root>/<workspace.coding>/` (flat — one folder per repo) and `<indexes.code_projects>` (the canonical code-repos index). Three-way diff — repos on disk missing from index → ADD; rows in index without folder → FLAG/remove. Read-only by default; mutates only after `AskUserQuestion` approval. Use whenever the user wants to audit code-repo bookkeeping — phrases like "sync indexes", "check for orphan repos", "audit code repos", "is my index up to date?", "/sync-indexes". Trigger broadly on audit/drift/orphan language.
allowed-tools: Read Edit Bash AskUserQuestion
---

# sync-indexes

Repair drift in `<indexes.code_projects>`. The code folder (`<workspace.root>/<workspace.coding>/`) is gitignored, so the index file is the only fork-portable record of what repos exist. Without periodic sync, reality and the index diverge — repos get manually `mv`'d in, repos get deleted, and the index goes stale.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.coding>` and `<indexes.code_projects>` resolve to whatever's defined there — never hardcode.

## Why this exists

The code index is the single allowed INDEX file in this workspace — justified because `<workspace.coding>/` is gitignored and the frontmatter-grep approach used everywhere else (`<scripts.project_query>` over `1-Projects/`) doesn't work for code repos that aren't visible to outer git.

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

Scan `<workspace.root>/<workspace.coding>/` for direct subdirectories:

```bash
ls -1 "<workspace.root>/<workspace.coding>/" 2>/dev/null
```

Each direct subdirectory is a code repo. Skip:
- Hidden entries (starting with `.`)
- Files (only directories count as repos)
- `README.md` (the folder README is tracked, not a repo)

The result is a set of `repo_name` values.

If `<workspace.coding>/` doesn't exist, abort: *"Coding directory not found at `<workspace.root>/<workspace.coding>/`. Either nothing's been migrated yet, or the path is wrong — check root CLAUDE.md Configuration."*

### Step 2: Parse the index

Read `<indexes.code_projects>`. The schema is a markdown table with header:

```
| Repo | Path | Stack | Status | GitHub | Brief | Last touched |
```

Skip the header row and the separator row (`|------|...`). For each remaining row, extract:
- `repo` (column 1, trimmed)
- `path` (column 2, trimmed) — should be like `<workspace.coding>/<repo_name>` (or the older `<workspace.coding>/<scope>/<repo_name>` form from before the 2026-05 flatten — treat the last path segment as the repo name)
- `status` (column 4) — `active`, `paused`, `archived`, `MISSING`, etc.

Build a map: `index_repos[<repo_name>] = full_row`.

If the index file is missing or has only the header (no data rows), that's a valid "fresh state" — proceed with empty index map. The skill will propose ADDs for everything on disk.

### Step 3: Compute the diff

Three buckets:

- **ADD candidates** — `repo_name`s on disk that have no matching `index_repos` entry. The skill will propose adding a row.
- **MISSING candidates** — `index_repos` entries whose folder doesn't exist on disk. The skill will propose flagging the row's status to `MISSING` (or removing it entirely — user choice).
- **MATCH** — entries where disk and index agree. No action needed; just count.

If all three buckets are empty except MATCH, print:

```
✨ Index in sync. <N> code repos tracked, all present on disk.
```

…and stop. No questions, no mutations.

### Step 4: Detect git remotes for ADD candidates (optional enrichment)

For each ADD candidate, try to detect its GitHub remote so the index row can be filled in:

```bash
git -C "<workspace.root>/<workspace.coding>/<repo_name>" remote get-url origin 2>/dev/null
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
ADD: <repo_name> · <github-or-(needs review)> · last touched <date>
```

For MISSING candidates, label format:
```
FLAG: <repo_name> · status was <old_status>, folder gone
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
| <repo_name> | <workspace.coding>/<repo_name> | (needs review) | active | <github> | (needs review) | <date> |
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
  - example-repo (github: <user.github>/example-repo)
  - notes-app (github: (needs review))

Flagged MISSING (M rows):
  - old-prototype

Removed (P rows):
  - abandoned-fork

Skipped (Q changes you unchecked):
  - private-tool

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

## Phase 2: shipped manifest sync (added 2026-05-20)

After the code-repos diff completes (success or no-op), prompt the user whether to also audit the shipped artifact manifest:

```
Phase 1 (code repos) complete. Run Phase 2 audit of deployed artifacts?
```

Use `AskUserQuestion` (yes/no). If yes, run the steps below. Otherwise exit normally.

### Step 9: Diff shipped manifest vs live deploys

The shipped manifest at `<workspace.root>/<workspace.resources>/shipped/manifest.json` tracks every URL <user.name> has deployed. It drifts the same way as the code index — deploys made manually via `wrangler`/`gcloud` don't get appended; retired deploys don't get marked.

Audit Cloudflare Pages first (primary, most common). Cloud Run / GCP IAP audit is future work — flag but don't gate.

```bash
# Cloudflare Pages live deploys
wrangler pages project list 2>/dev/null | grep "pages.dev" | awk -F'│' '{print $2}' | tr -d ' '
```

Each value is a `<project>` whose live URL is `https://<project>.pages.dev`.

Parse `manifest.json` (use `node -e` or `jq` if available) to extract entries where `platform == "cloudflare-pages"`. Build a map keyed by `id` (which by convention matches the Cloudflare project name).

Three buckets, same shape as Phase 1:
- **ADD candidates** — Cloudflare projects not in manifest → propose new entry with `needs-review` defaults
- **STALE candidates** — manifest entries with `platform: cloudflare-pages` whose Cloudflare project no longer exists → propose marking `status: retired`
- **MATCH** — both sides agree

For ADD candidates, enrich:
- Inspect the latest deploy via `wrangler pages deployment list --project-name <p>` to get deploy date
- Source path stays `needs-review` (<user.name> knows where it came from, the skill doesn't)

If all three buckets are empty except MATCH:
```
✨ Shipped manifest in sync. <N> live deploys tracked.
```

### Step 10: Approve shipped changes

Same `AskUserQuestion multiSelect: true` flow as Step 5. Each option = one ADD or STALE-mark.

Mutate the manifest via the recorder:
```bash
node <workspace.root>/<workspace.resources>/shipped/record-deploy.mjs \
  --id <project> --title <project> \
  --url https://<project>.pages.dev \
  --platform cloudflare-pages
```

For STALE: edit `manifest.json` directly (Edit tool) to flip `status: live` → `status: retired`. The recorder doesn't support status mutation since the common case is "I just deployed" → live.

### Step 11: Shipped summary

```
Phase 2 — shipped/ manifest sync:
  ADDED: <list>
  MARKED RETIRED: <list>
  Now tracked: T entries (L live, R retired)
```

If user wants to also audit Cloud Run IAP deploys later, defer to future skill version. Flag with:
```
Note: GCP Cloud Run IAP audit not yet implemented in this skill. To audit GCP deploys, run `gcloud run services list --project ai-workflows-459123` manually and reconcile against manifest entries with `platform: cloud-run-iap`.
```

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `<workspace.coding>/` doesn't exist | Fresh fork or path misconfigured | Abort with the resolved path so the user knows what to create or fix |
| `<indexes.code_projects>` doesn't exist | First-run, never created | Treat as empty index — propose ADDs for everything on disk |
| Index has malformed rows (wrong column count) | Manual edit broke the table | Skip the malformed row, surface a warning, continue. Don't auto-rewrite — that's a user judgment call. |
| `git remote get-url` fails | Not a git repo, or no remote | Use `(needs review)` for GitHub field. Best-effort enrichment, never blocks. |
| User unchecks all proposed changes | Audit-only invocation | "Nothing applied. Index unchanged." Exit cleanly. |
| `AskUserQuestion` not available (subagent context) | Worker subagents lack the tool | Treat all detected changes as approved (apply all ADDs, flag all MISSING). Don't remove rows — destructive default is wrong even for automation. |
| Legacy index row uses `<workspace.coding>/<scope>/<repo>` path | Pre-2026-05 row that never got migrated | Match by last path segment (repo name). Surface a one-line note suggesting the user update the path column to the flat form. |
| Configuration values missing | Fresh fork without `/bootstrap` run | Error: *"Configuration section in root CLAUDE.md not populated. Run `/bootstrap` (TBD) or fill it in manually first."* |

## Output format

Standard summary block (see Step 7), then optional fill-in note (Step 8). Keep it tight — this is bookkeeping, not narrative.
