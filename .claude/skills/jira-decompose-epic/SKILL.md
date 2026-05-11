---
name: jira-decompose-epic
description: Decompose an existing Jira Epic into N Story tickets in one batch — all sharing a consistent shape — header info panel with Confluence + repo cross-links, ADF taskList for acceptance criteria (interactive checkboxes), parent linkage, custom fields (Team, AI Category, label), and Blocks links wired between sequential slices (vertical-slice pattern). Use this whenever <user.name> wants to break an Epic into vertical slices and create the corresponding Jira tickets in one batch — phrases like "decompose this Epic into stories", "create the slices", "scaffold the stories under <Epic>", "spin up Slices A through G", "bulk-create these vertical slices in Jira", or any time a design doc lists multiple slices/stories that need to land in Jira together. Trigger broadly on Epic-decomposition / bulk-Story-creation language under an existing Epic. Reads from a YAML or JSON spec file the user prepares; does NOT create the spec from a conversation — the user (or another upstream skill) writes the spec, this skill executes it. Inputs go in, tickets come out, links wire up.
---

# jira-decompose-epic

Models the pattern <user.name> + <assistant.name> hammered out for the trf-benchmark-dashboard Epic (ATF-450) on 2026-05-06: a single Epic decomposed into N vertical slices, each end-to-end demoable, with sequential Blocks links capturing the dependency chain. That session cut by hand because no skill existed; this skill turns the pattern into one command.

The skill is **deliberately narrow**: it creates Stories under an existing Epic, with a specific ADF body shape and the Atlassian custom fields configured in your instance (Team, AI Category, etc. — IDs and field names vary by tenant). It does NOT create Epics, Bugs, or Tasks; it does NOT create the Confluence pages those tickets cross-link to (use `/confluence-publish-markdown` for that).

## When this triggers

Use this skill when:
- The user has an Epic already created (e.g. ATF-450) and wants to decompose it into N Stories
- The user has either already drafted slice specs or is asking <assistant.name> to draft them
- The desired shape is the trf-dashboard pattern: header info panel, taskList AC, parent linkage, Team + AI Category custom fields, label, and Blocks-link dependency chain

Do NOT use this skill when:
- You're creating a single Story (just use `mcp__atlassian__createJiraIssue` directly)
- The Epic doesn't exist yet (create it first — Epic-creation is a one-shot, not worth a skill)
- You want to update existing Stories' descriptions (use direct REST PUT or `mcp__atlassian__editJiraIssue`)
- The tickets need a different shape (e.g., bugs with reproduction tables — different skill)

## Workflow

### Step 1 — Confirm or build the spec

The skill consumes a spec file. Two paths:

**(a) User has a spec file ready.** They say something like "use this spec at `~/work/my-epic-slices.yaml`". Skip to Step 2.

**(b) <assistant.name> drafts the spec from conversation.** The user is decomposing an Epic verbally or pointing at a `system-design.md` with a slice list. <assistant.name> reads the design doc, drafts the YAML, **shows the user the spec, gets sign-off**, then proceeds. Don't skip the sign-off — slice content is opinionated and bulk-creating tickets without confirmation creates expensive cleanup.

The spec schema is in `references/spec-schema.md`. A worked example modeling today's session is `assets/example-spec.yaml`.

### Step 2 — Pre-flight checks

Before creating anything, run `scripts/create_slices.py --spec <path> --validate-only` to:

1. Parse the spec (YAML or JSON, auto-detected by extension)
2. Confirm `epic_key` exists via `GET /rest/api/3/issue/{key}` (basic-auth from `~/.second-brain-harness.env`)
3. Verify all `blocked_by_letter` values reference letters that exist in the spec's `slices` array
4. Confirm all required env vars present: `ATLASSIAN_BASIC_AUTH`, `ATLASSIAN_EMAIL`

If any check fails, the script exits non-zero with a clear message. Don't proceed until `--validate-only` succeeds — partial creation halfway through a 7-slice batch is the expensive failure mode.

### Step 3 — Execute

Run `scripts/create_slices.py --spec <path>` to create the slices and wire links.

