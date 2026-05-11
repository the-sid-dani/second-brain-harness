---
type: conventions
domain: jira / project-tracking
created: 2026-05-06
applies_to: ATF (Samba AI Task Force) and any future Sid-owned Jira project
verified_via: live API calls 2026-05-06 — see "Test cases" at bottom
---

# Jira Tracking — How Sid's Projects Land in Jira

The pattern Sid uses across `[Databricks-MCP]`, `[Salesforce-MCP]`, `[Samba Agentic]`, `[Samba-Slackbot]`, `[AudienceMgr-MCP]`, `[ReportGen-MCP]`, and now `[TRF-Dashboard]`. **Adopted manually first; will be skill-encoded only when the manual workflow proves repeatable across 2-3 projects** (per Operating Principle "Eliminate before automate").

The methodology is borrowed verbatim from the retired `engineering-plugin-v1.3.0/Engineering/skills/plan-to-jira` skill on Sid's Desktop. Adapted to ATF's actual field/priority configuration as discovered via live probes.

## Methodology — tracer-bullet vertical slices

When converting a plan, PRD, or `system-design.md` into Jira, **break it into vertical slices, not horizontal layers**.

A vertical slice cuts end-to-end through ALL integration layers (auth → API → transform → storage → render → deploy → tests) for a narrow path. A horizontal slice does one layer ("schema done, API not yet").

Vertical wins because:
- Each completed slice is **demoable on its own**. You can show stakeholders progress at any point.
- Slices unblock each other minimally — Slice A done means Slice B can start, instead of A→B→C→D→E sequencing where nothing demos until E.
- Risk surfaces early. End-to-end on day 1 finds the integration bug before you've built ten layers on top of it.

```
WRONG (horizontal):
  Story 1: Auth layer
  Story 2: API layer
  Story 3: Transform layer
  Story 4: Storage layer
  Story 5: Deploy

RIGHT (vertical):
  Slice A: Auth + API + Transform + Storage + Deploy — for ONE row
  Slice B: ... + render — for ONE row, deployed
  Slice C: Generalize to N rows
  Slice D: Add quality filtering
  Slice E: Add validation gate
  Slice F: Move to Cloud Run + cron
  Slice G: Polish (alerts, footer)
```

Each slice should be **AFK** (away-from-keyboard, agent-implementable without your input mid-task) when possible. Mark slices that need a design decision or human review as **HITL** (human-in-the-loop). Prefer AFK; aim for ≤20% HITL.

## Naming convention

**Epic summary:** `[<ProjectPrefix>] <one-line goal>`
- Example: `[TRF-Dashboard] Daily-refreshed TRF benchmark dashboard for MSCI`
- Pick a short, distinctive prefix. Established prefixes: `Databricks-MCP`, `Salesforce-MCP`, `Samba Agentic`, `Samba-Slackbot`, `AudienceMgr-MCP`, `ReportGen-MCP`, `TRF-Dashboard`. New project = new prefix.

**Story summary (vertical slice):** `[<ProjectPrefix>] Slice <Letter>: <demoable outcome>`
- Example: `[TRF-Dashboard] Slice A: Hello-world ingestion — one oracle into BQ end-to-end`
- The demoable outcome part is the most important — it forces vertical thinking.

**Standalone Task / Bug summary:** `[<ProjectPrefix>] <terse imperative>` or `[<ProjectPrefix>] [Upstream] <description>` for upstream-pipeline issues that aren't owned by the dashboard team.

## Ticket template (verbatim from `plan-to-jira`)

Every Story description follows this shape so an AFK agent or human picking up the ticket gets predictable structure.

```markdown
## Parent

ATF-XXX (Epic title)

## What to build

A concise description of the vertical slice. Describe the end-to-end **behavior**, not layer-by-layer implementation.
The implementer will explore the codebase fresh — describe what changes from a user-or-caller's perspective, not which files to edit.

**Reference docs in the repo:**
- `system-design.md` §X (relevant section)
- `<other-spec-doc>.md`

## Acceptance criteria

- [ ] Specific, testable criterion 1
- [ ] Specific, testable criterion 2
- [ ] Specific, testable criterion 3

Each criterion independently verifiable. Avoid "works correctly" — write criteria another engineer can check off without asking what they meant.

## Slice type

AFK (or HITL with reason)

## Blocked by

- ATF-YYY (reason)
- None — can start immediately

## Notes

(optional — context that doesn't fit elsewhere)
```

