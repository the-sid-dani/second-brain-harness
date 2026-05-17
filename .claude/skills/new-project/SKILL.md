---
name: new-project
description: Scaffolds a new project — either a meta-project (planning, strategy, content, research, meetings) at `<workspace.root>/<workspace.projects>/YYYY-MM-slug/` or a code repo at `<workspace.root>/<workspace.coding>/<name>/` with optional GitHub integration. Use whenever the user wants to start, kick off, scaffold, set up, or create a new project — phrases like "kick off X", "scaffold a project for Y", "set up the QBR prep", "new MCP server for Z", "spin up a repo for W", "create a TypeScript/Python/Rust project". Branches on project type; body has the full taxonomy and Configuration-token resolution.
allowed-tools: Read Write Bash AskUserQuestion Skill
---

# new-project

Scaffolds any new project — <assistant.name> meta-project OR code repo. The two cases share 90% of the logic; the differences (folder location, git init, GitHub repo, index update) live in a single branch on the project-type question.

**Before you begin: read the Configuration section in root CLAUDE.md.** All paths, the user's name, and their GitHub username come from there. Throughout this skill, references like `<workspace.projects>` and `<user.github>` resolve to whatever's defined in that section. Don't hardcode.

## Why this exists

Per-project YAML frontmatter is the source of truth for project discovery (no INDEX file to drift, per system-design.md decision #15). Every new project must start with that frontmatter populated correctly, or `/prune-projects` and frontmatter queries break. Doing this by hand is error-prone — date prefix, status field, project-type enum, template selection, and (for code) GitHub remote setup all need to be right. This skill makes the happy path one command.

Code projects fold into this skill rather than living in a separate `/new-code-project` because the *shape* is the same: a folder with CLAUDE.md + memory.md + status frontmatter. The genuinely-unique parts (folder under `<workspace.coding>/`, `git init`, optional `gh repo create`, append to `<indexes.code_projects>`) are a clean branch off the project-type question, not a whole separate skill.

## When to use

Trigger phrases (intentionally broad — over-trigger rather than miss):
- "let's start a new project on X" / "create a project for X" / "kick off X"
- "scaffold a project for X" / "set up the X work / prep / planning"
- "I want to track X properly" / "make a project to handle X"
- **Code-flavored:** "new MCP server for X", "scaffold a new agent", "spin up a repo for Y", "build a new tool", "new TypeScript/Python/Rust project for Z", "new library", "new CLI tool", "new bot"

Do NOT trigger for:
- Tasks the user wants done *now* without a project folder ("draft an email", "summarize this transcript") — those don't need a scaffold
- Updates to existing projects — append to its memory.md instead
- One-off scripts that don't deserve their own repo — put them in a project's `scripts/` folder, or `<workspace.inbox>/` if nothing owns them yet

## Process

The skill is interactive. Confirm before writing files — the user can correct typos.

### Step 0: Connect before create — `/find` first

**Before any scaffolding, search.** Per SOUL.md Operating Principles ("Connect before create" / "Revive before scaffold" / "Capture before commit"), the second brain's whole purpose is knowing what already exists — AND not promoting half-formed ideas to full project scaffolds.

Run `/find <proposed-slug>` and `/find <topic-keywords>` across `<workspace.root>/<workspace.projects>/`, `<workspace.root>/<workspace.archive>/`, and `<workspace.root>/<workspace.coding>/`. Then ask the user via `AskUserQuestion` — the option set depends on what was found:

**If matches surface:**
```
Found existing work that may match:
  · 1-Projects/2026-01-ai-task-force-execution/  (active, last touched 2026-04-14)
  · 4-Archive/2025-12-old-attempt/                (archived, last touched 2025-12-15)

How do you want to proceed?
  [1] Continue in the active project (open <path>)
  [2] Revive the archived one (mv to 1-Projects/, flip frontmatter status: done → active,
      append "revived: <date> — <reason>" to memory.md)
  [3] Start fresh — this is genuinely a different scope
  [4] Capture to <workspace.inbox>/<slug>/ — uncertain, decide later via /inbox-process
  [5] Cancel — I'll pick the existing path manually
```

**If no matches:**
```
No existing work found for "<topic>".

How do you want to proceed?
  [1] Scaffold a full project now — this is real, scoped work
  [2] Capture to <workspace.inbox>/<slug>/ — uncertain or exploratory, decide later
  [3] Cancel
```

**The "capture to Inbox" branch (option [4] with-matches / [2] without-matches):** create `<workspace.root>/<workspace.inbox>/<slug>/` (or single `<slug>.md` file if the user is capturing a thought, not a folder of material) — NO `CLAUDE.md`, NO frontmatter, NO `memory.md`. Just the slug folder/file with whatever initial content the user has. Then stop. `/inbox-process` (Friday triage) will revisit and either promote to `1-Projects/`, file in `3-Resources/`, or archive. The signal that something belongs in Inbox vs Projects: **uncertainty about whether it's a project at all.** Half-formed ideas, exploratory captures, "I might want to look at this later," generated artifacts (decks/dashboards/reports) without a project owner — all Inbox. Things with a clear scope, deliverables, and commitment to follow through — those earn the `1-Projects/` scaffold.

**Skip Step 0 only when the user explicitly says** *"yes, start a fresh project — I know <topic> exists / I'm sure this is project-scoped"* (already aware, deliberate). Otherwise the `/find` + capture-vs-commit precheck is mandatory. The cost is one /find call (cheap); the benefit is preventing two failure modes: (a) `<topic>-revival` / `<topic>-v2` siblings that fragment lineage, AND (b) the unmigrated-folder graveyard in `1-Projects/` (folders without CLAUDE.md that should have been Inbox captures).

For code-repo branch: `/find` should hit `<workspace.coding>/` to surface existing repos. The `<topic>-revival` anti-pattern applies there too (a code repo + a meta-project tracker for the same code repo are NOT two projects — they're one effort with a code half and a planning half). Code-repos do NOT have a "capture to Inbox" branch — by the time you're scaffolding a code repo, you've committed (it gets its own git, GitHub remote, etc.). Code uncertainty stays in chat or a scratch file.

If the user picks "scaffold full project" (or there were matches and they picked [3] start fresh) → proceed to Step 1. If they picked "capture to Inbox" → execute the capture (mkdir or write file), confirm to user, stop.

### Step 1: Get the project name

`AskUserQuestion` is multi-choice only — don't use it for free text:

1. **Check the invocation context first.** If the user named the thing in the trigger prompt ("let's start a project on the Q3 newsletter" or "scaffold an MCP server for the Anthropic admin API"), extract the name. For code projects, derive a reasonable kebab-case identifier (`anthropic-admin-mcp`).
2. **Otherwise ask in plain chat.** Print the question and wait for the next user message. Don't call `AskUserQuestion` for a free-text response — that creates a stutter (forces "Other → type" pattern).

### Step 2: Ask for the project type

Use `AskUserQuestion` with these choices:

- `design` — system design, architecture, planning meta-work
- `research` — exploratory investigation, deep-dives, literature reviews
- `execution` — operational rollout, project management, delivering an outcome
- `content` — YouTube, writing, talks, decks
- `meeting` — single-meeting prep packages
- `ongoing` — recurring duties (manager 1:1s, office hours, etc.)
- `code-repo` — anything that gets its own git repo (MCP servers, agents, libraries, CLI tools, prototypes)

Why force the choice: this drives folder location, template selection, and downstream lifecycle. An `ongoing` project is never stale at 90 days; an `execution` project usually is; a `code-repo` lives under `<workspace.coding>/` and is gitignored from outer git. Misclassification breaks the lifecycle.

**If type = `code-repo`, branch to Step 2a–2b. Else continue to Step 3 (non-code path).**

`<workspace.coding>/` is flat — one folder per repo, no scope subfolders. (Forks live separately at `<workspace.root>/<workspace.resources>/github-forks/` — they're reference material, not active development.)

### Step 2a (code-repo only): Ask for stack

`AskUserQuestion` with options + Other:

- TypeScript / Node
- Python
- Rust
- Markdown only (for docs / reading-list / reference repos)
- TBD (when the user is exploring and doesn't know yet — agent loops, prototypes, anything that might pivot)
- Other (free text in next chat message)

`TBD` is intentional. Forcing a commitment at scaffold time is wrong for exploratory work. If TBD, write `stack: []` (empty YAML array) and the user fills it in once the repo's purpose firms up.

### Step 2b (code-repo only): GitHub repo?

`AskUserQuestion` with two choices:

- `yes` — create a private GitHub repo under `<user.github>` and push the initial commit
- `no` — local repo only; the user can `gh repo create` later

### Step 3 (non-code only): Compute the date-prefixed slug

Today's date prefix: `date +%Y-%m`. Slugify the name (lowercase, spaces→hyphens, strip non-alphanum-hyphen, collapse hyphens, trim).

```bash
slug=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 -]//g' | tr -s ' ' '-' | sed 's/^-*//;s/-*$//')
date_prefix=$(date +%Y-%m)
folder="<workspace.root>/<workspace.projects>/${date_prefix}-${slug}"
```

For code-repos, **don't** date-prefix the folder — repo names are stable identifiers (and become GitHub identifiers). Use the name as-is, just kebab-case it lightly. Path: `<workspace.root>/<workspace.coding>/<name>/`.

### Step 4: Confirm the path with the user

Show the full plan via `AskUserQuestion` (yes/no), substituting the resolved paths from root CLAUDE.md:

**Non-code:**
```
Will create: <workspace.root>/<workspace.projects>/2026-MM-<slug>/
  Type: <type>
Proceed?
```

**Code-repo:**
```
Will create:
  Path:   <workspace.root>/<workspace.coding>/<name>/
  Stack:  <stack or "TBD">
  GitHub: <github.com/<user.github>/<name> or "local-only">
  Index:  appends to <indexes.code_projects>
Proceed?
```

If no, ask for a corrected name and retry from Step 1.

### Step 5: Validate uniqueness

```bash
[ -d "$folder" ] && error "already exists"
```

Don't auto-rename. Tell the user the path, ask for a different name.

For code-repos, if `<workspace.coding>/` itself is missing (fresh workspace), `mkdir -p` it.

### Step 6: Read the right template

Templates live at `<workspace.root>/<workspace.resources>/templates/`:

| Type | CLAUDE template | Memory template |
|------|-----------------|-----------------|
| Non-code | `<templates.project_claude>` | `<templates.project_memory>` |
| `code-repo` | `<templates.code_claude>` | `<templates.project_memory>` (same) |

Read both with the `Read` tool.

### Step 7: Populate frontmatter and write `CLAUDE.md`

**Non-code substitutions:**
- `status: active`
- `created: <today YYYY-MM-DD>`
- `project-type: <chosen type from Step 2>`
- `stakeholders: [<user.name>]` (default — user can add more later)
- `# <project-slug>` heading replaced with actual slug

**Code-repo substitutions:**
- `status: active`
- `created: <today YYYY-MM-DD>`
- `stack: [<chosen stack>]` (proper YAML array — `[TypeScript, Node]`, `[Python]`, etc.; or empty `[]` if TBD)
- `github: github.com/<user.github>/<name>` if Step 2c = yes, else `github: <none>`
- `deploy: local-only` (placeholder; user edits later)
- `# <repo-name>` heading replaced

Leave the summary, project-specific rules, and key-links/build-test-deploy sections as their template placeholders — the user fills them in as the project grows.

Write to `<folder>/CLAUDE.md`.

### Step 8: Populate `memory.md` and write it

Read the memory template. Replace `<project-slug>` heading with the actual slug.

Append an initial decision-log entry (don't replace the template's example — append a real one):

```markdown
## YYYY-MM-DD — Project created

Decision: Scaffolded project folder via `/new-project` skill. <type or stack summary>.
Why: <leave blank for the user to fill in>
Next: <leave blank>
```

For code-repos, include the stack in the Decision line: *"Stack: Python."*

Write to `<folder>/memory.md`.

### Step 9 (code-repo only): git init + optional gh

```bash
cd <path>
git init -q
git checkout -b main
git add CLAUDE.md memory.md
git commit -q -m "Initial scaffold"
```

If Step 2b was `yes`:
```bash
gh repo create <user.github>/<name> --private --source=. --remote=origin --push
```

If `gh` fails (not installed, not authenticated, network), capture stderr and surface to the user:
> *"`gh repo create` failed: `<stderr>`. Local repo is fine — run the `gh repo create` command manually when ready."*

Don't abort the whole skill on a `gh` failure; the local repo is still useful.

### Step 10 (code-repo only): Update the code-projects index

The index lives at `<indexes.code_projects>` and is the one allowed exception to decision #15's no-INDEX rule (justified — `<workspace.coding>/` is gitignored from outer git, so frontmatter-grep doesn't work there).

If the file is missing, create it with:

```markdown
# Code Projects Index

Single source of truth for code repos. Maintained by `/new-project` (creates row when type=code-repo), `/archive-project` (flips status), and `/sync-indexes` (repairs drift).

| Repo | Path | Stack | Status | GitHub | Brief | Last touched |
|------|------|-------|--------|--------|-------|--------------|
```

Append a new row:

```
| <name> | <workspace.root>/<workspace.coding>/<name> | <stack or "TBD"> | active | <github or "no-remote"> | (scaffold) | <YYYY-MM-DD> |
```

### Step 11: Confirm to user — and tell them to switch context for code-repos

**Non-code message:**

```
✅ Project created: <workspace.root>/<workspace.projects>/2026-MM-<slug>/

Files:
  CLAUDE.md       status: active · type: <type> · stakeholders: [<user.name>]
  memory.md       1 entry (Project created · YYYY-MM-DD)

Next: edit CLAUDE.md to add the one-line summary and any project-specific rules.
```

**Code-repo message — different ending:**

```
✅ Code repo scaffolded: <name>
  Path:   <workspace.root>/<workspace.coding>/<name>/
  Stack:  <stack or "TBD">
  GitHub: <url or "local-only">
  Index:  row appended to <indexes.code_projects>

Heads up: code repos work best when you open them in their own context. Recommended:
  - Open the folder directly in VS Code: `code <workspace.root>/<workspace.coding>/<name>`
  - Or start a fresh Claude Code session inside the repo:
      cd <workspace.root>/<workspace.coding>/<name> && claude

Claude Code's nested CLAUDE.md inheritance means the repo's own CLAUDE.md will auto-load when you work inside it, giving you the right code-flavored context (stack, build commands, key files) without the rest of the workspace getting in the way.

Next: edit CLAUDE.md to fill in build/test/deploy commands and update the Brief column in the index once the purpose firms up.
```

The "switch context" suggestion is real value — code work benefits from the repo being its own working directory, both for Claude Code's context loading and for the developer's own focus.

Stop. Don't auto-open files, don't propose follow-up scaffolding (no `npm init`, `pip install`, boilerplate). The skill creates the structure; the user does the actual coding.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| `mkdir: cannot create directory` | Wrong working directory | Run from the workspace root (where root CLAUDE.md lives). Check with `pwd`. |
| Templates not found | Template files missing under `<workspace.root>/<workspace.resources>/templates/` | Verify before reading; if missing, error and tell the user to restore from git |
| Slug came out empty | Name was all special chars | Re-prompt: "That name didn't slugify cleanly — try one with letters/numbers" |
| Folder exists | Same name was used before | Don't overwrite. Suggest a `-v2` suffix or different name. |
| Code-repo: `gh repo create` fails | Not authenticated / network / GitHub name collision | Surface stderr, suggest manual `gh repo create` |
| Code-repo: `<workspace.coding>/` missing | Fresh workspace or path misconfigured | `mkdir -p` — skeleton isn't load-bearing |
| AskUserQuestion not available | Subagent context | Pre-extract answers from invocation prompt; skip every AskUserQuestion call |
| Configuration values missing | Root CLAUDE.md doesn't have a Configuration section, or this is a fresh fork | Tell the user to run `/bootstrap` (TBD) or fill in the Configuration section by hand. Don't proceed with hardcoded fallbacks — that defeats the portability goal. |

## Output format

Two final-message templates above (Step 11). Use the right one based on whether `code-repo` was selected. Both end with a clear "Next:" line — `/prune-projects` and the UserPromptSubmit hook will scan transcripts for "Project created" / "Code repo scaffolded" patterns.
