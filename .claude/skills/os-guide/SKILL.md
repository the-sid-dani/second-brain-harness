---
name: os-guide
description: OS reference manual — for fork users in their first 30 days AND for Claude Code self-correcting mid-session on an OS-shaped mistake. Routes the question to its canonical source file, reads at runtime, answers with file:line citations. Topics — PARA, Configuration tokens, memory model, contacts schema, tools, lifecycle, design system, locked decisions, capability index, trigger-phrase map, Operating Principles. **Claude SHOULD consult this skill** before answering questions involving OS configuration values, workspace paths, or canonical skill behavior — especially before writing file paths into responses or scaffolding new files. Read-only by default; `/os-guide --sync` is the sole mutation mode and is gated behind explicit user approval. PRECEDENCE — `/bootstrap` for first-run setup; `/find` for topic search across user content; `/contact` for people; `/os-guide` for the OS itself.
allowed-tools: Read Bash Glob Grep AskUserQuestion Edit
---

# os-guide

Runtime-read librarian over the second-brain OS's canonical source files. Answers "how does X work in this OS?" without ever embedding facts that could drift. Every response carries file:line citations.

**Before you begin: read the Configuration section in root `CLAUDE.md`** (lines ~17-58). Path tokens like `<workspace.root>`, `<workspace.projects>`, `<assistant.name>` resolve from there — don't hardcode them in answers.

---

## ⚠️ Meta-instruction (for Claude reading this skill)

**If you are about to give an OS-shaped answer from memory rather than reading the canonical source — STOP and invoke this skill instead.** That includes any answer that contains:

- A workspace path (e.g., `<workspace.root>/...`)
- A Configuration token value (`workspace.projects`, `user.email`, `assistant.name`, etc.)
- A claim about a skill's behavior or scope
- A claim that a tool is or isn't installed
- A schema field (contacts, design systems, project frontmatter)
- A locked decision from `system-design.md` §7

Memory drifts. Canonical files don't. This skill exists to make the latter cheap to consult.

This rule mirrors the contact-no-fabrication discipline in the user's auto-memory (`feedback_contact_scaffolding.md`).

---

## Why this exists

The OS has eight+ canonical sources (`CLAUDE.md`, `README.md`, `SOUL.md`, `USER.md`, `IDENTITY.md`, `TOOLS.md`, `system-design.md`, contacts/`README.md`, plus individual SKILL.md files). Without `/os-guide`, answering "where does X live?" or "what's the rule about Y?" is a manual ritual of `grep` + `cat` + remembering which file owns which topic.

The naive alternative — encoding the answers in a tutorial-style skill body — fails the moment any canonical source drifts. Locked decision #25 in `system-design.md` §7 forbids it: explainer skills MUST be runtime-read librarians, not textbooks. This skill embodies that decision. Reference, don't reproduce (per `SOUL.md` Operating Principles).

Two audiences:
- **Claude Code, self-correcting mid-session** (primary) — about to write a path, a config value, or a skill claim; pauses to verify.
- **Fork users in their first 30 days** (secondary) — figuring out PARA, the Configuration pattern, how to connect a tool, what skills exist.

Designed for the harder Claude-shaped constraint ("cannot hallucinate"); fork users get served as a free side-effect.

---

## When to use

Trigger phrases (broad — the pattern is "OS-shaped explanatory question", not a literal command):

- "what is PARA in this OS?" / "how is PARA set up here?"
- "how do I connect a new tool?" / "how do I add an MCP?" / "how do I connect Slack?"
- "where do briefings go?" / "where does X live?" / "what's the path for Y?"
- "what is `workspace.projects`?" / "what are the Configuration tokens?" / "what does `<workspace.resources>` resolve to?"
- "what skills do I have?" / "what does this OS do?" / "what's the capability index?"
- "which skill creates a project?" / "how do I ask for X?" / "what's the trigger phrase for Y?"
- "how does memory work here?" / "Folder A vs Folder B?"
- "what does the contacts schema look like?" / "what fields does a contact need?"
- "what's the locked decision on X?" / "what did this OS decide about Y?"
- "what are the Operating Principles?" / "what's the rule about duplicate projects?"
- "/os-guide <topic>" / "/os-guide" (interactive prompt for topic)
- "explain the OS" / "remind me how X works here"

