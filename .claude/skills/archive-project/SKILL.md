---
name: archive-project
description: Moves a completed project from `<workspace.root>/<workspace.projects>/<slug>/` to `<workspace.root>/<workspace.archive>/<slug>/` and flips its frontmatter `status: active` → `status: done`. All paths come from the Configuration section in root CLAUDE.md — read those first. Use this whenever the user says they're done with a project, wants to wrap it up, or wants to clean up their active list — phrases like "archive the X project", "I'm done with X", "wrap up X", "move X to archive", "X is finished — clear it out", "shelve X for now". Optional one-paragraph retro gets appended to `memory.md` before the move so the decision context survives. Trigger even when the user doesn't say "archive" explicitly — finishing/wrapping/clearing language for a known project should invoke this skill rather than letting them `mv` by hand (which would skip the status flip and break `/prune-projects` later).
---

# archive-project

Closes the loop on a project: appends a retrospective to `memory.md` (optional but encouraged), flips `status: active → done` in `CLAUDE.md`'s YAML frontmatter, then moves the whole folder to `<workspace.root>/<workspace.archive>/<slug>/`.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.projects>` resolve to whatever's defined there — don't hardcode.

## Why this exists

`/prune-projects` filters on the `status` field. A project that gets moved by hand without the status flip looks `active` forever — <assistant.name> can't tell it's archived. This skill makes the right thing the easy thing: one command, frontmatter and filesystem stay consistent, optional retro captures the "what did we learn" without forcing it.

The retro matters because the project's `memory.md` is the only durable record of the decision history. Once a project is archived, nobody re-reads its memory unless something breaks — so a one-paragraph "what worked / what didn't" entry at the end is high-leverage. But forcing it would make the user skip the skill entirely, which is worse. Make it cheap to opt in.

## When to use

Trigger phrases (not exhaustive):
- "archive the X project"
- "I'm done with X"
- "wrap up X"
- "move X to archive"
- "X is finished — close it out"
- "shelve X for now"
- "clean up the X work"

Do NOT trigger for:
- Code repos under `<workspace.coding>/` — those have their own git lifecycle. Use `/archive-code-project` (TBD) instead.
- Pausing a project — that's a status change to `paused`, not an archive. Edit the frontmatter directly.
- Deleting — never. Archive is move, not delete.

## Process

The skill is interactive. The interactive prompts (`AskUserQuestion`) only fire when the user runs the skill themselves; subagent runs invoke with the answer pre-extracted from the prompt.

### Step 1: Identify the project

`AskUserQuestion` is multi-choice — useful here for picking from a list, not for free text. So:

1. **Check the invocation context first.** If the user named the project in the trigger prompt (e.g., "archive the all-hands-prep project"), extract the slug. Match the substring against `ls <workspace.root>/<workspace.projects>/` — if exactly one folder contains that substring, use it and skip to Step 2 with a confirmation in Step 4. If multiple match, ask to disambiguate.
2. **Otherwise list the projects via `AskUserQuestion`.** Run `ls <workspace.root>/<workspace.projects>/`, present each slug as a choice, plus an "Other" option for typed input. This handles the "I want to archive *something*, show me my options" case.

If the projects folder is empty, error: *"No active projects. Nothing to archive."*

### Step 2: Validate the project is migratable

```bash
proj="<workspace.root>/<workspace.projects>/<slug>"
[ -d "$proj" ] || error "Project doesn't exist."
[ -f "$proj/CLAUDE.md" ] || error "No CLAUDE.md — this project predates the new scaffolding. Run /new-project to migrate it first, or `mv` it manually."
[ -d "<workspace.root>/<workspace.archive>/<slug>" ] && error "Already archived."
```

If any check fails, abort with the specific error message. Don't auto-recover — the user should decide on unmigrated projects (do they want to backfill scaffolding, or just hand-move?).

### Step 3: Ask about the retro

