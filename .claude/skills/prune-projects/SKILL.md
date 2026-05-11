---
name: prune-projects
description: Friday-batch staleness review. Runs `<scripts.project_query>`, filters stale projects (active ≥90 days untouched, paused ≥60 days, status=done that slipped through), shows them in an `AskUserQuestion` multiselect with last-memory-entry context, and chains to `/archive-project` for each one the user approves. All paths come from the Configuration section in root CLAUDE.md — read those first. Use this whenever the user wants to clean up their active project list — phrases like "what's stale?", "any stale projects?", "Friday review", "what should I archive?", "prune projects", "what can I clean up?", "review my projects", "anything I should close out?", "what's gone cold?". Trigger even when the user doesn't say "prune" — clean-up / review / staleness language for the project list should invoke this rather than a manual scan. Skips `ongoing`-type projects (recurring duties — never stale).
allowed-tools: Read Bash AskUserQuestion Skill
---

# prune-projects

Friday-cadence cleanup of `<workspace.root>/<workspace.projects>/`. <assistant.name> proposes archive candidates, the user approves in one multiselect, the chain handles the rest.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<scripts.project_query>` and `<workspace.projects>` resolve to whatever's defined there — don't hardcode.

## Why this exists

Active projects rot if nobody triggers cleanup. A pure auto-move on a 90-day timer eats live work — projects in long planning phases look dead. So the design is: <assistant.name> does the *detection* (fast, deterministic, scriptable), the user does the *judgment* (a 30-second multiselect) once a week. No drift, no surprise mass-archives.

The two prerequisites are already shipped:
- `<scripts.project_query>` — outputs the project table with `days` and a `STALE` flag.
- `/archive-project` — handles the per-project archive (status flip + folder move).

This skill is just the orchestration: query → filter → ask → chain.

## When to use

Trigger phrases (intentionally broad):
- "what's stale?"
- "any stale projects?"
- "Friday review" / "Friday cleanup"
- "what should I archive?" / "prune projects"
- "review my projects" / "what can I clean up?"
- "anything I should close out?" / "what's gone cold?"

Do NOT trigger for:
- Archiving a *specific* known project — use `/archive-project` directly.
- Asking about *one* project's status — just read its `CLAUDE.md`.
- Code repos under `<workspace.coding>/` — different lifecycle, separate skill (TBD).

## Process

### Step 1: Run the query

```bash
bash <scripts.project_query> --tsv
```

The TSV output has these columns (tab-separated, no header):
```
slug   status   type   created   touched   days   flag
```

Parse it. If the script errors (missing dir, etc.), abort and tell the user.

### Step 2: Filter stale candidates

A project is a candidate if **any** of these are true:

- `status == "active"` AND `type != "ongoing"` AND `days >= 90`
- `status == "paused"` AND `days >= 60`
- `status == "done"` (any age — these slipped through `/archive-project` somehow and should be archived now)

Always **skip** `type == "ongoing"` — those are recurring duties (1:1s, office hours, etc.) and don't go stale by inactivity.

If zero candidates, print:

```
Nothing stale right now. Active projects look healthy. ✨
```

…and stop. Don't go further; don't ask questions.

### Step 3: Pull last-memory context for each candidate

For each candidate, read `<workspace.root>/<workspace.projects>/<slug>/memory.md` and extract:
- The last `## ` heading (most recent decision)
- The first non-blank line below it (1-line preview)

If `memory.md` is missing, use the literal `(no memory.md)`.

This context goes into the multiselect labels so the user can decide quickly without opening each project.

### Step 4: Ask which to archive

Use `AskUserQuestion` with `multiSelect: true`. Each option is one candidate; the label format is:

```
<slug> · <type> · <days>d · <last memory heading>
```

Question prompt:

```
These N projects look stale. Pick the ones to archive — uncheck any to keep active.
```

Default selection state: all candidates pre-selected. The user is more likely to glance and click *Archive* than to opt-in per project; the safe default leans toward action because a wrongly-archived project is one `mv` to undo, while a missed cleanup persists.

If everything gets unchecked, print:

```
Nothing archived. Everything stays active. ✨
```

…and stop.

### Step 5: Chain to /archive-project per pick

For each approved slug, invoke `/archive-project` via the `Skill` tool. Pass the slug in the args so the chained skill skips its own "which project?" prompt.

**Run sequentially**, not in parallel. The shared archive directory makes parallel `mv` operations a race-condition trap — and we want a clean audit trail of what got archived in what order.

In batch mode, **skip the per-project retro prompt**. Mass-asking 5 retros in a row is annoying; if the user wants a retro for any specific project, they can re-archive it individually later (the skill is idempotent enough — the retro just appends).

Pass to `/archive-project`:
- The slug to archive
- "skip retro" as the retro answer
- "yes" as the confirm answer

If one slug fails (folder already moved, permissions, etc.), capture the error, **continue with the rest of the batch**, and surface the failure in the final summary. Don't let one bad slug abort the whole prune.

### Step 6: Summary

After all chained archives finish, print:

```
✅ Prune complete: archived N, kept K active.

Archived:
  - <slug-1> (was 92d untouched)
  - <slug-2> (was 105d untouched)

Kept active (unchecked):
  - <slug-3>

Failed:
  - <slug-4>: <error message>

Next Friday review: <next-friday-date>
```

Compute the next Friday relative to today. Skip empty sections (no "Failed:" line if nothing failed).

Also mention if the query script flagged any unmigrated projects:

```
Note: M projects in <workspace.projects>/ have no CLAUDE.md and need /new-project scaffolding before they can be tracked.
```

That nudges the user toward closing the migration backlog without auto-acting on it.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Query script not found | `<scripts.project_query>` deleted or moved | Abort with the path the user should restore from git |
| All-archive batch picked | User clicked OK without unchecking | Trust the user — proceed; they can manually `mv` back from archive if regretted |
| `/archive-project` fails on first slug | Skill broken or moved | Abort the batch, surface the error, don't try the rest |
| `/archive-project` fails mid-batch | Per-slug issue (collision, etc.) | Continue, log to the Failed section of summary |
| `AskUserQuestion` not available (subagent context) | Worker subagents lack the tool | Treat all candidates as approved (archive all) — that's the safe default for an automated prune |
| Configuration values missing | Root CLAUDE.md doesn't have a Configuration section, or this is a fresh fork | Tell the user to run `/bootstrap` (TBD) or fill in the Configuration section by hand. Don't proceed with hardcoded fallbacks. |

## Output format

Standard summary block (see Step 6). Include the "Next Friday review:" line as a soft prompt — it makes the cadence visible without requiring a cron.