**What to leave OUT** of the description (per plan-to-jira discipline):
- File paths or line numbers — they go stale fast. Describe types, function signatures, or shapes instead.
- "How to implement it" prose — the implementer makes those decisions.
- Speculative scope — if a thing is uncertain, leave it for a follow-up ticket rather than padding this one.

For Epics, drop "Parent" and "Blocked by" sections; instead lead with **Goal**, **Audience**, **Architecture (one-line)**, **Repo + master plan links**, **Acceptance criteria (epic-level)**, **Vertical slices (children list)**, **Out of scope**.

## Cross-document linkage

Every project has multiple sources of truth. Keep them linked:

| Layer | What it tracks | Where it lives |
|---|---|---|
| **Jira Epic + Stories** | Work state (To Do / In Progress / Done) | `https://sambatv.atlassian.net/browse/<KEY>` |
| **Repo `system-design.md`** | Master plan, architecture, locked decisions | `github.com/<user.github>/<repo>` |
| **Repo `memory.md`** | Append-only decision log per session | (same) |
| **Repo `INVESTIGATION-*.md`** | Ad-hoc deep dives when warranted | (same) |
| **Repo `CLAUDE.md`** | Stack, build/test/deploy commands | (same) |

Within Jira:
- Epic description links to the repo + `system-design.md`
- Each Story description references the relevant `§section` of `system-design.md`
- `Blocks` link type wires dependencies between Stories
- `Relates` link type connects to upstream Epics in other projects (e.g. `[ReportGen-MCP]` for Auth0/Currency-API foundations)

## ATF Jira API reference (verified 2026-05-06)

This section captures the actual API behavior. Don't guess — these were validated by live probes during ATF-450 / ATF-451 creation.

### Identifiers

```
cloudId:           a5cee046-a800-4f1a-b616-5eeabc98f82d
project key:       ATF
project name:      Samba AI Task Force
project id:        10394
Sid accountId:     712020:49e85272-34f5-4d10-8231-c73576caa486
```

### Issue type IDs