Use `AskUserQuestion` with two choices:
- **yes** — *"Yes, I'll write a one-paragraph retro"*
- **skip** — *"Skip the retro, just move it"*

If `yes`: prompt in plain chat for the retro text. *"What's the retro? One paragraph — what worked, what didn't, what should be different next time."* Wait for the next user message. Don't use `AskUserQuestion` for the text itself (free-form prose doesn't fit multi-choice).

If `skip`: proceed to Step 4 with no retro.

### Step 4: Confirm before mutating

Print the plan and ask for explicit confirmation via `AskUserQuestion` (yes/no), substituting the resolved paths from root CLAUDE.md:

```
Will archive: <workspace.root>/<workspace.projects>/<slug>/
  → <workspace.root>/<workspace.archive>/<slug>/
  Status flip: active → done
  Retro: <YES, one paragraph | SKIP>

Proceed?
```

This is the last bail-out. The user should be able to back out cleanly here.

### Step 5: Append retro (if requested)

Append to `<proj>/memory.md`:

```markdown

---

## <YYYY-MM-DD> — Retro on archive

<retro text from Step 3>
```

Use `>>` redirection or the Edit tool. Keep the `---` separator before the heading — that's the convention from `<templates.project_memory>`. Today's date.

### Step 6: Flip the status field

Edit `<proj>/CLAUDE.md`'s YAML frontmatter. The line looks like:

```
status: active        # active | paused | done
```

Change `active` → `done`, **preserving the inline comment**. The simplest robust pattern is the Edit tool with `old_string: "status: active        # active | paused | done"` and `new_string: "status: done          # active | paused | done"`. If the comment spacing differs, use sed: `sed -i.bak 's/^status: active/status: done/' <proj>/CLAUDE.md && rm <proj>/CLAUDE.md.bak`.

Do not touch any other frontmatter field. Do not strip the comment.

### Step 7: Move the folder

```bash
mv <workspace.root>/<workspace.projects>/<slug>/ <workspace.root>/<workspace.archive>/<slug>/
```

`mv` not `cp+rm` — atomic, preserves mtimes (which `/prune-projects` cares about for archived-recency stats later).

### Step 8: Confirm

Print:

```
✅ Archived: <slug>
  From: <workspace.root>/<workspace.projects>/<slug>/
  To:   <workspace.root>/<workspace.archive>/<slug>/
  Status: active → done
  Retro: <appended | skipped>
```

Stop. Do not auto-commit, do not modify any index file (no INDEX file exists per system-design.md decision #15 — the code-projects.md exception applies only to code repos), do not propose a follow-up project.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `mv: rename failed` | Target already exists in archive | Step 2 should have caught this; if it didn't, name collision happened mid-flow. Abort and tell the user. |
| Status field not changed | Inline comment had different spacing | Fall back to sed: `sed -i.bak 's/^status: active/status: done/' && rm *.bak` |
| Memory.md missing | Pre-existing project lacked one (shouldn't happen with `/new-project` outputs) | Create it with just the retro entry. Or skip retro and move on. |
| User says "wrap up X" but X doesn't exist | Typo or stale memory | Show `ls <workspace.projects>/` as a list and ask to pick the right one |
| `AskUserQuestion` not available (subagent context) | Worker subagents lack the tool | Extract answers from invocation prompt. If retro text is mentioned ("with a retro about Y"), append Y. If "skip retro" or no retro mentioned, skip. |
| Configuration values missing | Root CLAUDE.md doesn't have a Configuration section, or this is a fresh fork | Tell the user to run `/bootstrap` (TBD) or fill in the Configuration section by hand. Don't proceed with hardcoded fallbacks. |

## Output format

Final message after success:

```
✅ Archived: <slug>
  From: <workspace.root>/<workspace.projects>/<slug>/
  To:   <workspace.root>/<workspace.archive>/<slug>/
  Status: active → done
  Retro: <appended | skipped>
```

Use this format consistently — `/prune-projects` and any future audit skill will look for "Archived:" lines in transcripts.
