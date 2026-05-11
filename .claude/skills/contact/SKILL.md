---
name: contact
description: Read-only display of a contact's profile from `<workspace.root>/<workspace.resources>/contacts/<slug>.md`. Fuzzy-matches a name across the contacts directory, then surfaces the matched person's frontmatter summary, last interaction, open commitments (To/From split), About blurb, and Recurring topics. Use whenever the user asks <assistant.name> to recall who a person is or what context exists with them — phrases like "/contact <name>", "who is X again?", "what's my context with Y?", "remind me about Z", "tell me about <name>", "context on <name>". Trigger broadly on entity-keyed recall about people. PRECEDENCE vs `/find`: `/contact` wins when the query target is a name that matches a file in `<workspace.root>/<workspace.resources>/contacts/`. `/find` handles topic-keyed recall (research subjects, project topics). For ambiguous queries that could be either, `/contact` wins; `<user.name>` can override by typing `/find <name>` explicitly. FUZZY-MATCH PRIORITY ORDER (locked, evaluated in order — first hit wins): exact slug match > slug-stem-match (last-token-of-slug or any whitespace-joined slug fragment) > frontmatter `name` exact (case-insensitive) > frontmatter `legal_name` exact (case-insensitive) > prefix match on slug or `name` > substring match on slug or `name`. Substring against `legal_name` is intentionally NOT in the order — it would cause regressions like "michela" matching Omar via `legal_name=Michael Zennadi`. Multi-match → `AskUserQuestion` disambiguation with name + role + relationship per candidate. No-match → graceful fallback suggesting `/contact-add` (planned, not yet shipped). Read-only — never mutates contact files; for mutation use `/contact-log` (append interaction) or `/contact-add` (scaffold).
context: fork
---

# contact

