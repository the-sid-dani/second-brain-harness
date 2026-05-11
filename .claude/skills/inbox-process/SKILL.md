---
name: inbox-process
description: Friday-batch triage of `<workspace.root>/<workspace.inbox>/` AND of unmigrated `<workspace.root>/<workspace.projects>/*/` folders (those missing `CLAUDE.md` — i.e., placed in Projects without scaffolding). Iterates every candidate (file or folder), shows the user a preview, asks disposition via `AskUserQuestion`: **promote** (chains to `/save-resource`), **project** (chains to `/new-project` with the content as initial material), **scaffold-in-place** (only for unmigrated 1-Projects/ items — keeps the existing folder, just adds CLAUDE.md + memory.md), **move-to-coding** (only for items that are actually code repos — moves to `<workspace.coding>/<scope>/`), **move-to-inbox** (only for items currently misplaced in 1-Projects/ — moves back to `<workspace.inbox>/`), **archive** (moves to `<workspace.archive>/inbox-<YYYY-MM-DD>/`), **delete** (with confirm), or **keep** (skip). Sister skill to `/prune-projects` (which reviews scaffolded-and-stale Projects). All paths come from the Configuration section in root CLAUDE.md — read those first. Use this whenever the user wants to clean up Inbox or surface unmigrated project debris — phrases like "process inbox", "Friday inbox review", "what's in inbox?", "clear my inbox", "triage inbox", "what's unmigrated?", "find folders without CLAUDE.md", "/inbox-process". Trigger broadly on clean-up / triage / review / Friday language. Closes both: the Inbox→Resources flow (prevents 0-Inbox graveyarding, research §2 constraint #1) AND the 1-Projects/ unmigrated-debris flow (folders dropped in without scaffolding, the workflow defect surfaced 2026-05-06).
---

# inbox-process

Friday triage of `<workspace.inbox>/` AND unmigrated `<workspace.projects>/*/` folders. Iterate candidates, ask disposition per item, dispatch each to the right downstream skill — `/save-resource` (promote), `/new-project` (turn into project), or move/scaffold/archive. Sister to `/prune-projects` for scaffolded-and-stale Projects.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.inbox>` resolve to whatever's defined there.

## Why this exists

Two graveyard surfaces share the same triage shape:

1. **`0-Inbox/`** — capture zone. Items land fast (drag-drop, Drive download, paste). Without periodic triage, it graveyards. Research (§2 constraint #1) is unambiguous: surviving systems either skip Inbox entirely or have a discipline for clearing it. `<user.name>` kept Inbox per their README, so we need the discipline as a skill.

2. **Unmigrated `1-Projects/<slug>/` folders** (those missing `CLAUDE.md`) — folders placed in Projects without going through `/new-project`. Same disease: stuff dropped into the wrong location, never properly scaffolded, slowly accumulating. The workflow defect surfaced 2026-05-06 (9 of 12 Projects folders had no CLAUDE.md). Per SOUL Operating Principle "Capture before commit," these belonged in `0-Inbox/` until a deliberate decision to promote them — but absent a triage flow, they sat in `1-Projects/` unscaffolded.

Both surfaces have identical triage flow: list candidates, ask disposition, act. So `/inbox-process` covers both — its scope is "anything that needs to be moved to its right home." `/prune-projects` handles the *next* lifecycle stage (scaffolded projects that have gone stale).

`/save-resource` handles individual save-this-now operations. `/inbox-process` is the **iteration wrapper** that goes through everything weekly across both surfaces.

## When to use

Trigger phrases (broad — over-trigger rather than miss):
- "process inbox" / "process my inbox"
- "Friday inbox review" / "Friday inbox" / "Friday cleanup"
- "what's in inbox?" / "what's in my inbox?"
- "clear my inbox" / "clean up inbox"
- "triage inbox" / "go through inbox"
- "inbox-process" / "/inbox-process"

Do NOT trigger for:
- A specific known item the user wants saved now ("save 0-Inbox/X to research") → use `/save-resource` directly
- Projects pruning (status review of `1-Projects/`) → that's `/prune-projects`
- Outputs <assistant.name> generates (briefings, prep docs) — those go to `docs/`, not Inbox

## Process

### Step 1: List candidates from BOTH surfaces

**Surface A — Inbox items:**
```bash
ls -1tr <workspace.root>/<workspace.inbox>/    # oldest first
```

**Surface B — unmigrated `1-Projects/` folders** (those missing `CLAUDE.md`):
```bash
for d in <workspace.root>/<workspace.projects>/*/; do
  [ -d "$d" ] && [ ! -f "$d/CLAUDE.md" ] && echo "$d"
done
```

Tag each candidate with its source surface so the disposition step can offer the right options. Inbox items get the standard 5-option set; unmigrated `1-Projects/` items get an extended 7-option set (scaffold-in-place + move-to-coding + move-to-inbox added — they're already in Projects, so the dispositions differ).

If both surfaces empty:
```
Inbox is empty AND every 1-Projects/ folder has CLAUDE.md. ✨ Nothing to process.
```
…and stop.

### Step 2: Show the user the candidates

Print one numbered table per surface (or merged with surface column — your call based on volume):

```
=== 0-Inbox/ — N items (oldest → newest) ===

  1. <item-name>     <YYYY-MM-DD>   <size>   <preview>
  2. <item-name>     <YYYY-MM-DD>   <size>   <preview>
  ...

=== 1-Projects/ — M unmigrated folders (no CLAUDE.md) ===

  1. <folder-name>   <last-mtime>   <N items inside>   <preview>
  2. <folder-name>   <last-mtime>   <N items inside>   <preview>
  ...
```

**Preview** depends on the item:
- `.md` / `.txt` files → first non-empty line of the file (`head -n 5 | grep -v '^$' | head -1`)
- Folders → top-3 file/subdir names (e.g., `README.md, plan.md, mockups/`) so the user can guess content type
- Other files → just the file extension

This helps the user decide quickly without opening each file.

### Step 3: Iterate — ask disposition per item, then act

For each candidate, in oldest-first order (interleave both surfaces by mtime, OR finish Inbox surface first then 1-Projects surface — your call based on volume):

```
[Inbox] Item N of M: <item-name> (<YYYY-MM-DD>, <size>)
Preview: <preview>
```

OR

```
[1-Projects unmigrated] Item N of M: <folder-name> (last-mtime <YYYY-MM-DD>, <N items inside>)
Preview: <preview>
```

**For Inbox items**, use `AskUserQuestion` with the standard 5 choices:
- `promote` — file this in Resources (chains to `/save-resource`)
- `project` — turn this into a project (chains to `/new-project`, treats inbox content as initial material)
- `archive` — move to `<workspace.archive>/inbox-<today>/` (kept but out of the way)
- `delete` — gone (will ask to confirm)
- `keep` — leave in Inbox (skip for now)

**For unmigrated `1-Projects/` folders**, use `AskUserQuestion` with the extended 7-choice set:
- `scaffold-in-place` — keep the folder where it is, just add `CLAUDE.md` + `memory.md` (chains to a minimal `/new-project`-equivalent that scaffolds in the existing path; asks for type to populate frontmatter)
- `move-to-coding` — this is actually a code repo; move to `<workspace.root>/<workspace.coding>/<scope>/<name>/` (asks for scope: work/personal/forks). Also append a row to `<indexes.code_projects>`.
- `move-to-inbox` — wasn't actually project-scoped, demote back to `<workspace.inbox>/<folder-name>/` so it can be triaged like a normal Inbox item next pass
- `promote` — turn into Resources (chains to `/save-resource`); use when the folder is reference material, not a project (e.g., a Confluence dump, a research dump)
- `archive` — move to `<workspace.archive>/<folder-name>/` (no `inbox-<date>/` bucket since the folder already has a meaningful name)
- `delete` — gone (will ask to confirm)
- `keep` — leave it as-is in `1-Projects/` (skip for now — comes back next triage)

**Sequence: ask → act → next.** Don't batch all questions then act. The reason: `project` / `promote` / `scaffold-in-place` / `move-to-coding` chain into other skills which themselves ask questions; interleaving keeps each item's flow coherent.

### Step 4: Execute disposition

#### promote (both surfaces)
Invoke `/save-resource` via the `Skill` tool, passing the source path. For Inbox: `<workspace.inbox>/<item>`. For unmigrated 1-Projects: `<workspace.projects>/<folder>`. `/save-resource` handles the rest (asks for type, topic, filename, confirms, moves). It will move the source out of its origin location automatically when done.

#### project (Inbox surface only)
Invoke `/new-project` via the `Skill` tool. After the project is scaffolded at `<workspace.projects>/YYYY-MM-<slug>/`:

```bash
mv <workspace.inbox>/<item> <workspace.projects>/YYYY-MM-<slug>/<item-name>
```

The inbox content becomes the initial material in the new project's root. The user's `/new-project` answers (name, type) drive the slug; we just need the resulting path to do the final `mv`.

#### scaffold-in-place (1-Projects surface only)
The folder already lives at `<workspace.projects>/<folder-name>/` — just add the missing scaffold without moving it. Steps:

1. Ask the user via `AskUserQuestion` for project type (same choices as `/new-project` Step 2: design / research / execution / content / meeting / ongoing).
2. Read template at `<workspace.root>/<workspace.resources>/<templates.project_claude>` and write `<workspace.projects>/<folder-name>/CLAUDE.md` with frontmatter:
   - `status: active`
   - `created: <today YYYY-MM-DD>`
   - `project-type: <chosen type>`
   - `stakeholders: [<user.name>]`
3. Read template at `<workspace.root>/<workspace.resources>/<templates.project_memory>` and write `<workspace.projects>/<folder-name>/memory.md` with an initial entry:
   ```markdown
   ## YYYY-MM-DD — Scaffolded retroactively
   Decision: Folder pre-existed without CLAUDE.md. Triaged via `/inbox-process` and scaffolded in place.
   Why: <leave blank for user>
   Next: <leave blank>
   ```
4. Confirm to user: `✅ Scaffolded in place: <path>. CLAUDE.md + memory.md added.`

Don't `mv` the folder. Don't rename it. Existing content untouched.

#### move-to-coding (1-Projects surface only)
The folder is actually a code repo misplaced in `1-Projects/`. Steps:

1. Ask the user via `AskUserQuestion` for scope: `work` / `personal` / `forks`.
2. Compute target: `<workspace.root>/<workspace.coding>/<scope>/<folder-name>/`.
3. Validate target doesn't exist already. If it does, surface conflict and ask user for a different name.
4. `mv <workspace.projects>/<folder-name> <workspace.root>/<workspace.coding>/<scope>/<folder-name>`
5. If the folder doesn't already have a `.git/`, optionally offer to `git init` (skip for now if the user says no — they can do it later).
6. Append a row to `<indexes.code_projects>`:
   ```
   | <folder-name> | <workspace.root>/<workspace.coding>/<scope>/<folder-name> | TBD | active | no-remote | (migrated from 1-Projects 2026-MM-DD) | <today> |
   ```
7. Confirm to user: `✅ Moved to <workspace.coding>/<scope>/<folder-name>/. Index updated. Heads up: <workspace.coding>/ is gitignored; this folder is now invisible to outer git.`

#### move-to-inbox (1-Projects surface only)
The folder wasn't project-scoped — demote back to Inbox for normal triage.

```bash
mv <workspace.projects>/<folder-name> <workspace.inbox>/<folder-name>
```

That's it. Next `/inbox-process` run picks it up as a regular Inbox item.

#### archive (both surfaces, slightly different)
**For Inbox items** — bucketed by date (multiple Inbox items on same triage day group):
```bash
bucket="<workspace.root>/<workspace.archive>/inbox-$(date +%Y-%m-%d)"
mkdir -p "$bucket"
mv "<workspace.inbox>/<item>" "$bucket/"
```

**For 1-Projects unmigrated folders** — keep folder name (it's already meaningful), no bucket:
```bash
mv "<workspace.projects>/<folder-name>" "<workspace.root>/<workspace.archive>/<folder-name>/"
```

After the move, optionally scaffold a minimal CLAUDE.md inside the archive folder with `status: done` so the retro-archive looks like a properly-archived project (matches the convention `/archive-project` produces). Same template as scaffold-in-place but with `status: done` and `completed: <today>`. Optional — skip if you want the move to be the only mutation.

#### delete (both surfaces)
**Confirm before deleting**:

```
AskUserQuestion: "Permanently delete <item>? This cannot be undone."
   Choices: yes / cancel
```

If `yes`: `rm -rf <path>` (folders need `-r`).
If `cancel`: skip — treat as "keep" for this run.

The double-confirmation is intentional. Inbox/Projects loss is real loss; it has no recycle bin behind it.

#### keep (both surfaces)
Do nothing. Item stays where it is. Move to next.

### Step 5: Failure handling

If a chained skill fails (e.g., `/save-resource` errors mid-flow), capture the error, log it, **continue with the next item**. Don't abort the whole triage on one bad disposition — `<user.name>` will be partway through and want to finish. Surface failures in the Step 6 summary.

### Step 6: Summary

After the loop, print:

```
✅ Triage complete: <N> Inbox items + <M> unmigrated 1-Projects/ folders processed.

Inbox dispositions:
  Promoted to Resources:  K   (saved via /save-resource)
  Made into projects:     L   (scaffolded via /new-project)
  Archived:               M
  Deleted:                P
  Kept in Inbox:          Q

1-Projects/ unmigrated dispositions:
  Scaffolded in place:    A   (CLAUDE.md + memory.md added at existing path)
  Moved to 2-Coding/:     B   (with index row appended)
  Demoted to Inbox:       C   (will re-triage next pass)
  Promoted to Resources:  D
  Archived:               E
  Deleted:                F
  Kept (skipped):         G

Failed:                   R   <list each error: item, disposition, why>

Inbox now has Q items. 1-Projects/ now has G unmigrated folders.
Next Friday review: <next Friday's date>.
```

Compute next Friday relative to today (a date in the future, suggesting cadence without enforcing a cron).

If everything was kept (all action counters 0):
```
Nothing dispatched. State unchanged.
```

If both surfaces clear post-triage (Q=0 AND G=0):
```
Inbox cleared, 1-Projects/ fully scaffolded. ✨
```

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Both surfaces empty when invoked | Nothing to triage | Friendly message, stop. Step 1 handles. |
| `/save-resource` chained call fails mid-batch | Source already moved, type unclear, etc. | Log, continue, surface in summary |
| `/new-project` chained call fails | Name collision, slug error | Log, continue. Source stays put for next time. |
| `move-to-coding` target already exists | Same repo name in `<workspace.coding>/<scope>/` | Surface conflict, ask for different name OR ask to merge manually |
| `scaffold-in-place` overwrites existing CLAUDE.md | Race — folder gained CLAUDE.md between Step 1 scan and Step 4 act | Re-check before write; if CLAUDE.md now exists, skip scaffold and treat as "keep" |
| User picks `delete` on everything | Possibly accidental | Each delete still requires its own confirm — that's the safety net. Trust the user after explicit confirmation. |
| `AskUserQuestion` not available (subagent context) | Worker subagents lack the tool | Pre-extract dispositions from invocation prompt. Treat the prompt as authoritative ("promote X to research, archive Y, scaffold-in-place Z as execution"). |
| Configuration values missing | Fresh fork | Error: tell user to run `/bootstrap` (TBD) or fill in Configuration manually first. |
| 1-Projects scan misses a folder that has an unrelated CLAUDE.md | Some legacy folder might have a `CLAUDE.md` that's not a real scaffold | Acceptable false-negative. The scan is "missing CLAUDE.md ⇒ unmigrated" — folders with CLAUDE.md are assumed scaffolded. If the user wants to re-scaffold one, they can `rm` its CLAUDE.md and re-run, OR use a future `/retro-project` skill. |

## Output format

Standard summary block (Step 6). Include the "Next Friday review:" line as a soft cadence prompt — it makes the weekly rhythm visible without requiring a cron.
