---
name: resume-handoff
description: Resume work from handoff document with context analysis and validation
user-invocable: true
---

## Step 0 — Resolve storage roots

Two roots, both walked-up from CWD:

**state_root** (for `continuum/autonomous/`, `continuum/research/`, `thoughts/shared/plans/`, `thoughts/shared/research/` — project work artifacts):
1. If CWD is inside `<workspace.root>/<workspace.projects>/<slug>/` → `state_root = <workspace.root>/<workspace.projects>/<slug>/`
2. If CWD is inside `<workspace.root>/<workspace.coding>/<name>/` → `state_root = <workspace.root>/<workspace.coding>/<name>/`
3. If CWD has a `CLAUDE.md` or `.git/` but no parent workspace match → `state_root = <repo_root>` (standalone repo / original CCv4 mode)
4. None of the above → `AskUserQuestion`: "No project context detected. Which project should this run in?" Never silently fall back.

**handoff_root** (for `handoffs/`, `library/` — session metadata):
- If `<workspace.resources>` is defined in CLAUDE.md Configuration AND `<workspace.root>/` exists as a directory on disk → `handoff_root = <workspace.root>/<workspace.resources>/` (multi-project / workspace mode — handoffs pool workspace-wide)
- Else → `handoff_root = <state_root>/thoughts/shared/` (single-project mode — original CCv4 behavior, no workspace)
- If `<handoff_root>/` subfolder doesn't exist yet → create on first write (`mkdir -p` semantic).

Use `<state_root>/continuum/...` and `<handoff_root>/handoffs/{session-name}/...` in place of any relative paths in the rest of this skill.

---

Resume work from handoff through interactive analysis. Handoffs contain critical context, learnings, next steps from previous sessions requiring full understanding before continuation.

**Parameter Handling:** If handoff path provided, immediately read document and linked research/plans under `<handoff_root>/plans` or `<handoff_root>/research` — no sub-agents for critical files. If ticket number (ENG-XXXX) provided, list `<handoff_root>/handoffs/ENG-XXXX/` contents. Zero files or missing directory: "Can't find handoff, please provide path." One file: proceed. Multiple files: use most recent by YYYY-MM-DD_HH-MM timestamp. No parameters (single-project mode): respond with "I'll help resume from handoff. Which would you like? Tip: /resume_handoff path or /resume_handoff ENG-XXXX"

**No-args workspace-wide discovery:** If no arguments and CWD resolves to multi-project mode (per Step 0), scan `<handoff_root>/handoffs/*/` for the most recent handoff (mtime-sorted), present its session-name + date + summary, then `AskUserQuestion`: "Resume this, or pick a different one?" If user picks "different", list all session folders mtime-sorted with last-handoff date and let user pick. Single-project mode falls through to the prompt above.

**Next Session Prompt Priority:** After reading handoff, check for `next_session_prompt:` field. If exists, present directly: "Previous session left prompt: > {contents} Shall I proceed or adjust approach?" If user approves, execute as-is using rest of handoff for context. Skip analysis steps — they're for handoffs lacking direct prompts.

**Full Analysis (when no next_session_prompt):** Read handoff completely without limit/offset. Spawn focused research tasks verifying current state — gather artifact context from feature docs, implementation plans, research documents mentioned. Wait for ALL sub-tasks before proceeding. Read critical files from learnings and recent changes sections.

**Present Synthesis:** "Analyzed handoff from [date]. Current situation: Original Tasks: [task]: [handoff status] → [current verification]. Key Learnings Validated: [learning with file:line] - [still valid/changed]. Recent Changes Status: [change] - [verified/missing/modified]. Artifacts Reviewed: [doc]: [takeaway]. Recommended Next Actions: [logical steps from handoff]. Potential Issues: [conflicts/regressions]. Shall I proceed with [action] or adjust?"

> **Bridge to project_root:** After reading the handoff YAML, extract the `project_root:` field from frontmatter. If present, treat that path (relative to `repo_root`) as the project context for the rest of resume — look for `continuum/autonomous/` and other state at `<repo_root>/<project_root>/continuum/...`, not at CWD. If absent, fall back to CWD (single-project / pre-split legacy handoffs).

**Resume Autonomous Session:** After presenting synthesis and getting confirmation, check for an existing `/autonomous` session in `<state_root>/continuum/autonomous/`. If one exists with pending milestones, resume it — the handoff provides updated context and mental model, `/autonomous` drives execution. If no autonomous session exists, offer to start one using the handoff's `next:` steps and `next_session_prompt:` as the task specification.

**Validation Approach:** Be thorough — read entire handoff, verify ALL mentioned changes exist, check for regressions/conflicts, read referenced artifacts. Be interactive — present findings before starting, get buy-in on approach, allow course corrections, adapt based on current vs handoff state. Leverage handoff wisdom — pay attention to learnings section, apply documented patterns, avoid mentioned mistakes, build on discovered solutions.

**State Verification:** Never assume handoff state matches current. Verify file references exist, check for breaking changes since handoff, confirm patterns still valid. Handle scenarios: clean continuation (proceed with recommendations), diverged codebase (reconcile differences, adapt plan), incomplete work (complete unfinished first), stale handoff (re-evaluate strategy given major changes).
