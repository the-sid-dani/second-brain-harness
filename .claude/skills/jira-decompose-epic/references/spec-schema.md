# jira-decompose-epic — spec schema

The skill consumes a YAML or JSON spec file. This doc describes every field, what
it means, what's required, and what's optional. Use `assets/example-spec.yaml`
as a working starting point — it models the actual trf-benchmark-dashboard run
from 2026-05-06.

---

## Top-level fields

All required unless noted.

| Field | Type | Description |
|---|---|---|
| `epic_key` | string | Existing Jira Epic key, e.g. `ATF-450`. Pre-flight will GET this and abort if it doesn't exist. |
| `cloud_id` | string | Atlassian cloudId UUID for your tenant (e.g. `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`). Find via `mcp__atlassian__getAccessibleAtlassianResources`. (Reserved for future use; current REST path uses the host directly, not cloudId.) |
| `project_key` | string | Jira project key, e.g. `PROJ`. Stories will be created in this project. |
| `assignee_account_id` | string | Default assignee for all created Stories. Find via `mcp__atlassian__atlassianUserInfo` or the user profile URL. Format: `nnnnnn:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`. |
| `team_uuid` | string | Value for `customfield_10001` (Team field) — your team's UUID in Atlassian. **Plain string**, not an object — Jira's "Team" field accepts the UUID directly. (Custom-field IDs like `customfield_10001` may differ in your instance — verify via `mcp__atlassian__getJiraIssueTypeMetaWithFields`.) |
| `ai_category` | string | Value for a custom dropdown field (e.g. `customfield_11335`). Set example values that match your instance's allowed options. The skill wraps it as `{"value": <ai_category>}`. |
| `label` | string | Single label applied to all created Stories — used for JQL-finding the family later (`labels = "trf-dashboard"`). |
| `confluence_hub_url` | string | URL of the project's Confluence hub page. Goes into the header info panel of every slice. Empty string `""` if no hub yet. |
| `confluence_design_url` | string | URL of the System Design page (the source-of-truth for slice §-references). Goes into the header panel + the Reference docs section. Required — slice descriptions reference §-numbered sections of this page. |
| `repo_url` | string | GitHub repo URL. Goes into the header panel. |
| `slices` | list | Array of slice specs. Order matters: slices are created in array order, and `blocked_by_letter` references must point at slices that appear earlier in the array (so the blocker exists when the blocked slice's description is rendered). |

---

## Slice fields

Each entry in the `slices` array.

| Field | Type | Required | Description |
|---|---|---|---|
| `letter` | string (1 char) | yes | Letter identifier like `A`, `B`, `C`. Used as the slice's name in cross-references and as the Block-link key. Must be unique within the spec. |
| `summary` | string | yes | Jira ticket summary — the title of the Story. Convention: `[<Project-Tag>] Slice <Letter>: <description>`. |
| `sd_sections` | list of strings | yes | Sections of the System Design page this slice implements. Rendered as `§3 (steps 1-3), §8 auth model` in the header panel and Reference docs. Strings can be free-form: `"3 (steps 1-3)"`, `"4 rule A"`, `"5 (validation gate)"`. |
| `what_to_build` | list of strings | yes | One paragraph per array entry. Each string is rendered as a paragraph in the description, inline markdown (`code`, **strong**, _em_, `[text](url)`) preserved. Keep paragraphs focused — 2-4 paragraphs is typical. |
| `ac_items` | list of strings | yes | Acceptance criteria, one per array entry. Rendered as an ADF taskList (interactive checkboxes). Inline markdown preserved. Don't prefix with `- [ ]` — that's the markdown convention; the skill wraps each item in a `taskItem`. |
| `blocked_by_letter` | string (1 char) or null | no | If this slice depends on another slice in the same spec, set this to the blocker's `letter`. The skill renders the Blocked-by section pointing at the blocker's actual issue key (resolved at create time) and creates a Jira `Blocks` link after all slices exist. Null = no dependency. |
| `blocked_by_note` | string | no | Extra prose appended after the blocker key in the Blocked-by section. E.g. `"needs the test table populated with at least one row"`. |
| `slice_type` | string | no | `AFK` (default — agent-implementable end-to-end) or `HITL` (human-in-the-loop step required). Renders a single sentence under the "Slice type" heading. |
| `notes` | list of strings | no | Italicized paragraphs at the bottom of the description. Use for caveats, "this is deferred to Slice X", deferred-decision pointers. Each string becomes one `<p><em>...</em></p>`. |
| `extra_refs` | list of strings | no | Additional bullet items appended to the Reference docs section. Inline markdown preserved. Use for paths to other repos, secondary docs, etc. |

---

## Inline markdown — what gets parsed

The skill parses these inline markers in `what_to_build`, `ac_items`, `blocked_by_note`, and `extra_refs`:

| Marker | ADF result |
|---|---|
| `` `code` `` | text node with `code` mark |
| `**strong**` | text node with `strong` mark |
| `_em_` | text node with `em` mark |
| `[label](url)` | text node with `link` mark, attrs.href = url |

Plain text passes through. Nested marks (e.g. **`bold-and-code`**) are NOT supported — keep markers separate.

If you need richer formatting (panels, tables, code blocks), the spec format
isn't the right tool. Either edit the description after the skill runs, or extend
the skill to read a richer per-slice description from a separate file path.

---

## Idempotency and re-runs

This skill is **not idempotent**. There's no built-in dedup. If the script
fails halfway through:

1. Check what got created via `JQL: labels = "<your label>" ORDER BY key DESC`
2. Either delete the partial tickets and re-run from scratch, or
3. Edit the spec to remove the slices that already created, then run for the rest

The pre-flight check (`--validate-only`) catches most pre-create errors. Once
creation has started, partial completion is the failure mode you have to
manage manually.

---

## Custom field caveats

These are the gotchas captured in the trf-benchmark-dashboard session that this
skill silently handles or warns about:

- **AI Category not on Bug screen.** This skill creates Stories only — AI Category always works. If you adapt for Bugs, drop the `customfield_11335` field from the create payload.
- **Team UUID is a plain string.** Pass `"77854ec1-..."` not `{"value": "..."}`.
- **Priority defaulted.** Skill omits priority — Jira defaults to `(SEV3) Medium`. Explicitly setting `"Medium"` errors; you'd need `(SEV3) Medium` if you set it. Adjust the script if you need non-default priority.
- **Parent linking via `parent` field, not `customfield_10014`.** The skill uses `additional_fields.parent.key` which is the modern Jira Cloud path.
- **Workflow status defaults to To Do.** No transitions applied at create time. If you need slices to start in a different status, adjust the script to issue a transition POST after create.

---

## Auth and env

The skill requires these env vars at runtime:

| Var | Purpose |
|---|---|
| `ATLASSIAN_BASIC_AUTH` | base64(`email:token`) string for HTTP Basic auth on Jira REST. Auto-loaded via `~/.zshrc` → `~/.second-brain-os.env`. |

The token must support:
- `POST /rest/api/3/issue` (create)
- `PUT /rest/api/3/issue/{key}` (update description)
- `POST /rest/api/3/issueLink` (Blocks links)

Scoped Atlassian tokens may lack one of these. If you hit 403s, regenerate as
a **classic** API token at <https://id.atlassian.com/manage-profile/security/api-tokens>.

---

## Testing your spec before running

Always do this before the real run:

```bash
python <skill-path>/scripts/create_slices.py --spec my-spec.yaml --validate-only
```

The validate-only mode confirms the Epic exists, all blocked-by references are
resolvable, and prints what would be created. Costs zero Jira mutations.
