---
name: scaffold-engineering-project
description: One-command project scaffold combining Confluence + Jira. Given an existing Jira Epic and a repo with `system-design.md` (and optionally other markdown design docs), the skill publishes the markdown docs to Confluence as a hub-and-spokes structure, then bulk-creates the vertical-slice Stories under the Epic with full cross-links. Use this whenever <user.name> wants to scaffold a new engineering project end-to-end — phrases like "scaffold this engineering project", "set up Confluence + Jira for X", "land this design across both wikis", "boot the project tracking for X", "wire up Confluence and Jira for the new initiative", "publish the design doc and create the slices", or any intent to spin up project-tracking infrastructure all at once. Trigger broadly on combined-publish-and-ticket intent. The skill is a thin orchestration wrapper around `/confluence-publish-markdown` and `/jira-create-vertical-slices` plus its own hub-page generation. Use the atomic skills directly when you only need one half of the workflow.
---

# scaffold-engineering-project

Wrapper for the full scaffold workflow that <user.name> + <assistant.name> ran by hand for trf-benchmark-dashboard on 2026-05-06: design markdown → Confluence pages → project hub → Epic + Slices in Jira → cross-links wired everywhere. ~1 hour by hand; ~30 seconds via this skill.

The skill **assumes the Epic already exists**. Epic creation is rare per project, the metadata varies enough that automating it adds little value, and creating one manually takes 1 minute via `mcp__atlassian__createJiraIssue` or the Jira UI.

## When this triggers

Use this skill when:
- A new engineering project just had its design locked
- The design lives as markdown in a repo (typically `system-design.md` + optional `INVESTIGATION-*.md` etc.)
- A Jira Epic exists for the project
- You want Confluence pages (hub + design + extras) AND Jira slices created in one shot, with cross-links wired

Do NOT use this skill when:
- You only need one half — use the atomic skill (`/confluence-publish-markdown` or `/jira-create-vertical-slices`) directly
- The Epic doesn't exist yet — create it first (Jira UI or single `createJiraIssue` call)
- The project doesn't fit the hub-and-spokes pattern (e.g., it's a one-doc-no-slices effort) — use one of the atomic skills

## What it produces

For a spec describing project X with N slices:

1. **One Confluence design page** (child of `parent_page_id` from the spec) — full port of `system-design.md` with mermaid diagrams + standard header panel
2. **0..M extra Confluence pages** — additional markdown docs published as siblings of the design page (e.g., investigations, runbooks)
3. **One Confluence hub page** (also child of `parent_page_id`) — the project's landing page with status lozenges, active links table, architecture summary, links to all design + extras + the Jira Epic
4. **N Jira Story tickets** under the Epic, with the standard slice shape (header info panel, taskList AC, parent linkage, custom fields, label, Blocks links)

