---
description: Swap the active design system at workspace root. Copies a brand from workspace/3-Resources/design-systems/<brand>/DESIGN.md to ./DESIGN.md so all design:* skills pick up the new tokens.
argument-hint: <brand>
allowed-tools: Bash(ls:*), Bash(cp:*), Bash(test:*), Bash(stat:*), Bash(diff:*), Read
---

# /use-design — swap the active design system

The user wants to swap the workspace's active design system to: `$ARGUMENTS`

Library: `workspace/3-Resources/design-systems/`
Active selection: `./DESIGN.md` (workspace root)
Per-project override: `workspace/1-Projects/<slug>/DESIGN.md` takes precedence over root for that project

## Workflow — execute these steps in order

### Step 1 — Validate the argument

Check `$ARGUMENTS`:

- **If empty:** the user invoked `/use-design` with no brand. Skip to Step 2's "list and ask" branch.
- **If contains anything other than letters, digits, hyphens, underscores:** REFUSE. The argument must match `^[a-zA-Z0-9_-]+$`. Anything else (slashes, spaces, shell metacharacters) is rejected — print "Invalid brand name. Brand names must be alphanumeric with hyphens or underscores only." and stop.
- **If valid:** continue to Step 2.

### Step 2 — Resolve the brand

Run: `test -f "workspace/3-Resources/design-systems/$ARGUMENTS/DESIGN.md" && echo FOUND || echo MISSING`

- **If FOUND:** continue to Step 3.
- **If MISSING (or `$ARGUMENTS` was empty):** list available brands and ask the user to pick.
  ```
  Run: ls workspace/3-Resources/design-systems/ | grep -v '^README' | sort
  ```
  Show the list (72 brands). Tell the user: "Brand `$ARGUMENTS` not found. Pick one from the list above and re-run `/use-design <brand>`." Then stop. Do NOT proceed to copy.

### Step 3 — Backup current DESIGN.md (so this swap is reversible)

Run: `test -f DESIGN.md && cp DESIGN.md .DESIGN.md.previous && echo BACKED_UP || echo NO_PREVIOUS`

- This preserves the previously-active brand at `.DESIGN.md.previous` so a fat-fingered swap can be undone with `cp .DESIGN.md.previous DESIGN.md`.
- If no DESIGN.md existed (first-time swap), skip the backup silently.

### Step 4 — Detect what's currently active (for the diff summary)

Read the first 3 lines of the current `DESIGN.md` (if it exists) to extract the brand title (e.g., the `# Title` heading on line 1). Save this as `PREVIOUS_BRAND`. If no DESIGN.md, set to `(none)`.

### Step 5 — Copy the new brand into place

Run: `cp "workspace/3-Resources/design-systems/$ARGUMENTS/DESIGN.md" DESIGN.md`

Then read the first 3 lines of the new `DESIGN.md` to extract the new brand title. Save as `NEW_BRAND`.

### Step 6 — Report the swap

Print to the user:
```
✅ Active design system swapped.

  Was: <PREVIOUS_BRAND>
  Now: <NEW_BRAND>  (from workspace/3-Resources/design-systems/$ARGUMENTS/)

Backup at .DESIGN.md.previous (run `cp .DESIGN.md.previous DESIGN.md` to undo).

All design:* skills will now read this brand. Per-project overrides at
workspace/1-Projects/<slug>/DESIGN.md take precedence over this root file.
```

## Edge cases

- **`/use-design draft`** or **`/use-design placeholder`**: there is no brand by that name in the library; the placeholder/draft DESIGN.md lives only at workspace root. Treat as a missing brand → list-and-ask branch.
- **`/use-design ../etc/passwd`**: blocked at Step 1 by the regex check.
- **Two brands with similar names** (e.g., `linear` vs `linear-app`): the regex permits both; whichever the user typed exactly is what gets copied. If the user mistypes, Step 2's list-and-ask branch surfaces the canonical names.
- **The user is inside a project (cwd is `workspace/1-Projects/<slug>/`)**: this command always operates on the workspace-root DESIGN.md, NOT the project-local one. If the user wants to set a per-project DESIGN.md, they should `cp` manually or run `/use-design <brand>` from workspace root then move the file.

## What this command does NOT do

- Does not git commit the swap (DESIGN.md changes are tracked in git, but commits happen on the user's terms)
- Does not validate the brand DESIGN.md is well-formed (it trusts the library)
- Does not modify any per-project DESIGN.md overrides
- Does not delete `.DESIGN.md.previous` (the backup persists across swaps; only the latest swap's backup is preserved)
