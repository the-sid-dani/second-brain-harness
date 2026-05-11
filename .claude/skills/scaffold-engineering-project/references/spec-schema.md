# scaffold-engineering-project — combined spec schema

The skill consumes a single combined YAML/JSON spec that drives both the Confluence publishing and the Jira slice creation. Schema below; worked example in `assets/example-spec.yaml`.

## Top-level fields

All required unless noted.

### Project metadata

| Field | Type | Required? | Description |
|---|---|---|---|
| `project_name` | string | yes | Display name, e.g. "TRF Benchmark Dashboard" |
| `project_prefix` | string | yes | Short ticket prefix, e.g. "TRF-Dashboard" — used in slice summaries |
| `project_owner` | string | no | Owner name; goes in hub footer + design header |
| `project_goal` | string | no | One-line goal; goes in hub info panel |
| `audience` | string | no | Audience description; goes in hub info panel |
| `project_status_line` | string | no | Status sentence used in design page header (e.g. "v2 design locked 2026-05-06.") |
| `architecture_summary` | string | no | One-paragraph architecture summary for the hub page |
| `out_of_scope` | list of strings | no | Bullet items for the hub's "What's NOT in scope" panel |
| `phases` | list of `{label, color}` | no | Status lozenges row on hub. Default: two lozenges "DESIGNED" and "BUILD PENDING", both yellow |

### Repo + deployment

| Field | Type | Required? | Description |
|---|---|---|---|
| `repo_url` | URL | yes | Source repo |
| `live_url` | URL | no | Deployed/live URL if any |

### Atlassian targets

| Field | Type | Required? | Description |
|---|---|---|---|
| `epic_key` | string | yes | Existing Jira Epic key — must already exist; skill validates |
| `cloud_id` | string | yes | Atlassian cloudId UUID (sambatv: `a5cee046-...`) |
| `project_key` | string | yes | Jira project key (e.g. `ATF`) |
| `assignee_account_id` | string | yes | Default assignee for slices (also used as project_owner if not set) |
| `team_uuid` | string | yes | Jira Team customfield_10001 value |
| `ai_category` | string | yes | Jira customfield_11335 value |
| `label` | string | yes | Single label applied to all slices |
| `confluence_space_id` | string | yes | Confluence space ID (ATF: `14288191609`) |
| `confluence_parent_id` | string | yes | Parent page ID where hub + design + extras land as children |
| `hub_page_title` | string | yes | Title of the hub page to be created (e.g. "TRF Benchmark Dashboard") |

### Documents to publish

| Field | Type | Required? | Description |
|---|---|---|---|
| `design_doc.path` | string | yes | Path to system-design.md, **relative to the spec file** |
| `design_doc.title` | string | yes | Title for the published design Confluence page |
| `extra_children` | list of `{path, title}` | no | Additional markdown docs to publish as siblings of the design page |

### Slices

| Field | Type | Required? | Description |
|---|---|---|---|
| `slices` | list | yes | Array of slice specs — same schema as `/jira-decompose-epic`'s `slices` field |

See `/jira-decompose-epic` `references/spec-schema.md` for the slice item schema (letter, summary, sd_sections, what_to_build, ac_items, blocked_by_letter, slice_type, notes, extra_refs).

The wrapper's slice-spec materialization step **automatically fills in** `confluence_hub_url` and `confluence_design_url` from the just-created Confluence pages — the user does NOT need to provide those at the wrapper-spec level.

---

## What the skill creates

For a typical run with N slices and M extra child pages:

| Artifact | Where | Source |
|---|---|---|
| Design Confluence page | child of `confluence_parent_id` | `design_doc.path` markdown |
| M extra Confluence pages | siblings of design page | `extra_children[].path` markdowns |
| Hub Confluence page | child of `confluence_parent_id` (sibling of design) | generated from spec metadata |
| N Jira Story tickets | children of `epic_key` | `slices` array |
| Sequential Blocks links | between dependent slices | derived from `blocked_by_letter` chain |

Total round-trips: 1 (design) + M (extras) + 1 (hub) + N + N + (Blocks-link count). For typical N=7 + M=1, that's ≈ 17–24 calls in one batch.

---

## Recovery flags

If a partial run fails:

| Flag | Use case |
|---|---|
| `--hub-page-id <id>` | Hub page already created (e.g. via MCP); update it instead of creating new. Useful when `POST /api/v2/pages` returned 404 (scoped token) and you fell back to manual MCP create. |

The atomic skills' own recovery patterns apply for design / extras / slices — see their docs.

---

## Validation

Always run with `--validate-only` first:

```bash
python <skill>/scripts/scaffold.py --spec my-spec.yaml --validate-only
```

This validates:
1. Combined spec shape
2. Epic exists (Jira REST GET)
3. Confluence parent exists (REST GET)
4. design_doc + each extra_children path resolves to a real file
5. Each markdown's mermaid blocks compile (via mermaid.ink)
6. Slice spec validates via `/jira-decompose-epic` validator (Epic exists, blocked_by_letter chain resolves)

Costs zero mutations.