**Trigger Claude-self-consult specifically when** the response Claude is about to give includes:
- a path (workspace/project/skill/canonical-source path),
- a Configuration value,
- a claim about a skill,
- a claim about a tool's connection state,
- a schema field.

## Do NOT trigger for

- **Topic-keyed recall over user content** ("do I have anything on Anthropic?", "what did I save about Q1 planning?") — that's `/find`. `/find` searches Resources/Projects/Archive/memory for content the user authored. `/os-guide` does NOT.
- **Entity-keyed recall about a person** ("who is Omar?", "context on Michela") — that's `/contact`.
- **First-run interactive setup on a fresh fork** ("I just cloned this, set me up") — that's `/bootstrap`. `/os-guide` is the post-bootstrap steady-state reference.
- **Action requests** ("create a project", "archive this", "log my interaction with X") — those are the mutation skills (`/new-project`, `/archive-project`, `/contact-log`).
- **Generic theory** (Tiago Forte's PARA framework as a concept, Claude Code as a product, generic productivity systems) — out of scope; refer to external sources. `/os-guide` only answers the *in-this-OS-specifically* version.
- **Live workspace state** ("what projects are active right now?") — that's `project-query.sh`. The skill can point at it but doesn't run it.
- **CLI install instructions** (`brew install gws`, `samba-onboarding` flow) — out of scope; point at the appropriate installer.

---

## Precedence vs neighbor skills

When multiple skills could match the user's phrasing, the priority is:

| Skill | Owns | When this skill wins | When it defers |
|---|---|---|---|
| `/bootstrap` | First-run interactive setup, persona regeneration, Configuration writes | Fresh fork before `setup_completed:` is filled in | After fork is configured |
| `/find` | Topic-keyed recall over user content (Resources, Projects, Archive, memory) — per locked decision #18 | "do I have anything on X" / "find my notes on Y" | OS structural questions ("how does X work in this OS") |
| `/contact` | Per-person entity recall | "who is X" / "context on Y" where X/Y is a name | Anything not-a-person |
| `/os-guide` | OS-meta — config, paths, schema, capability index, locked decisions, trigger-phrase map | "how does X work here" / "what is X in this OS" / "where does X live (structurally)" | User content (defer to `/find`); people (defer to `/contact`); first-run (defer to `/bootstrap`) |

**Composition rule**: `/os-guide` MUST NOT call `/find` recursively for OS-knowledge questions (its canonical source list is hardcoded — see Routing Table below). `/bootstrap` SHOULD reference `/os-guide` in its Step 8 closer for ongoing-manual discovery. `/find` MAY route OS-shaped queries here (one-way; the reverse would loop).

---

## Routing Table — topic → canonical source

This is the librarian's shelves. **Every answer this skill gives MUST cite a row from this table.** If a question doesn't map to any row, the skill responds with the no-canonical-source fallback (see Read Protocol Step 7), never improvises.

### Workspace layout & PARA

| Topic | Canonical source(s) | Notes |
|---|---|---|
| PARA layout (5-folder workspace) | `README.md` §"Project Map" + §"What is PARA in this OS" + locked decision #1 in `system-design.md` §7 | The 5-folder this-OS implementation |
| Mac Desktop PARA (6-folder, distinct) | `USER.md` §"Mac Desktop Layout (PARA)" | **Separate system** — disambiguate from workspace PARA |
| What does NOT belong at root | `README.md` §"What does NOT belong at root" | Explicit anti-pattern list |
| Outputs location (briefings/meeting-prep/etc.) | `README.md` §"Outputs" + `CLAUDE.md` §"Briefing & report outputs" | CLAUDE.md adds `<assistant.name>`-specific deltas |

### Configuration tokens

| Topic | Canonical source(s) | Notes |
|---|---|---|
| All Configuration tokens (`workspace.*`, `user.*`, `assistant.*`, etc.) | `CLAUDE.md` §"Configuration — source of truth for skills" | Auto-loaded every session. Re-read at every invocation; never cache. |
| Forking the workspace | `CLAUDE.md` §"Forking note" + `README.md` §"Forking this repo" + `EXAMPLE-CONFIG.md` | Three sources, intentional redundancy |
| `setup_completed` lifecycle marker | `CLAUDE.md` §"lifecycle" subsection of Configuration | Used by `/bootstrap` as re-run gate |

### Identity & voice

| Topic | Canonical source(s) | Notes |
|---|---|---|
| Assistant persona / voice / boundaries | `SOUL.md` (whole file) | Includes the Operating Principles |
| Operating Principles | `SOUL.md` §"Operating Principles" | 6 principles: Connect-before-create, Eliminate-before-automate, Consolidate-before-duplicate, Reference-don't-reproduce, Capture-before-commit, Boring-is-beautiful |
| User profile | `USER.md` (whole file) | Fork users edit per their own role/team |
| Assistant identity | `IDENTITY.md` | Name, version, origin |

### Memory

| Topic | Canonical source(s) | Notes |
|---|---|---|
| Memory model (Folder A vs Folder B) | `README.md` §"Memory — dual-folder model" | Locked decision #10 in `system-design.md` §7 |
| Daily journal location | `memory/YYYY-MM-DD.md` (append-only) | Cited from `README.md` |
| Writing-style profile | `memory/writing-style.md` | Locked location per decision #10 |
| Learned preferences | `memory/learned-preferences.md` | Locked location per decision #10 |

### Tools & MCPs

| Topic | Canonical source(s) | Notes |
|---|---|---|
| Tool inventory (live state) | `TOOLS.md` (root, auto-loaded) | The ONLY canonical tool source. `tool-inventory.md` was deprecated 2026-05-17 (item 15q in `system-design.md` §6). |
| How to add a new tool (MCP or CLI) | `TOOLS.md` §"How to add a tool" | Step-by-step procedure for both paths |
| Declared MCPs | `.mcp.json` at repo root | `mcpServers` block |

### Contacts & relationships

| Topic | Canonical source(s) | Notes |
|---|---|---|
| Contacts schema (frontmatter + body sections) | `<workspace.root>/<workspace.resources>/contacts/README.md` | **Reference, don't reproduce** — read live, don't restate. |
| Contact location | `<workspace.root>/<workspace.resources>/contacts/<slug>.md` | Per-file flat layout |
| WikiLinks `[[topic]]` convention | `CLAUDE.md` §"Cross-references — WikiLinks convention" + decision #19 | Manual convention; `/find` follows `[[X]]` links |

### Lifecycle skills

| Topic | Canonical source(s) | Notes |
|---|---|---|
| How to create a new project | `.claude/skills/new-project/SKILL.md` + `README.md` Quick Reference | The skill body is the authoritative procedure |
| How to archive a project | `.claude/skills/archive-project/SKILL.md` | |
| How to prune stale projects | `.claude/skills/prune-projects/SKILL.md` | Friday-batch staleness review |
| How to triage Inbox | `.claude/skills/inbox-process/SKILL.md` + Operating Principle "Capture before commit" | Locked decision #24 |
| How to save a resource | `.claude/skills/save-resource/SKILL.md` | |
| How to find existing knowledge | `.claude/skills/find/SKILL.md` + decision #18 | The unified recall surface |

### Capability index (dynamic — globbed at invocation)

| Topic | Discovery method | Notes |
|---|---|---|
| All available skills | `find .claude/skills -maxdepth 2 -name SKILL.md` then read each frontmatter `description:` line | DO NOT hardcode the list — glob at invocation time |
| All design-system brands | `find <workspace.resources>/design-systems -name DESIGN.md` | Plus the `README.md` in that directory |
| All contacts (count, not enumeration) | `ls <workspace.resources>/contacts/*.md \| grep -v README \| wc -l` | Enumeration deferred to `/contact` |
| All reference micro-docs | `ls <workspace.resources>/reference/*.md` | Top-level only; subdirs are domain-specific |
| Active projects (live status) | run `<scripts.project_query>` | Defer to the script; don't enumerate inline |

### Design system

| Topic | Canonical source(s) | Notes |
|---|---|---|
| Active design brand | Root `DESIGN.md` | Read by all `design-*` skills |
| Design brand library | `<workspace.root>/<workspace.resources>/design-systems/<brand>/DESIGN.md` | Plus the README catalog in that dir |
| How to swap brand | `.claude/skills/use-design/SKILL.md` | `/use-design <brand>` |

### Hooks & harness

| Topic | Canonical source(s) | Notes |
|---|---|---|
| Hook wiring | `.claude/settings.json` (the wiring) + `.claude/hooks/` (the source) + `CLAUDE.md` §"Bundled harness layout" | No single explainer doc — surface as a gap if asked |
| Recurring work primitives | `README.md` §"Recurring Work" | `CronCreate`, `/schedule`, `/loop`, hooks |
| CCv4 bundle map | `CLAUDE.md` §"Bundled harness layout" + `TOOLS.md` §"Native skill bundles" | 9 CCv4 skills bundled in-repo since 2026-05-11 |

### First-run setup

| Topic | Canonical source(s) | Notes |
|---|---|---|
| `/bootstrap` procedure | `.claude/skills/bootstrap/SKILL.md` | The skill IS the source of truth on its own procedure |
| Re-running `/bootstrap` | `bootstrap/SKILL.md` Tiger invariants (T1-T4) | T2 refuses re-run on configured fork |

### Gaps (no canonical source — surface honestly)

The following are commonly asked but have **no canonical source today**. The skill MUST surface this honestly rather than improvise:

| Topic | Status | Workaround |
|---|---|---|
| Why these 5 MCPs (gemini-vision/exa/slack/atlassian/figma) and not others | MISSING | Point at `system-design.md` decision #17 (vision) + #20 (plugin MCPs) + #23 (exa) for partial rationale |
| How hooks work end-to-end | MISSING | Point at `.claude/hooks/` source files + `CLAUDE.md` §"Bundled harness layout" |
| How to author a new skill (procedural) | PARTIAL | Point at `/skill-creator` SKILL.md — it teaches conversationally |
| Configuration-token resolution under the hood | MISSING | Point at `CLAUDE.md` §"Configuration" for the *what*; explain that skills substitute tokens at read-time |

When asked about a gap topic, respond per Read Protocol Step 7. Do NOT fill the gap with inline content.

---

## Read Protocol

When invoked with a question (or auto-routing match), execute these steps in order:

### Step 1 — Classify the query

Map the user's question to a row in the Routing Table. Multi-topic queries fan out to multiple rows. If no row matches, jump to Step 7.

Also detect the invocation mode:
- **Narrative mode** (default) — if the query is natural language from a user-facing prompt
- **Structured mode** — if the invocation includes a structured args payload (e.g., `args="token:workspace.projects"` or `args="topic:contacts-schema"`) typical of Claude self-consult

### Step 2 — Resolve Configuration tokens

Read `CLAUDE.md` lines containing the `## Configuration` section. Extract every `<token>` value referenced in the routing-table entries you matched. This step is MANDATORY and runs every invocation — never cache token values between calls.

If Configuration is empty or contains placeholder values (e.g., `setup_completed:` is missing or unfilled), **short-circuit immediately** with:

> *"Cannot answer — Configuration section in root `CLAUDE.md` is unfilled or placeholder. This usually means `/bootstrap` hasn't run yet, or the fork was set up manually and Configuration was skipped. Run `/bootstrap` first, then re-ask."*

Never improvise an answer in this state.

### Step 3 — Read the canonical source(s)

Use the `Read` tool. For section-specific lookups, use `offset`/`limit` to fetch only the relevant lines. If section anchors don't match (e.g., the heading moved), fall back to reading the whole file.

For dynamic-glob entries (capability index, brands, contacts count, reference docs):
- Use `Glob` or `Bash` (`find`/`ls`) at invocation time
- Read SKILL.md frontmatter description lines via `Grep` + `Read`
- NEVER hardcode the list in the skill body

### Step 4 — Compose the answer

**For narrative mode**:
- Lead with the answer (no "Great question!" — see voice rules)
- Quote canonical content verbatim where useful; paraphrase only when length demands
- Every factual claim ends with `*(source: <relative-path>:<line-range>)*`
- Resolve all `<workspace.*>` and `<user.*>` tokens to actual values before quoting paths
- Optional one-line "next step" or "want me to…?" closer when appropriate

**For structured mode**:
- Zero prose padding
- Output key:value:source triples in YAML-ish format:

```
key: <token or topic name>
value: <literal value or canonical answer>
source: <relative-path>:<line-range>
resolved_path: <if applicable, fully-resolved path with Configuration substitutions>
related_tokens:
  - <if relevant>
canonical_files:
  - <list of source files consulted>
last_verified: <date if available, e.g. from setup_completed>
```

### Step 5 — Surface disagreements explicitly

If two canonical sources contradict each other (e.g., `README.md` says X about a topic but `system-design.md` §7 says Y), **never silently pick one**. Surface both with citations and explain the hierarchy:

> *"Sources disagree on this:*
> *- `README.md` (line N) says X*
> *- `system-design.md` decision #M (line P) says Y*
>
> *Locked decisions in `system-design.md` §7 win over README when they conflict. Recommend updating README to match. The current locked answer is Y."*

This discipline mirrors `/find`'s contradiction-surfacing rule at `find/SKILL.md:155`.

### Step 6 — Distinguish similar-shaped topics

Some queries are ambiguous between this-OS-specific and generic. Default to the *this-OS-specific* answer; explicitly reject the generic version.

Example — "what is PARA?":
- Generic answer: Tiago Forte's framework → REJECT with one-line redirect to Wikipedia/Forte
- This-OS answer: the 5-folder workspace layout → THIS is what the skill answers

Some queries are ambiguous between disjoint scopes (e.g., "what is PARA?" could mean workspace PARA *or* Mac Desktop PARA, which are distinct). Ask one disambiguating question via `AskUserQuestion` if the answer differs:

> *"Which PARA — the workspace `<workspace.root>/` (5-folder) or your Mac Desktop `~/Desktop/` (6-folder, documented in USER.md)?"*

### Step 7 — No-canonical-source fallback

If the query maps to a "Gaps" row OR no Routing Table row matches at all, respond:

> *"That topic exists in this OS conceptually, but there's no canonical source documenting it yet. Closest related:*
> *- `<file-path>` covers <related-aspect>*
> *- `<file-path>` covers <related-aspect>*
>
> *If you decide what the canonical answer is, write it down at `<workspace.root>/<workspace.resources>/reference/<topic>.md` and re-ask — I'll pick it up next sync."*

**Never improvise.** Never fill the gap with inline generated content. The gap surface IS the correct behavior.

### Step 8 — Out-of-scope refusal

If the query is genuinely outside the skill's scope (asking about generic productivity theory, asking about Claude Code itself, asking for an action that's a mutation skill's job):

> *"Out of scope for `/os-guide` — that's not OS-shaped. Try:*
> *- `<other-skill>` if you meant <X>*
> *- `<external-resource>` if you meant <Y>*
>
> *If you meant something OS-specific and the phrasing came out generic, try rewording — like 'what is `<workspace.projects>` in this OS' instead of 'what is PARA in general'."*

---

## Citation format

**Mandatory on every factual claim** in narrative mode. Format: `*(source: <relative-path>:<line-range>)*`

Examples:
- `*(source: CLAUDE.md:24)*`
- `*(source: README.md:32-39)*`
- `*(source: <workspace.root>/<workspace.resources>/contacts/README.md)*` (whole-file citation when section-specific isn't appropriate)

Relative path is from repo root. If a token-substituted path is more readable, use both:
- `*(source: <workspace.resources>/contacts/README.md — resolves to your configured workspace.root)*`

In structured mode, citations live in the `source:` key, not as inline text.

---

## Voice & answer-shaping

Voice per `SOUL.md` Operating Principles. Lead with the answer. No filler.

**Phrases to use** (from `SOUL.md`):
- "Here's what matters..."
- "Worth noting..."
- "From what I'm seeing..."
- "My take on this..."
- "Want me to...?"

**Phrases to never produce**:
- "Great question!" / "I'd be happy to help!" / "Sure!" — performatively helpful
- "Per your request..." / "Please be advised..." / "FYI..." — corporate fluff
- "Actionable items include..." — corporate-action phrasing
- "As an AI..." or any self-referential meta-narration

**Length discipline**:
- Definitional questions: 2-5 sentences plus citation
- Procedural questions: numbered steps, prereqs surfaced upfront
- "Where is X" lookups: one sentence, the path + citation
- Capability-index questions: structured list, grouped by category, with one-line descriptions from each skill's frontmatter

**No emojis** unless the user explicitly invites them — per `USER.md` formatting preferences.

---

## Failure modes

| # | Failure | Mitigation |
|---|---|---|
| 1 | Stale embedded fact in skill body | This skill body MUST NOT embed facts — Routing Table only. Enforce at edit time. |
| 2 | Renamed canonical file | Step 3 `Read` fails cleanly; skill surfaces *"Routing table points at `<path>` but file is missing — has it been renamed? Run `/os-guide --sync` to refresh."* Never improvises. |
| 3 | Topic has no canonical source | Step 7 — surface the gap honestly with closest-related pointers; suggest writing it down. Never improvises. |
| 4 | Configuration drift (fork renamed `workspace.root`) | Step 2 re-reads Configuration every invocation; substitutes tokens dynamically. Path-shape answers are always correct for the fork's actual layout. |
| 5 | Canonical source itself is wrong | Skill is a faithful repeater. File:line citation lets user/Claude verify and notice. Correctness is pushed to canonical-source maintenance (where the project invests effort). |
| 6 | Recursive self-call / loop | Skill MUST NOT call itself; MUST NOT call `/find` recursively for OS-knowledge. Canonical source list is hardcoded in Routing Table. |
| 7 | Out-of-scope question | Step 8 — graceful refusal with redirects. |
| 8 | Description over-triggers (steals routing from `/find`/`/bootstrap`) | Description claims explicit scope + names neighbors. Eval cases include explicit deferral tests. |
| 9 | Skill body drifts (someone adds prose answers) | The rule from decision #25: routing entries only, never content. Pre-commit grep MAY enforce in future. |
| 10 | Two canonical sources disagree | Step 5 — surface both with citations, explain hierarchy. Never silently pick. |
| 11 | User asks for live workspace state (e.g., "what projects are active?") | Point at `<scripts.project_query>` (project-query.sh); don't run it inline. This skill is structural, not state-querying. |
| 12 | Claude self-consults but the user's question wasn't OS-shaped | Skill should still produce a useful answer if possible, but if the question maps to no row, fall to Step 7 (no-canonical-source) gracefully. |

---

## Boundaries

This skill is **read-only by default**. The single exception is `--sync` mode (see `--sync` section below), which edits the Routing Table only, gated by explicit user approval.

The skill MUST NOT:
- Modify any canonical source file (CLAUDE.md, README.md, SOUL.md, TOOLS.md, system-design.md, contacts/README.md, etc.) — those are owned by their respective edit paths (the user, `/bootstrap`, lifecycle skills)
- Auto-install tools, run `/mcp`, modify `.mcp.json`
- Run `git add` or `git commit` — surface commands as text only
- Modify any user content (Resources, Projects, Archive, memory)
- Call itself recursively
- Call `/find` recursively for OS-knowledge questions (canonical source list is hardcoded)
- Fabricate content for gap topics
- Embed facts in its own body — only routing entries, protocol, voice, boundaries

If asked to do any of the above, defer to the appropriate skill (`/bootstrap` for setup, `/new-project` for scaffolding, etc.) — do not silently invoke them.

---

## --sync mode (self-update)

`/os-guide --sync` is the sole mutation mode. The skill's Routing Table is hardcoded in this body for safety (no hidden dynamic state), but new things get added to the OS constantly — new skills, new MCPs, new design brands, new locked decisions. `--sync` detects what's changed and proposes routing-table updates without ever auto-applying them.

### Trigger surfaces

- **Explicit command**: `/os-guide --sync` or `/os-guide refresh`
- **Natural language**: "sync the os guide", "refresh /os-guide", "I added new tools — update the guide", "I added a new skill, update /os-guide"
- **Future (deferred)**: PostToolUse hook on Edit/Write to canonical files (TOOLS.md, .mcp.json, system-design.md, CLAUDE.md) that suggests `--sync` without auto-running it

### Five-phase behavior

#### Phase 1 — Inventory snapshot (no mutations)

Glob the filesystem against every known convention, produce a current-state snapshot:

```bash
# All from <workspace.root>/<workspace.resources>/ — resolve via Configuration first
SKILLS=$(find .claude/skills -maxdepth 2 -name SKILL.md | wc -l)
BRANDS=$(find "$WORKSPACE_RESOURCES/design-systems" -maxdepth 2 -name DESIGN.md | wc -l)
CONTACTS=$(ls "$WORKSPACE_RESOURCES/contacts/"*.md 2>/dev/null | grep -v README | wc -l)
REFDOCS=$(ls "$WORKSPACE_RESOURCES/reference/"*.md 2>/dev/null | wc -l)
PROJECTS=$(find "$WORKSPACE_PROJECTS" -maxdepth 2 -name CLAUDE.md | wc -l)
DECISIONS=$(grep -c "^| [0-9]\+ |" "$DESIGN_PROJECT/system-design.md")
MCPS=$(jq -r '.mcpServers | keys[]' .mcp.json 2>/dev/null | wc -l)
```

Also capture lists, not just counts:
- Skill slug list (sorted)
- Design brand slug list (sorted)
- Reference doc filename list (sorted)
- MCP name list (from `.mcp.json`)
- TOOLS.md status flag hash (sha256 of the lines matching `^- [✅⏳⚠️❌]`)
- Configuration section line range (grep for `^## Configuration` and the next `^## ` header)

#### Phase 2 — Diff against last-sync state

Read `.claude/skills/os-guide/state/last-sync.json` (if exists). If first sync, every item is NEW; skip the diff and report everything as initial state. Otherwise compute per-category deltas: items added, items removed, status-changed.

#### Phase 3 — Drift detection on canonical sources

For each routing-table entry pointing at a specific path:
- Verify the file exists (`test -f`)
- If the entry has a hardcoded line range (e.g., "CLAUDE.md:17-58"), grep for the section header and verify the range still matches the actual section

For each known canonical-section anchor (e.g., `## Configuration`, `## Project Map`, `## Operating Principles`):
- Find current line range via `grep -n "^## " <file>`
- Compare to last-sync stored range; flag if moved

Flag in the report — don't auto-fix.

#### Phase 4 — Markdown report

Compose a report like:

```markdown
# /os-guide --sync report (YYYY-MM-DD)

## Inventory delta since last sync (YYYY-MM-DD)
- **Skills**: +N new (slug list), -M removed
- **Design brands**: +N new
- **Contacts**: count changed N→M (enumeration deferred to /contact)
- **Reference docs**: +N new (filename list)
- **Locked decisions**: +N new (titles of new rows)
- **TOOLS.md status changes**: <tool> ⏳→✅
- **MCPs in .mcp.json**: +N new, -M removed
- **Active projects**: count changed N→M

## Drift on canonical sources
- **Stale routing entries** (file moved/renamed): list
- **Section-range drift**: list (e.g., "CLAUDE.md ## Configuration moved 17-58 → 17-62")
- **Reopened locked decisions**: list

## Proposed routing-table updates
<inline diff block showing exact SKILL.md edits>

## Items requiring manual action (cannot auto-propose)
- **New top-level canonical files at repo root**: list (e.g., "found WORKFLOW.md — is this a canonical source?")
- **New directory patterns under Resources**: list (e.g., "found experiments/ — is this a new convention to add a glob for?")
- **Semantic drift detected**: list (always empty — `--sync` cannot detect this; surface explicitly)
```

#### Phase 5 — `<user.name>` review + apply (the mutation gate)

After the report is shown, prompt:

```javascript
AskUserQuestion({
  question: "Apply these updates to /os-guide's routing table?",
  options: [
    { label: "Apply all", description: "Edit SKILL.md per the diff; update last-sync.json" },
    { label: "Apply some", description: "Multi-select which updates to apply (next round of AskUserQuestion)" },
    { label: "Skip — defer for later", description: "Write report to state/sync-deferred-<date>.md; no SKILL.md edit" },
    { label: "Cancel", description: "Exit without writing anything" }
  ]
})
```

- **Apply all** / **Apply some**: Use `Edit` to update the Routing Table section only (never touch other sections of SKILL.md). Then `Write` updated state to `.claude/skills/os-guide/state/last-sync.json`. Surface final summary: *"Routing table updated; N entries added, M flagged stale for manual review."*
- **Skip**: `Write` report to `.claude/skills/os-guide/state/sync-deferred-YYYY-MM-DD.md`. Do NOT update `last-sync.json`. Surface: *"Deferred. Report saved to state/sync-deferred-<date>.md. Re-run `--sync` when ready."*
- **Cancel**: Exit immediately. Write nothing.

### State file schema

`.claude/skills/os-guide/state/last-sync.json`:

```json
{
  "last_sync": "YYYY-MM-DDTHH:MM:SS-07:00",
  "schema_version": "1",
  "skills": {
    "count": 51,
    "list": ["archive-project", "bootstrap", "..."]
  },
  "design_brands": {
    "count": 73,
    "list": ["airbnb", "anthropic", "..."]
  },
  "contacts": { "count": 21 },
  "reference_docs": {
    "count": 4,
    "list": ["MCP-Server-Reference-Guide.md", "README.md", "..."]
  },
  "active_projects": { "count": 9 },
  "locked_decisions": { "count": 25, "latest_id": 25 },
  "tools_status_hash": "sha256:...",
  "mcp_servers": ["gemini-vision", "exa", "slack", "atlassian", "figma"],
  "configuration_section_range": [17, 58],
  "operating_principles_section_range": [66, 82]
}
```

Schema versioned so future shape changes don't break drift detection. Bump `schema_version` when adding fields; old `last-sync.json` files are treated as first-sync (full reset).

### Tiger invariants for `--sync`

Mirror `/bootstrap`'s T1-T4 — they're the contract that makes mutation safe:

- **T1 — Never auto-apply**. Every routing-table edit MUST be gated behind `AskUserQuestion` approval. The skill MUST NOT batch-apply without explicit go-ahead per invocation.
- **T2 — Never delete routing entries automatically**. If a canonical file got renamed/moved, FLAG it in the report and surface as manual-action; do not silently remove the routing entry. The user removes or remaps.
- **T3 — Never commit, never push**. Surface `git add` / `git commit` commands as text in the closing message; never execute them. Same rule as `/bootstrap` T3 and `/contact-log` E1.
- **T4 — Never touch files outside `.claude/skills/os-guide/`**. The only files `--sync` may write to are: `SKILL.md` (Routing Table section only — body sections like voice, protocol, boundaries are NEVER edited) and `state/last-sync.json` + `state/sync-deferred-<date>.md`.

### Scope limits (honest about what `--sync` doesn't catch)

`--sync` covers ~80% of routine OS evolution. It does NOT catch:

1. **New top-level canonical files** at repo root that don't match any existing convention (e.g., if you add `WORKFLOW.md` at root, `--sync` surfaces "found unknown top-level .md files" for manual decision — doesn't add to routing automatically).
2. **New convention patterns entirely** (e.g., if `<workspace.resources>/experiments/<slug>/EXPERIMENT.md` becomes a new pattern, `--sync` finds the directory but doesn't know to add a glob — surfaces as "new directory pattern detected").
3. **Semantic drift** where the file path stayed the same but the content's meaning changed (e.g., README.md PARA section got rewritten with different folder counts). `--sync` cannot detect this; only structural drift.

These 3 cases are listed explicitly in the Phase 4 report under "Items requiring manual action" so the user is never surprised by what was silently missed.

### When to run `--sync`

- **After adding a new skill** via `/skill-creator`
- **After adding a new MCP** to `.mcp.json` and authorizing it via `/mcp`
- **After adding a new design-system brand** to `<workspace.resources>/design-systems/`
- **After locking a new decision** in `system-design.md` §7
- **After major doc edits** that may have moved section line ranges (CLAUDE.md restructure, README rewrite)
- **On schedule** — once a week as a maintenance ritual, similar to `/prune-projects` Friday batch (manual at first; cron only after value is proven, per the heartbeat lesson)

---

## Output formats

**Narrative mode** — markdown response with citations on every factual claim. Optional closing question or next-step pointer.

**Structured mode** — YAML-ish key:value:source block. Zero prose. Designed for Claude self-consult parsing.

**No-canonical-source mode** — gap-surfacing response per Step 7 with closest-related pointers.

**Out-of-scope mode** — refusal + redirects per Step 8.

**Disagreement mode** — explicit "Sources disagree" block per Step 5, citing both, explaining hierarchy.

These five formats are stable. Downstream skills (Layer 3 chief-of-staff) MAY compose `/os-guide` for path/config lookups and parse the structured-mode output specifically.
