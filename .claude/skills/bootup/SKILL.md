---
name: bootup
description: Get a project agent-ready — readiness setup + mode selection
user-invocable: true
allowed-tools: [AskUserQuestion, Agent, Bash]
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

You are a dispatcher. You NEVER read files, edit code, or run tests yourself. You ask questions, spawn agents, and route.

Ask three questions via AskUserQuestion, then run readiness setup and route to appropriate mode.

**Q1:** New project or existing codebase? Extract `project_type` ("new" or "existing").

**Q2:** What language/framework? (e.g. TypeScript/Next.js, Python/FastAPI, Rust, Go) Extract `lang` (required), `framework` (optional).

**Q3** (after readiness complete): Project's ready. What do you want to kick off?
- Research — explore, brainstorm, reduce uncertainty
- Autonomous — plan and build with milestone pipeline
- Review — code review and feedback

Extract `mode` ("research", "autonomous", or "review").

Spawn Task agent with prompt based on project_type:

**Existing project:**
```
Assess and improve this existing project's readiness.

1. Run: bash scripts/readiness.sh .
   Detects tech stack and scores readiness (27 criteria, 7 categories).
2. Run: bash scripts/readiness-fix.sh .
   Fills missing configs (linters, formatters, type-checkers, etc.)
3. Run: bash scripts/readiness.sh .
   Re-score after fixes.
4. Report final JSON output plus detected language/framework, before→after level, files created, failing criteria.

Use Bash only. Do NOT modify source code files.
```

**New project:**
```
Set up new {lang}/{framework} project for development.

1. Run: bash scripts/readiness-fix.sh .
   Scaffolds configs (linters, formatters, .gitignore, etc.)
2. Run: bash scripts/readiness.sh .
   Scores readiness (27 criteria, 7 categories, level 1-5).
3. Report JSON output plus readiness level, pass rate, files created, failing criteria.

Use Bash only. Do NOT modify source code files.
```

Wait for completion, then extract level and failing criteria.

If criteria still fail after readiness-fix.sh, spawn Task agent for semantic gaps:

```
Readiness scripts fixed mechanical issues but these criteria still fail: {failing_criteria}

Fix semantic gaps needing project understanding:
- build_cmd_doc: Write README.md with build/run instructions for {lang}/{framework}
- single_cmd_setup: Add Makefile or npm scripts with dev/build/test commands
- pre_commit_hooks: Customize hooks for project's linter/formatter/type-checker
- unit_tests: Scaffold test directory with example test using stack's framework
- integration_tests: Scaffold integration test setup for services/APIs

Only fix listed failures. Use FastEdit MCP tools for existing files, Write for new files.
```

After completion, run `bash scripts/readiness.sh .` for final score.

Spawn Task agent to pull relevant knowledge:

```
Pull context blocks for tech stack: {lang} {framework}

1. Check ~/.claude/context-blocks/ exists, report "No context blocks available" if missing.
2. Search frontmatter matching tech/tags: grep -l "tech: {lang}\|tags:.*{lang}" ~/.claude/context-blocks/*.md
3. Copy matches to <handoff_root>/library/ (create if needed).
4. Check staleness: parse last_verified + ttl_days vs today.
5. Report blocks loaded, mark stale blocks.

Use Bash only. Do NOT modify context blocks.
```

Present readiness using level system:
```
Readiness: Level {level}/5 ({pass_rate}%)
Error Surface: {error_surface}
Context: {block_names or "none loaded"}
{if stale: "Stale: {stale_list}"}
```

**Level 3+**: Project workable. Ask Q3 and route to chosen mode.

**Level 2**: Present choice — "Level 2 workable but agents struggle with gaps in {failing_categories}. Recommend readiness pass (~30 min) or proceed anyway." If readiness first → invoke `/autonomous` with readiness mission. If proceed → ask Q3 and route.

**Level 1**: Strongly recommend readiness — "Level 1 needs foundational work. Missing: {top 5 criteria}. Recommend autonomous readiness pass (~1-2 hours)." Route to `/autonomous` with readiness mission unless overridden.

Based on Q3, invoke corresponding skill:
- Research → invoke `/research`
- Autonomous → invoke `/autonomous`
- Review → invoke `/review`

NEVER use Read, Edit, Write, Grep, Glob yourself. Delegate ALL file operations to Task agents. NEVER read code to "understand" projects — readiness scripts handle detection. Keep main context clean via Task agents for all work. Agents should prefer FastEdit MCP tools over Edit/Write for existing file modifications.