Entity-keyed recall for people. Fuzzy-match a name across `<workspace.root>/<workspace.resources>/contacts/`, surface the matched profile + last interaction + open commitments. Read-only.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.resources>` resolve from there — don't hardcode.

## Why this exists

Without `/contact`, recall about a person is a manual ritual: `ls beru-workspace/3-Resources/contacts/`, guess the slug, `cat` the file. For Layer 3 skills (`/briefing`, `/meeting-prep`) the lookup is even more painful — they have to fuzzy-match names every time.

`/contact` is the entity-keyed recall primitive. It pairs with `/find` (topic-keyed). Together they cover both axes of "what do I know about X?" — where X is either a thing or a person.

The contacts schema (frontmatter fields, body sections, status enum, WikiLinks pattern) is defined in `<workspace.root>/<workspace.resources>/contacts/README.md` — read that first if you need schema details. This skill references the schema; it does not reproduce it.

## When to use

Trigger phrases (broad — entity recall is the pattern, not the literal command):

- "/contact <name>" / "/contact"
- "who is <name>?" / "who is <name> again?"
- "what's my context with <name>?" / "context on <name>"
- "remind me about <name>" / "tell me about <name>"
- "do I have notes on <name>?" — when the target is a person, not a topic
- "what did I promise <name>?" / "what does <name> owe me?"

Do NOT trigger for:
- Topic-keyed recall (research, projects, meetings) — that's `/find`. Phrases like "do I have anything on <topic>", "what do I know about <topic>".
- Specific known filename — Read it directly.
- Mutation (logging an interaction, adding a contact, updating a field) — use `/contact-log`, `/contact-add`, or `/contact-update`. This skill is read-only.
- A question explicitly typed as `/find <name>` — `<user.name>` is overriding precedence; honor it.

### Precedence vs `/find`

When both could trigger (e.g., "tell me about omar"):
- If the query maps to a name that matches a file in `<workspace.root>/<workspace.resources>/contacts/` (per the match algorithm below), `/contact` wins.
- If no contact matches, fall through to `/find` behavior — search resources/projects/archive/memory for the term.
- If `<user.name>` types `/find <name>` explicitly, honor that — they want topic-keyed search across the second brain even though a contact exists.

## Source of truth

Every contact lives at `<workspace.root>/<workspace.resources>/contacts/<slug>.md` with the schema documented at `<workspace.root>/<workspace.resources>/contacts/README.md`. Required frontmatter: `name`, `email`, `role`, `team`, `company`, `relationship`, `status`, `first_logged`, `last_interaction`. Optional: `legal_name`, `recurring_cadence`, `tags`, `slack_handle`, `timezone`, `linkedin`, `reports_to`, `location`, `department`, `division`, `work_phone`. Body sections: About, Recurring topics, Open commitments (To/From split), Interaction log.

## Process

### Step 1: Get the query

If the invocation includes a name (e.g., `"/contact omar"`, `"who is omar again?"`, `"context on michela"`), extract it. Otherwise ask in plain chat:

*"Which contact? I'll look across `<workspace.root>/<workspace.resources>/contacts/`."*

Normalize the query: lowercase, trim. Keep the original-case query for display; build a slugified variant (lowercase, hyphens, spaces collapsed) for filename matching.

### Step 2: Enumerate contacts

```bash
ls -1 "<workspace.root>/<workspace.resources>/contacts/" 2>/dev/null | grep -E '\.md$' | grep -v '^README\.md$'
```

Each result is a slug (filename without `.md`). For each slug, parse the frontmatter to extract `name` and (if present) `legal_name`. This produces a list of `(slug, name, legal_name)` triples — the candidate set.

If the contacts directory doesn't exist or is empty, abort: *"No contacts directory at `<workspace.root>/<workspace.resources>/contacts/`. Either nothing's been scaffolded yet, or the path is wrong — check root CLAUDE.md Configuration."*

### Step 3: Match — locked priority order

Evaluate each tier in order. **First tier with a non-empty result wins; do not continue to lower tiers.** Within a tier, ties go to multi-match disambiguation (Step 4).

1. **Exact slug match.** Slug equals query-slug (e.g., query `omar-zennadi` matches `omar-zennadi.md`).
2. **Slug-stem-match.** Slugify the query (lowercase, whitespace → hyphen). Match if (a) any hyphen-separated token of the slug equals the slugified query (e.g., query `omar` → slug-token match against `omar-zennadi`), OR (b) the slugified query is a contiguous multi-token slice of the slug (e.g., query `van toorn` → slugified `van-toorn` is a contiguous slice of `bob-van-toorn`).
3. **Frontmatter `name` token-level match** (case-insensitive). Query equals the full `name` string (case-insensitive) OR any whitespace-separated token of `name` equals the query exactly. Examples: query `omar zennadi` matches `name: Omar Zennadi` (full-string); query `aswani` matches `name: Jaya Aswani` (token-exact). Token-level NOT substring — `lyson` does NOT match `Alyson Sprague`.
4. **Frontmatter `legal_name` token-level match** (case-insensitive). Query equals the full `legal_name` string (case-insensitive) OR any whitespace-separated token of `legal_name` equals the query exactly. Example: query `michael` matches `legal_name: Michael Zennadi` (token-exact on first token). **Token-level NOT substring.** Substring against `legal_name` would cause `michela` to match Omar via `Michael` substring — that's the locked anti-regression rule, intentionally NOT in this tier OR tiers 5/6. Token-exact is safe because `michela` is not a token of `Michael Zennadi`.
5. **Prefix match on slug or `name`.** Query `aly` matches slug `alyson-sprague` and name `Alyson Sprague`. Multiple hits → multi-match.
6. **Substring match on slug or `name`** (case-insensitive). Last resort. Query `kin` matches `lena-kincaid`. Multiple hits → multi-match.

`legal_name` is **not** included in tiers 5 or 6 (prefix/substring) — only in tier 4 (token-level exact). Token-level on legal_name is safe (token-exact `michael` matches Omar's `Michael Zennadi`, but `michela` is NOT a token of `Michael Zennadi` so no regression). Substring on legal_name would re-introduce the `michela`→Omar bug — that's the locked rule.

### Step 4: Resolve outcome

- **Exactly one match across the winning tier** → display profile (Step 5).
- **Two or more matches in the winning tier** → multi-match disambiguation (Step 6).
- **Zero matches across all tiers** → graceful no-match fallback (Step 7).

### Step 5: Display the profile (single match)

Read the matched contact file. Render in this format:

```
<name> — <role>, <team> (<company>)
Relationship: <relationship>
Status: <status> · Last interaction: <last_interaction>
<email> · <slack_handle if present> · <timezone if present>

About:
<one paragraph from the About section, lightly trimmed if long>

Recurring topics:
- <bullet>
- <bullet>

