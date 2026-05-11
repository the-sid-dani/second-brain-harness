---
name: create-handoff
description: Create handoff document for transferring work to another session
user-invocable: true
---

## Step 0 — Resolve storage roots

Two roots, both walked-up from CWD:

**state_root** (for `continuum/autonomous/`, `continuum/research/`, `thoughts/shared/plans/`, `thoughts/shared/research/` — project work artifacts):
1. If CWD is inside `<workspace.root>/<workspace.projects>/<slug>/` → `state_root = <workspace.root>/<workspace.projects>/<slug>/`
2. If CWD is inside `<workspace.root>/<workspace.coding>/<scope>/<name>/` → `state_root = <workspace.root>/<workspace.coding>/<scope>/<name>/`
3. If CWD has a `CLAUDE.md` or `.git/` but no parent workspace match → `state_root = <repo_root>` (standalone repo / original CCv4 mode)
4. None of the above → `AskUserQuestion`: "No project context detected. Which project should this run in?" Never silently fall back.

**handoff_root** (for `handoffs/`, `library/` — session metadata):
- If `<workspace.resources>` is defined in CLAUDE.md Configuration AND `<workspace.root>/` exists as a directory on disk → `handoff_root = <workspace.root>/<workspace.resources>/` (multi-project / workspace mode — handoffs pool workspace-wide)
- Else → `handoff_root = <state_root>/thoughts/shared/` (single-project mode — original CCv4 behavior, no workspace)
- If `<handoff_root>/` subfolder doesn't exist yet → create on first write (`mkdir -p` semantic).

Use `<state_root>/continuum/...` and `<handoff_root>/handoffs/{session-name}/...` in place of any relative paths in the rest of this skill.

---

Handoffs transfer mental model to fresh sessions. Cardinal sin: forcing next instance to re-discover what you know.

First determine session folder from existing handoffs: `ls -td <handoff_root>/handoffs/*/ 2>/dev/null | head -1 | xargs basename`. Returns most recent folder name (e.g., `open-source-release`). Use this name, or `general` if none exist.

Create file at `<handoff_root>/handoffs/{session-name}/YYYY-MM-DD_HH-MM_description.yaml` using today's date/time and brief kebab-case description.

Use EXACTLY this YAML format — `goal:` and `now:` fields appear in statusline and must be named precisely:

```yaml
---
session: {session-name from ledger}
date: YYYY-MM-DD
status: complete|partial|blocked
outcome: SUCCEEDED|PARTIAL_PLUS|PARTIAL_MINUS|FAILED
---

# ── STATUSLINE (REQUIRED — parsed by hooks) ──────────────────────
goal: {What this session accomplished - shown in statusline}
now: {What next session should do first - shown in statusline}
test: {Command to verify this work, e.g., pytest tests/test_foo.py}

# ── MENTAL MODEL (REQUIRED) ──────────────────────────────────────
mental_model: |
  {3-10 lines explaining how the system ACTUALLY works as you discovered
  during this session. Include non-obvious behaviors, execution order, real
  data flow, surprises. Example: "Hook system runs PreToolUse before
  permission checks. Order: PreToolUse hooks → permission check → tool
  execution → PostToolUse hooks. Hooks dir .claude/hooks/dist/ contains
  compiled JS — TS source in .claude/hooks/src/ needs npm run build."}

# ── CODEBASE STATE (REQUIRED) ────────────────────────────────────
codebase_state:
  builds: true|false
  tests_passing: {N}/{total}
  test_command: {e.g., cargo test -p tldr-cli}
  pre_existing_failures: [{any failures NOT from this session}]
  uncommitted_changes: true|false
  branch: {current branch}
  dirty_files: [{modified/staged files relevant to this work}]
  warnings: {known warnings to ignore, or "clean"}

# ── WHAT WAS DONE ────────────────────────────────────────────────
done_this_session:
  - task: {completed task}
    files: [{file1.py}, {file2.py}]
  - task: {second completed task}
    files: [{file3.py}]

# ── DECISIONS (capture WHY) ──────────────────────────────────────
decisions:
  - name: {decision_name}
    chose: {what was chosen}
    over: [{rejected alternatives}]
    because: {actual reason — constraints, user preference, technical}
    constraint: {non-negotiable constraint if any}

# ── FINDINGS (tiered by importance) ──────────────────────────────
findings:
  critical:
    - {thing next instance MUST know or they'll waste time}
  useful:
    - {helpful context that saves time}
  fyi:
    - {nice-to-know background}

# ── APPROACHES ───────────────────────────────────────────────────
worked: [{approaches that worked}]

failed:
  - attempted: {what you tried}
    root_cause: {real reason it didn't work}
    avoid: {what class of approaches to skip}
    use_instead: {what to do instead if known}

# ── TRAJECTORY (include if task evolved) ─────────────────────────
trajectory:
  started_as: {original request/framing}
  evolved_to: {what it became after discussion/discovery}
  scoped_to: {final agreed scope}
  user_approved_scope: true|false

# ── USER INTENT (include when non-obvious) ───────────────────────
user_intent: |
  {Real context behind request. E.g., "Preparing for demo — visual polish
  matters more than architecture" or "Exploring viability — be ready to
  pivot entirely" or "User prefers minimal changes over full refactor."}

# ── HYPOTHESES (REQUIRED when status: partial|blocked) ───────────
hypotheses:
  - status: active|confirmed|ruled_out
    claim: {what you think is happening}
    evidence: [{supporting observations}]
    next_test: {what to try next to confirm/deny}

# ── BLOCKERS & QUESTIONS ─────────────────────────────────────────
blockers: [{blocking issues}]
questions: [{unresolved questions for next session}]

# ── NEXT STEPS ───────────────────────────────────────────────────
next:
  - {specific step with file paths, function names, line numbers}
  - {second step}

# ── NEXT SESSION PROMPT (REQUIRED) ───────────────────────────────
next_session_prompt: |
  {Write as if you're the user talking to fresh Claude instance.
  3-15 lines, direct and specific. Example:

  "Continue implementing CSV export in src/export/csv.rs. Struct
  CsvWriter defined at line 42 but write_row() is stub. Use same
  pattern as JsonWriter in src/export/json.rs:58-90. Tests in
  tests/export_csv.rs — 3 of 7 passing. Remaining 4 need write_row()
  to work. Run `cargo test -p export` to verify. Don't change public
  API — agreed with user in previous session."}

# ── FILE MANIFEST ────────────────────────────────────────────────
files:
  created: [{new files}]
  modified: [{changed files}]
```

**Section Requirements by Status:** `goal:`/`now:`/`mental_model:`/`codebase_state:` always required. `done_this_session:` required unless blocked with no progress. `findings:` required for complete, optional for partial/blocked. `hypotheses:` required for partial/blocked, skip for complete. `trajectory:`/`user_intent:` when non-obvious. `next_session_prompt:` always required.

**Quality Gates:** Mental model test — would fresh instance avoid your first 20 minutes of mistakes? Decision test — could they judge validity if circumstances changed? Dead end test — would they avoid the failure class, not just exact attempt? Intent test — could they continue without clarifying questions? State test — could they start coding in 30 seconds? Prompt test — is next_session_prompt immediately actionable?

**Guidelines:** More information beats less. Be thorough and precise with both high-level objectives and low-level details. Avoid large code blocks — use file:line references like `src/auth.ts:42-68 (validateToken)`. Mental model IS the handoff — everything else is metadata. Be explicit about implicit knowledge.