Hub + design + extras + each slice all reference each other:
- Hub links to: design, extras, Jira Epic, repo, live URL
- Design + extras: header panel links to hub, repo, live URL, Jira Epic
- Each slice's header panel links to hub, design page, repo
- Jira Epic description (manually maintained — skill doesn't update Epic) ideally references the hub

## Workflow

### Step 1 — Confirm or build the spec

The skill consumes a single combined YAML/JSON spec. Schema in `references/spec-schema.md`. Worked example in `assets/example-spec.yaml` (modeled exactly on trf-benchmark-dashboard).

The spec has three sections:

1. **Project metadata** — name, prefix, owner, repo, live URL, Confluence space + parent IDs
2. **Documents to publish** — the design doc (required) and any extras
3. **Slices** — same shape as `/jira-create-vertical-slices` spec, just inline

The user (or <assistant.name>) can write the spec from a `system-design.md` directly — most fields are obvious. Get sign-off on the spec before running; this is bulk creation across two systems.

### Step 2 — Pre-flight

Run `scripts/scaffold.py --spec <path> --validate-only` to:

1. Validate the combined spec
2. Validate the underlying slice spec (delegates to `/jira-create-vertical-slices` validator)
3. Confirm the Epic exists
4. Confirm the Confluence parent page exists
5. Confirm all referenced markdown files exist and parse
6. Compile-check every mermaid block in every markdown via mermaid.ink
7. Print a plan of what will be created — Confluence pages, Jira tickets, links

### Step 3 — Execute

Run the same command without `--validate-only`. The script:

1. **Publishes the design page** via `/confluence-publish-markdown` (subprocess) — captures the new page ID
2. **Publishes each extra page** the same way — captures their IDs
3. **Builds and POSTs the hub page** (this logic lives in the wrapper, not in `/confluence-publish-markdown`) — info panel, status lozenges, active links table, architecture summary, children list, out-of-scope panel
4. **Constructs a slice spec dict** with the just-created Confluence URLs filled in
5. **Calls** `/jira-create-vertical-slices` (subprocess) with the materialized spec
6. **Prints a final summary** — every created Confluence URL, every created Jira ticket key, the JQL to find them

### Step 4 — Verify

Open the hub page first. Confirm:
- Status lozenges render
- Active links table works (each link clicks through)
- Children list points at the design + extra pages
- Architecture summary is accurate

Then sample one slice (e.g., Slice A in the Jira board) and confirm:
- Parent linkage shows the Epic in the side panel
- AC checkboxes are interactive
- The "Confluence: System Design" link in the header lands on the design page

## Composability

This skill **calls the atomic skills via subprocess**, not via Python imports. That keeps each skill independently usable.

If `/confluence-publish-markdown` or `/jira-create-vertical-slices` is updated independently, this wrapper picks up the changes automatically — no shared-module versioning.

The hub-page generation is **unique to this wrapper** (not exposed as a separate skill). The atomic Confluence skill ports markdown 1:1; the hub page is generated from the spec metadata, not from a markdown file. If hub-page generation grows enough features, it could be promoted to its own skill — for now it's a private function inside `scripts/scaffold.py`.

## Idempotency — non-idempotent and dangerous

This skill is **not idempotent at any layer**:

- Re-running creates duplicate Confluence pages (one per doc, plus a duplicate hub)
- Re-running creates duplicate Jira slices

If the script fails partway through, you have to manually clean up partial state before re-running. Plan for this:

- The script publishes Confluence pages first, prints their IDs to stdout, **then** creates Jira slices. If Jira creation fails, the Confluence pages still exist. You can either re-use them (manual: pass their IDs into a follow-up run of `/jira-create-vertical-slices` directly) or delete them.
- If hub-page POST fails, the design + extra pages still exist. Same recovery — point a follow-up tool at them.

For first-run safety, **always do `--validate-only` first**. The validate phase is cheap — confirms Epic + parent page + every markdown file + every mermaid block, costs zero mutations.

## Auth + dependencies

Same as the atomic skills:
- `ATLASSIAN_BASIC_AUTH` env var (auto-loaded via `~/.zshrc` → `~/.daily-agents.env`)
- Python 3.10+ with `mistletoe` and `pyyaml` (transitively via the atomic skills)
- mermaid.ink reachable for diagram rendering

## Files in this skill

- `scripts/scaffold.py` — the orchestrator. Validates spec, calls atomic skills via subprocess, generates the hub page directly.
- `references/spec-schema.md` — combined spec format with field-by-field semantics
- `assets/example-spec.yaml` — full worked example modeling trf-benchmark-dashboard

## When this skill is the wrong tool

- **Already-published Confluence pages + already-created slices, just need them cross-linked** → manual edits or extend the atomic skills with an "update existing" mode. The wrapper assumes greenfield publish.
- **One-shot single-doc-to-Confluence** → use `/confluence-publish-markdown` directly
- **Just bulk-creating slices, no Confluence work** → use `/jira-create-vertical-slices` directly
- **Creating the Epic itself** → out of scope (use `mcp__atlassian__createJiraIssue` first)

## Maturity

**v0 — built immediately after the atomic skills, before either had been used 2+ more times.** This is earlier than the workspace's "Eliminate before automate" Operating Principle would normally allow — built only because <user.name> requested all four skills at once and the cost of the manual workflow is steep enough (1 hour per project) that having the wrapper available even at v0 saves time.

Expect rough edges. Specifically expected to evolve:
- Better error recovery on partial-batch failures
- Optional skill flag to update existing Confluence pages (rather than create new) when re-running
- Smarter hub-page template (currently hardcoded to the trf-dashboard shape)
- Automatic Epic-description update to link back to the hub once created