Open commitments:
  To <name> (<user.name> owes): <count> open
    [optional: list each as "- <date> — <task> — by <due>"]
  From <name> (owes <user.name>): <count> open
    [optional: list each as "- <date> — <task> — by <due>"]

Last interaction:
<latest entry from the Interaction log section, verbatim>

Mentions: /find [[contacts/<slug>]]   (run to surface where this person appears across the vault)

Source: <workspace.root>/<workspace.resources>/contacts/<slug>.md
```

Notes on rendering:
- If a section is empty in the source file (e.g., "*(none tracked yet)*"), surface the literal "0 open" / "no entries yet" rather than fabricating content. **No fabrication, ever** — per the contact-scaffolding-no-fabrication rule.
- If `last_interaction: unknown`, say "no logged interactions yet" instead of inventing one.
- Trim About to ~3-4 sentences if longer; never rewrite or paraphrase — just truncate cleanly.
- The "Mentions" line is a pointer, not an auto-execution. `<user.name>` runs `/find` separately if they want the WikiLinks graph traced.

### Step 6: Multi-match disambiguation

When 2+ candidates win the same tier, use `AskUserQuestion` with `multiSelect: false`. Each option:

```
<name> — <role>, <team> · <relationship>
```

Prompt:

```
Multiple contacts matched "<query>". Which one?
```

After the user picks, render that contact via Step 5. If the user cancels, exit cleanly with no further action.

If `AskUserQuestion` is unavailable (subagent context), surface all candidates inline as a list and stop — let the caller re-invoke with a more specific query.

### Step 7: No-match fallback

When no tier produces any match:

```
No contact named "<query>" in <workspace.root>/<workspace.resources>/contacts/.

Options:
- Add them: /contact-add <query>   (coming soon — Pass 4 #35)
- Topic search instead: /find <query>   (if "<query>" is a topic, not a person)
- See all contacts: ls <workspace.root>/<workspace.resources>/contacts/
```

Don't fabricate a profile, don't speculate about who the person might be, don't invent `last_interaction` dates. The graceful failure IS the correct behavior.

If the directory had any partial-stem matches that fell below substring threshold (e.g., 2-letter overlap), surface them as suggestions: *"Did you mean: <slug-1>, <slug-2>?"*

### Step 8: Stop

Read-only by design. Don't auto-update any index, don't auto-commit, don't propose unrelated next actions, don't modify the contact file. Mutation is `/contact-log` / `/contact-add` / `/contact-update`'s job.

## Boundary

This skill is **read-only**. It MUST NOT:
- Modify any file under `<workspace.root>/<workspace.resources>/contacts/`
- Append entries to the Interaction log (that's `/contact-log`)
- Scaffold new contact files (that's `/contact-add`)
- Edit frontmatter fields (that's `/contact-update`)
- Write to `memory/YYYY-MM-DD.md` (that's the user's daily log; this skill doesn't touch it)

If the user asks for any of the above during the same turn, complete the read action first, then suggest the appropriate mutation skill — do not silently invoke it.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Contacts dir missing | Fresh fork or path misconfigured | Abort with the resolved path so the user knows what to create |
| Frontmatter unparseable on a candidate | Manual edit broke YAML | Skip that candidate, continue matching, surface a one-line warning |
| Tier 4 (`legal_name` exact) matches but tier 1-3 also matched | Impossible by construction (priority order is sequential) | If you hit this, the order was implemented wrong — re-read Step 3 |
| `AskUserQuestion` unavailable (subagent) | Worker context | List candidates inline, stop, let caller re-invoke |
| Two contacts share an exact `name` | e.g., two "John Smith" | Both tier 3 hits → multi-match disambig surfaces them with role/team to differentiate |
| Query is empty after normalization | All special chars | Re-prompt: *"That didn't normalize cleanly — try a name with letters"* |
| Configuration values missing | Fresh fork | Error: *"Configuration section in root CLAUDE.md not populated. Fill it in or run `/bootstrap` (TBD) first."* |

## Output format

**Single-match:** the profile block from Step 5.

**Multi-match:** the `AskUserQuestion` from Step 6, then the profile block once the user picks.

**No-match:** the fallback block from Step 7.

These three formats are stable — Layer 3 skills (`/briefing`, `/meeting-prep`) will compose `/contact <name>` and parse the profile block (specifically the `Open commitments` lines and `Last interaction:` block) for inclusion in their own output.