| Type | ID | Hierarchy | Use for |
|------|-----|-----------|---------|
| Epic | 10524 | 1 | Project-level rollups |
| Story | 10523 | 0 | Vertical slices |
| Task | 10521 | 0 | One-off work that isn't a feature slice |
| Bug | 10522 | 0 | Defects (incl. upstream pipeline issues) |
| Subtask | 10525 | -1 | Below a Story (rarely used in Sid's flow) |
| Initiative | 10848 | 0 | Misconfigured — same level as Task; avoid for now |

### Priority — DO NOT pass plain "Medium"

ATF uses a custom severity-prefixed scheme. Valid priority names:

| Sent | Result |
|------|--------|
| `(SEV1) Critical` | ✅ |
| `(SEV2) High` | ✅ |
| `(SEV3) Medium` | ✅ (also the default if you omit priority) |
| `(SEV4) Low` | ✅ |
| `Medium` | ❌ "Priority: The priority selected is invalid." |
| `High` | ❌ same error |

**Lesson:** if you don't care about priority, **omit it from createJiraIssue** — it auto-defaults to `(SEV3) Medium`. If you need to set it explicitly, use the SEV-prefixed name. Update later via `editJiraIssue` if needed.

### AI Category custom field — `customfield_11335`

Optional but useful. Auto-routes the ticket to the right org cut. Allowed values:

| Name | ID |
|---|---|
| AI Agents & Products | 22140 |
| AI Workflows & Automation | 22141 |
| Training & Adoption | 22142 |
| Governance & Compliance | 22143 |
| Analytics & Measurement | 22144 |
| Infrastructure & Tools | 22145 |
| General AI Initiative | 22146 |

Pass via `additional_fields: {"customfield_11335": {"value": "Analytics & Measurement"}}` (use `value` field with the human-readable name, NOT the id).

### Date fields

```
duedate                  YYYY-MM-DD     ✅ settable on create + edit (both Epic + Story)
customfield_10034        YYYY-MM-DD     "Start date" — Epic-only, settable
created                  auto, RFC 3339 read-only
updated                  auto, RFC 3339 read-only
customfield_10011        Rank           auto-managed by Jira
```

Pass via `additional_fields: {"duedate": "2026-05-30"}`.

### Workflow transitions

ATF uses a simple linear flow:

| Transition ID | To Status |
|---|---|
| 11 | To Do |
| 21 | In Progress |
| 31 | Done |
| 32 | Postponed |

Use `transitionJiraIssue` with `transition: {"id": "21"}` to move a ticket. Not via `editJiraIssue`.

### Link types

The relevant subset:

| Type | id | inward / outward |
|---|---|---|
| Blocks | 10000 | "is blocked by" / "blocks" |
| Relates | 10003 | "relates to" / "relates to" |
| Duplicate | 10002 | "is duplicated by" / "duplicates" |

`createIssueLink` semantics:
- **`inwardIssue`** = the source (e.g. for "A is blocked by B": inwardIssue=B)
- **`outwardIssue`** = the target (e.g. outwardIssue=A)
- For `Relates`, direction doesn't matter (symmetric)

### Parent linking (Epic → Story)

Use `additional_fields: {"parent": {"key": "ATF-450"}}` at create time. The Story will appear under the Epic in the Jira UI. **Do not** use `createIssueLink` for parent — that creates a separate "Relates" link, not a real parent relationship.

### What's NOT in createMeta but works via additional_fields

The Jira `getJiraIssueTypeMetaWithFields` endpoint shows fields available at creation. ATF's createMeta does NOT list `priority` or `labels`, but they CAN be set via the `additional_fields` parameter on `createJiraIssue`:

```json
{
  "additional_fields": {
    "labels": ["trf-dashboard", "msci", "slice-a", "afk"],
    "duedate": "2026-05-30",
    "customfield_11335": {"value": "Analytics & Measurement"},
    "parent": {"key": "ATF-450"}
  }
}
```

Don't pass `priority` here — it'll error unless you use the SEV-prefixed name. Easier: omit it, take the default, edit later.

### Description content format

Pass `contentFormat: "markdown"` on createJiraIssue. The MCP converts to ADF (Atlassian Document Format) internally. Known limitations:
- `[ ]` checkboxes get back-slash-escaped to `\[ \]` in storage. Renders fine in the Jira UI but looks weird in the raw response. Cosmetic only.
- Code blocks render correctly.
- Markdown links `[text](url)` render correctly.

For round-trip fidelity (e.g., when you need to read-edit-write a description without mangling), use `contentFormat: "adf"` and work with the ADF JSON directly. ADF is overkill for normal ticket creation.

## Standard tag set for Sid's projects

Apply these labels consistently so JQL queries cut the board cleanly:

| Label | Meaning |
|---|---|
| `<project-prefix>` | e.g. `trf-dashboard` — appears on every ticket in the project |
| Audience tag | `msci`, `pam`, `exec`, etc. — who consumes the output |
| Slice tag | `slice-a`, `slice-b`, … — for vertical slices in a project |
| `afk` / `hitl` | implementation mode (most slices = `afk`) |
| `tracer-bullet` | optional flag for the first end-to-end slice in a project |
| `upstream` | for tickets that flag bugs in dependencies, not the project itself |

Avoid invented labels per ticket — pick from this set unless there's a real reason to grow it.

## JQL queries that cut the ATF board cleanly

```jql
# Active TRF Dashboard work (everything under the epic + standalones)
project = ATF AND (parent = ATF-450 OR labels = "trf-dashboard") AND statusCategory != Done

# All my open work, sorted by due date
project = ATF AND assignee = currentUser() AND statusCategory != Done ORDER BY duedate ASC

# All work in a specific AI Category
project = ATF AND "AI Category" = "Analytics & Measurement" AND statusCategory != Done

# All upstream-tagged bugs across projects
project = ATF AND issuetype = Bug AND labels = "upstream"

# What's stale (no update in 60 days, still open)
project = ATF AND statusCategory != Done AND updated < -60d
```

## Workflow

### When starting a new project

1. Read the project's `system-design.md` and identify vertical slices (each = one demoable end-to-end cut)
2. Pick the project prefix
3. Create the **Epic** with summary `[<Prefix>] <goal>`. Description includes Goal, Audience, Architecture (one-line), Repo+plan links, Acceptance criteria (epic-level), the children-slice list, Out-of-scope.
4. Create each **Story** as a child of the Epic, using the ticket template above. Use `additional_fields: {"parent": {"key": "<EPIC-KEY>"}}`.
5. Wire `Blocks` links between dependent slices via `createIssueLink`.
6. Create `Relates` links to upstream Epics (e.g. ATF-256 for `[ReportGen-MCP]` Currency API auth foundations).
7. Standalone Tasks/Bugs (one-off cleanup, manual gates, upstream issues) live OUTSIDE the Epic. Tag them with the project prefix label so JQL still finds them.

### Per slice as work progresses

- When you start work: `transitionJiraIssue` with id `21` → `In Progress`
- When you finish: `transitionJiraIssue` with id `31` → `Done`
- If you need to defer: `transitionJiraIssue` with id `32` → `Postponed` (keeps it on the board but out of the active queue)

### Don't

- Don't paste full file contents into ticket descriptions. Reference repo paths instead.
- Don't update the Epic description after kickoff to reflect progress. The Epic is a north-star, not a status board. Status lives on each Story's transition history.
- Don't create Subtasks. Sid's flow uses flat Story-under-Epic. Subtasks add a layer no one navigates.

## Gotchas — Session B (2026-05-06 PM, full slice + sidecar bulk-create)

These are field/auth/MCP behaviors discovered during the bulk-create pass that scaffolded ATF-452 through ATF-461. Each one cost real round-trips during the session — capture them so future bulk creates skip the pain.

### customfield_11335 (AI Category) is NOT on the Bug create screen

Stories, Tasks, and Epics have AI Category on the create screen — passing `customfield_11335: {"value": "Analytics & Measurement"}` works fine. **Bugs do not.** Attempting to set it on Bug creation returns:

```
{"errors":{"customfield_11335":"Field 'customfield_11335' cannot be set. It is not on the appropriate screen, or unknown."}}
```

Workaround: drop `customfield_11335` from `additional_fields` when `issuetypeName: "Bug"`. The Bug ticket gets created without an AI Category. If categorization matters for routing/dashboards, an admin needs to add the field to the Bug create screen (Project settings → Issue types → Bug → Layout). Until then, accept that Bug tickets are AI-Category-less.

The `/jira-create-vertical-slices` skill creates only Stories and is unaffected. If you adapt it to bugs later, drop the field for that issue type.

### Atlassian basic-auth tokens — scoped vs classic matters

The token persisted at `~/.second-brain-harness.env` (auto-loaded via `~/.zshrc`) is what every API call uses. **What scope it has determines what's possible.**

The token used in Session A + B (May 2026) had this asymmetric behavior:

| Endpoint | Result |
|---|---|
| `GET /wiki/api/v2/pages/{id}` (Confluence v2 read) | ✅ 200 |
| `PUT /wiki/api/v2/pages/{id}` (Confluence v2 update body) | ✅ 200 |
| `POST /wiki/api/v2/pages` (Confluence v2 create page) | ❌ 404 (Atlassian's "no permission" signal for v2) |
| `GET /wiki/rest/api/content/{id}/child/attachment` (v1 list attachments) | ❌ 403 "Current user not permitted to use Confluence" |
| `POST /wiki/rest/api/content/{id}/child/attachment` (v1 upload) | ❌ 403 same message |
| `GET /rest/api/3/issue/{key}` (Jira read) | ✅ 200 |
| `POST /rest/api/3/issue` (Jira create) | ✅ 201 |
| `PUT /rest/api/3/issue/{key}` (Jira update) | ✅ 204 |
| `POST /rest/api/3/issueLink` (Jira link) | ✅ 201 |

The pattern — v2 pages allowed for read/update but not create, all v1 REST denied — is the fingerprint of a **scoped/granular API token** (Atlassian's 2024 token model). A scoped token grants only specific scopes (e.g. `read:page:confluence`, `write:page:confluence`).

**Fix:** if you need v1 REST (attachment upload, attachment listing, page create that doesn't go through OAuth/MCP), regenerate as a **classic API token** at <https://id.atlassian.com/manage-profile/security/api-tokens>. Classic tokens inherit the user's full Confluence + Jira product permissions — the asymmetric 403/404s go away.

**Workaround used in Session B:** Confluence page CREATE went through `mcp__atlassian__createConfluencePage` (OAuth path, full scope). Page UPDATE went through direct REST PUT (token's v2 scope). Attachment upload was skipped — diagrams embedded as external mermaid.ink URLs instead. This hybrid worked but flagged the limitation.

### Direct Jira REST PUT for batch description updates is faster than MCP

When you need to update many Jira ticket descriptions with full ADF (e.g., after bulk-creating slices with markdown placeholders), prefer:

```bash
curl -s -X PUT \
  -H "Authorization: Basic $ATLASSIAN_BASIC_AUTH" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --argjson adf "$ADF" '{fields: {description: $adf}}')" \
  "https://sambatv.atlassian.net/rest/api/3/issue/$KEY"
```

over `mcp__atlassian__editJiraIssue` for batch loops. Reasons:
- **Faster** — no MCP roundtrip overhead. ~0.5–1s/ticket vs 2–4s via MCP.
- **No "fields" wrapping confusion** — the REST API takes `{fields: {description: <ADF>}}` cleanly. The MCP tool occasionally normalizes the ADF on read-back, which is confusing.
- **Returns HTTP 204 on success** — easy to assert in batch scripts.

Use the MCP for one-off edits where the niceties (issue resolution, validation, friendly errors) help. Use REST PUT for tight loops.

### MCP normalizes ADF → markdown on read

When you call `mcp__atlassian__getJiraIssue` (or `editJiraIssue` and look at the response), the `description` field comes back as **markdown**, even when the underlying storage is ADF (with taskList nodes for AC checkboxes, etc.).

This is cosmetic — the storage is still ADF. But it means:
- ADF taskList in the description shows up as `- [ ]` markdown in the response
- Verifying interactive checkboxes need a browser visit, not the API response
- Round-trip ADF→markdown→ADF via the MCP loses the taskList structure (becomes regular bullet list)

**Safe pattern for AC editing:** always send full ADF via `editJiraIssue` with `contentFormat: "adf"`, never read-modify-write the markdown form.

## Test cases (verified 2026-05-06)

These are the ATF tickets the conventions doc was validated against. If anything in this doc seems wrong, re-read these tickets — actual behavior is the source of truth.

### Session A (early 2026-05-06): test pair

| Key | Type | Purpose |
|---|---|---|
| [ATF-450](https://sambatv.atlassian.net/browse/ATF-450) | Epic | `[TRF-Dashboard]` epic |
| [ATF-451](https://sambatv.atlassian.net/browse/ATF-451) | Story | Slice A — hello-world ingestion |

### Session B (later 2026-05-06): full bulk-create

| Key | Type | Purpose | Custom fields |
|---|---|---|---|
| [ATF-452](https://sambatv.atlassian.net/browse/ATF-452) | Story | Slice B — end-to-end deploy with one row | parent=ATF-450, AI Cat=Analytics & Measurement, Team=AI Task Force |
| [ATF-453](https://sambatv.atlassian.net/browse/ATF-453) | Story | Slice C — full discovery + retry-handling | (same) |
| [ATF-454](https://sambatv.atlassian.net/browse/ATF-454) | Story | Slice D — 7 quality rules + industry canonicalization | (same) |
| [ATF-455](https://sambatv.atlassian.net/browse/ATF-455) | Story | Slice E — 5-check validation gate + atomic BQ write | (same) |
| [ATF-456](https://sambatv.atlassian.net/browse/ATF-456) | Story | Slice F — Cloud Run deploy + daily Cloud Scheduler | (same) |
| [ATF-457](https://sambatv.atlassian.net/browse/ATF-457) | Story | Slice G — observability + transparency footer | (same) |
| [ATF-458](https://sambatv.atlassian.net/browse/ATF-458) | Task | HITL: apply Cloudflare Access policy | label=trf-dashboard,hitl,blocker |
| [ATF-459](https://sambatv.atlassian.net/browse/ATF-459) | Task | HITL: confirm dedup rule with MSCI | label=trf-dashboard,hitl,msci |
| [ATF-460](https://sambatv.atlassian.net/browse/ATF-460) | Bug | [Upstream] Status column corruption | **AI Cat omitted (not on Bug screen)**, Relates ATF-258 |
| [ATF-461](https://sambatv.atlassian.net/browse/ATF-461) | Bug | [Upstream] Other Unclassified industry | **AI Cat omitted**, Relates ATF-258 |

JQL to find the family: `labels = "trf-dashboard" ORDER BY key ASC`

## Skills that descended from this doc

This doc graduated to skills on 2026-05-06 PM (immediately after Session B), once the pattern had been used end-to-end on a real project (TRF Dashboard).

- **`/jira-create-vertical-slices`** at `.claude/skills/jira-create-vertical-slices/`. Reads a YAML/JSON spec, bulk-creates Stories under an Epic with consistent shape, wires Blocks links. Replaces the manual loop of 7 createJiraIssue + 7 editJiraIssue + 6 createIssueLink calls. Uses this conventions doc as the API reference.

The promotion was earlier than the original "wait for 3 projects" criterion — but the manual cost was high enough (≈ 1 hour for 7 slices) that automating after one project was justified. Skill is non-idempotent by design (re-running creates duplicates) and pre-flights the Epic + blocked-by chain before any mutations.

Pending future skills (from the planning conversation 2026-05-06 PM):
- **`/confluence-publish-markdown`** at `.claude/skills/confluence-publish-markdown/` — sister skill for porting markdown to Confluence with mermaid diagrams. Often paired with `/jira-create-vertical-slices` (publish design doc → cite from slices).
- **`/scaffold-engineering-project`** — combined wrapper that calls both atomic skills. Build last, after each atomic skill has been used 2+ more times.
