---
name: find
description: Recall layer for the second brain. Searches across `<workspace.root>/<workspace.resources>/`, `<workspace.projects>/`, `<workspace.archive>/`, `hq-*/` (HQ workstations + foundation), and `memory/` for a topic — by filename and content — then ranks matches and optionally synthesizes them with file citations. Use whenever the user asks <assistant.name> to recall existing knowledge before generating new content — phrases like "do I have anything on X", "what do I know about Y", "search my notes for Z", "find research on W", "is there a project for V", "/find <topic>". Trigger broadly on recall language even when the user doesn't say "find" explicitly.
allowed-tools: Read Bash AskUserQuestion
---

# find

Unified recall across the second brain. Default mode: ranked list of matches. Optional: synthesis pass that reads top matches and produces a citations-backed summary.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.resources>` resolve from there — don't hardcode.

## Why this exists

Without `/find`, recall is manual flailing across four organizational locations: Resources (research/reference/meetings), Projects (active), Archive (closed), and Memory (daily logs + curated long-form). `/find` unifies the search surface into one skill.

Two downstream consumers depend on this:
1. **Layer 3 skills (briefing, meeting-prep, etc.)** — before generating "what's on your plate today", they need to ask "what existing notes are relevant?". Without a recall primitive, every Layer 3 skill reinvents search.
2. **The user, daily** — "do I have anything on the Anthropic admin API?" should be one slash command, not a 4-step `find | grep | head | cat` ritual.

This skill is a port of claudesidian's `research-assistant` adapted to our paths, frontmatter conventions, and the synthesis-with-citations pattern. The "identify contradictions" guidance from claudesidian is preserved — when sources disagree, surface it explicitly rather than silently pick one.

## When to use

Trigger phrases (broad — recall is the pattern, not the literal command):

- "do I have anything on X" / "what do I have on X"
- "find my notes on X" / "search for X"
- "is there research on X" / "any research about X"
- "what did I save about X" / "what do I know about X"
- "is there a project for X" / "any project related to X"
- "what's in my notes on X" / "search my second brain for X"
- "/find X" / "/find"

Do NOT trigger for:
- Content creation — generate directly. Recall is implicit; the user will say "find" if they want it first.
- A specific known filename — Read it directly.
- Web search — use `WebSearch` / `WebFetch`.
- Code search inside `<workspace.coding>/<repo>/` — that's a per-repo concern; `/find` doesn't span gitignored code repos.

## Process

The skill is interactive. Subagent runs (no `AskUserQuestion`) extract intent from the invocation prompt and default to `synthesize` mode if more than 2 matches.

### Step 1: Get the topic

If the invocation includes a query (e.g., `"/find anthropic admin api"` or `"what do I have on the Q1 plan?"`), extract it. Otherwise ask in plain chat:

*"What topic? I'll search resources, projects, archive, and memory."*

Keep the original-case query for content grep; build a slugified variant (lowercase, hyphens) for filename matching. Both are used in Step 2.

### Step 2: Search across locations (parallel)

Run these searches in parallel via Bash. All paths come from the Configuration section.

```bash
# Filename match — case-insensitive
find "<workspace.root>/<workspace.resources>" \
     "<workspace.root>/<workspace.projects>" \
     "<workspace.root>/<workspace.archive>" \
     hq-* \
     -type f \( -iname "*<query>*" -o -iname "*<slug>*" \) 2>/dev/null

find memory -type f -iname "*<query>*" 2>/dev/null
```

```bash
# Content match — prefer ripgrep (fast), fall back to grep -r
if command -v rg >/dev/null 2>&1; then
  rg -l -i --type md "<query>" \
    "<workspace.root>/<workspace.resources>" \
    "<workspace.root>/<workspace.projects>" \
    "<workspace.root>/<workspace.archive>" \
    hq-* \
    memory 2>/dev/null
else
  grep -r -l -i --include="*.md" "<query>" \
    "<workspace.root>/<workspace.resources>" \
    "<workspace.root>/<workspace.projects>" \
    "<workspace.root>/<workspace.archive>" \
    hq-* \
    memory 2>/dev/null