The script:
1. For each slice in `slices` array order: `POST /rest/api/3/issue` with markdown placeholder description, parent linkage, custom fields, label
2. After each create, immediately `PUT /rest/api/3/issue/{key}` with the full ADF body (header panel + Parent heading + What to build + Reference docs + AC taskList + Slice type + Blocked by + Notes)
3. After all slices created, walk the spec again and create Blocks links: `inwardIssue=<blocker_key>`, `outwardIssue=<this_key>` for each slice with `blocked_by_letter` set
4. Print summary: list of created keys + JQL to find them all (`labels = "<label>" ORDER BY key ASC`)

### Step 4 — Verify

After the script finishes, ask the user to spot-check the first slice in the browser: confirm the header info panel renders, AC checkboxes are interactive (not markdown text), and parent linkage shows ATF-450 in the side panel. If the first slice looks right, the rest will too — they're built from the same code path.

## Idempotency — important caveat

**This skill is not idempotent.** Re-running it creates duplicate tickets. There is no built-in deduplication, and Jira doesn't natively support "create-or-update by summary."

If a partial batch lands and you need to re-run, either:
- Delete the partially-created tickets first (Jira permits this within ~30 days), or
- Manually edit the spec to remove the slices that already created, run the script for the remainder, and add Blocks links manually

The pre-flight check (Step 2) catches the common mistakes. The non-idempotency is the cost of using bulk creation; in exchange you get one command for what was previously 6 createJiraIssue + 6 editJiraIssue + 6 createIssueLink calls (18 round-trips).

## Custom field gotchas

Captured from the 2026-05-06 session and locked in `references/spec-schema.md`:

- **AI Category** (`customfield_11335`) is **not on the Bug create screen** in the ATF project. Stories, Tasks, and Epics support it. This skill only creates Stories — so AI Category always works here. If you adapt this skill to bugs later, drop the field for Bug issue types or the create call returns `BAD_REQUEST`.
- **Team** (`customfield_10001`) takes a **plain string UUID**, not an object. Pass `"77854ec1-..."` not `{"value": "..."}`.
- **Priority** is intentionally omitted — defaults to `(SEV3) Medium`. Setting `"Medium"` directly errors; you must use `(SEV3) Medium` if you set it explicitly.
- **Parent linking** for Stories under an Epic uses `additional_fields: {"parent": {"key": "ATF-450"}}`, not the deprecated `customfield_10014`.

## Auth

The script reads `ATLASSIAN_BASIC_AUTH` from the environment (auto-loaded via `~/.zshrc` → `~/.second-brain-harness.env`). If the env var isn't set, the script tells the user to source the env file or run from a fresh shell.

**Token scope matters.** The basic-auth token must support both:
- `POST /rest/api/3/issue` (create issues) — requires write scope
- `PUT /rest/api/3/issue/{key}` (update description) — requires write scope
- `POST /rest/api/3/issueLink` (create Blocks links) — requires write scope

A scoped/granular Atlassian token may be missing some of these. If creates work but PUTs return 403, regenerate as a **classic API token** (full user permissions) at https://id.atlassian.com/manage-profile/security/api-tokens.

## Files in this skill

- `scripts/create_slices.py` — the workhorse. Reads spec, validates, creates tickets, wires links.
- `references/spec-schema.md` — full schema documentation with field-by-field semantics, edge cases, and examples.
- `assets/example-spec.yaml` — worked example based on the trf-benchmark-dashboard Epic (ATF-450). Read this if you're drafting a new spec from scratch.

## When this skill is the wrong tool

- **Single Story creation** → use `mcp__atlassian__createJiraIssue` + `mcp__atlassian__editJiraIssue` directly. The overhead of writing a spec file isn't worth it for one ticket.
- **Updating existing slices' descriptions** → curl PUT to `/rest/api/3/issue/{key}` directly. The skill creates; it doesn't update.
- **Creating Bugs, Tasks, or sidecars** → out of scope. Future skill or manual.
- **Creating the Epic itself** → manual; Epic creation is rare per project and the metadata varies enough that bulk creation isn't a pattern.
- **Cross-project Stories** → the skill assumes single project. If you need slices spread across projects, run the skill once per project with a sub-spec.