fi
```

Collect into a unique set. Skip:
- `node_modules/`, `.git/`, `_archive-cleanup-*/`, `_archive-ccv4-*/` — cleanup / vendor noise
- Files larger than 5 MB — likely binaries
- `<workspace.root>/<workspace.coding>/` — out of scope (gitignored, per-repo concern)

### Step 3: Rank matches

For each unique file, compute a weight:

| Signal | Weight |
|--------|--------|
| Filename contains query (case-insensitive) | +3 |
| Each content occurrence (cap at 5 per file) | +1 |
| `mtime` within last 30 days | +1 |
| Path contains `<workspace.projects>/` | +2 |
| Path contains `memory/` | +1 |
| Path contains `<workspace.archive>/` | -1 |

Higher weight = more likely to be what the user wanted. Sort descending, cap displayed list at 15 (the rest are surfaced as a count: *"+ N more matches truncated"*).

### Step 4: Show ranked list

```
Found N matches for "<query>":

  📁 <relative-path>     <YYYY-MM-DD>   <size>   <one-line excerpt>
  📁 <relative-path>     <YYYY-MM-DD>   <size>   <one-line excerpt>
  ...

Breakdown: K resources · L projects · M archive · P memory
```

The **excerpt** is the first line containing the query (case-insensitive content match), or the first non-empty line if filename-only match. Trim to ~80 chars.

Use `<relative-path>` from the workspace root (e.g., `workspace/3-Resources/research/2026-04-anthropic-admin-research/findings.md`) so the user can copy and Read directly.

If breakdown shows zero in resources but matches in archive, **flag it**: *"Note: only archived matches — nothing live."*

### Step 5: Ask what next

`AskUserQuestion`:

- `synthesize` — read top 5 matches, produce a structured summary with citations
- `read` — read a specific match in full (next chat message: *"which one? say the number or path"*)
- `done` — show list only, exit

**Skip the question and default to `synthesize`** when:
- Only 1-2 matches found (just synthesize directly — no point asking)
- Subagent context (no `AskUserQuestion`) — pre-extract from invocation prompt

### Step 6: Synthesize (if chosen)

Read top 5 matches **in parallel** via the `Read` tool. Then produce:

```markdown
## Synthesis: "<query>"

### Key points
- <bullet>  *(source: <relative-path>)*
- <bullet>  *(source: <relative-path>)*

### Connections
- <X relates to Y because Z>  *(sources: <a>, <b>)*

### Open questions / contradictions
- <surface explicitly if sources disagree, e.g. "file A says X happens monthly; file B says weekly">

### Where to dig deeper
- `<relative-path>` — <one sentence on why this is the richest source>
```

**Citation rule:** every factual claim must end with `*(source: <path>)*`. If sources contradict, surface it under "Open questions / contradictions" — don't silently pick one. This is the claudesidian discipline: "Don't ignore contradictions — they're often where insights live."

### Step 7: Empty result handling

If zero matches:

```
No matches for "<query>" across the second brain.

You might want to:
- Start a research note:  /save-resource → research → topic="<query>"
- Start a project:        /new-project   (if this is becoming work)
- Try a related term:     <suggest 1-2 variants based on the query>
```

The "related term" suggestions should be obvious word-stem variants (e.g., "anthropic admin api" → "anthropic API", "claude admin").

### Step 8: Stop

Don't auto-update any index, don't auto-commit, don't propose unrelated next actions. Recall is read-only by design.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Neither `rg` nor `grep -r` available | Truly bare system | Surface error: *"Need `rg` or `grep` for content search. Install via `brew install ripgrep`."* |
| Too many matches (>50) | Generic term ("AI", "the") | Truncate to top 15, suggest narrowing: *"Query is broad — try `<workspace.projects>/<query>` or a more specific phrase"* |
| All matches in archive | Topic is dormant | Surface this — *"Note: only archived matches — nothing live."* — then offer to dig in or start fresh |
| File >5MB matched | Binary or huge dump | Skip silently (rank weight 0) |
| `AskUserQuestion` unavailable | Subagent context | Default to `synthesize` mode if matches > 0; if 0, return the empty-result message |
| Configuration values missing | Fresh fork | Error: *"Configuration section in root CLAUDE.md not populated. Run `/bootstrap` (TBD) or fill it in manually first."* |
| Topic slugifies to empty | All special chars | Re-prompt: *"That topic didn't slugify cleanly — try one with letters/numbers"* |

## Output format

**Default (list only):** the ranked-list block from Step 4, ending with the breakdown line.

**Synthesize mode:** the markdown block from Step 6 with citations on every claim.

**Empty:** the empty-result block from Step 7.

These three formats are stable — `/briefing` and other Layer 3 skills will parse them by looking for `## Synthesis:` headers and `*(source: ...)*` citation patterns.
