---
name: confluence-publish-markdown
description: Port a local markdown file (design doc, investigation report, runbook) to a Confluence page in one command — handles the full markdown → ADF conversion, renders embedded mermaid diagrams via mermaid.ink as external media (no attachment upload required), and optionally injects a standard header info panel with Repo / Live / Jira cross-links. Use this whenever <user.name> wants to publish a markdown file to Confluence — phrases like "publish this design doc to Confluence", "port this markdown to ATF space", "create a Confluence page from this .md", "ship the system-design.md to the wiki", "put this report on Confluence", "update the Confluence page with my markdown", or any time a local markdown artifact needs to become a Confluence page. Trigger broadly on markdown-to-Confluence intent. Both create-new (with `--parent-id`) and update-existing (with `--page-id`) modes are supported. Models exactly the workflow <user.name> + <assistant.name> ran by hand for trf-benchmark-dashboard's system-design.md and INVESTIGATION-994.md on 2026-05-06.
---

# confluence-publish-markdown

Models the pattern that took an hour by hand for trf-benchmark-dashboard: a markdown doc in the repo, three mermaid diagrams, a 200-line Python ADF builder per doc, three round-trips. This skill turns it into one command. Markdown stays the source of truth; Confluence becomes a rendered view.

The skill is **deliberately scoped** to design docs / runbooks / investigation reports — text-heavy docs with occasional diagrams. It is NOT for porting fully designed Confluence pages (with custom layouts, advanced macros) — those need the editor.

## When this triggers

Use this skill when:
- The user has a markdown file ready (typically in a code repo as the canonical doc)
- They want it as a Confluence page — either creating a new child of a parent, or replacing the body of an existing page
- The doc may contain mermaid diagrams that need to render
- A standard header info panel (Repo / Dashboard / Jira links) is wanted at the top

Do NOT use this skill when:
- The page needs Confluence-native macros (panels stacked in custom ways, expand/collapse, decision lists, JIRA inline issues) — drop into the editor
- The markdown has unusual elements (LaTeX, footnotes, definition lists) — see `references/markdown-subset.md` for what's supported
- You want the canonical source to live in Confluence and pull *down* — opposite direction, different skill

## Workflow

### Step 1 — Confirm or build the header config

The skill optionally injects a standard header info panel at the top of the page with Repo / Live / Jira links. If the user wants this:

- Pass `--header-config <path-to-yaml>` pointing to a YAML or JSON file
- Schema in `references/header-config-schema.md`
- Worked example in `assets/example-header.yaml`

If the user doesn't want a header panel, omit the flag — the page renders just the markdown body.

The header config is **optional but recommended for project docs** — without it, readers landing on the page have no way to navigate to the repo or related Jira tickets.

### Step 2 — Pre-flight

Run `scripts/publish_markdown.py --markdown <path> --parent-id <id> --validate-only` to:

1. Parse the markdown — confirm it's valid
2. Extract mermaid blocks; for each, render to PNG via mermaid.ink to confirm syntax compiles (HTTP 200 + non-empty body)
3. Confirm parent page exists (or `--page-id` resolves) via Atlassian REST
4. If `--header-config` supplied, validate it against the schema

If any check fails, the script exits non-zero with a clear message.

### Step 3 — Execute

Run the same command without `--validate-only`. The script:

1. Parses the markdown into an AST (using `mistletoe`)
2. Walks the AST, emitting ADF nodes — headings, paragraphs, lists, tables, code blocks, inline marks
3. Mermaid code blocks become mediaSingle with `type: external` and the mermaid.ink URL
4. If header config given, prepends an info panel with the standard cross-links
5. POSTs (create) or PUTs (update) to Confluence

Output: the page URL and ID, plus a short summary.

### Step 4 — Verify

Open the page URL and spot-check:
- The header panel renders (if configured)
- Mermaid diagrams display (they're external images, so first load may take a second)
- Tables and code blocks look right
- Links work

If a mermaid diagram fails to render in Confluence (rare — usually mermaid.ink syntax issue), the script's pre-flight should have caught it. If it didn't, the diagram URL is in the script output — open it in a browser to see the mermaid.ink error.

## Two modes — create vs update

**Create new page** (most common): `--parent-id <id>` — page becomes a child of the given parent.
**Update existing page**: `--page-id <id>` — replaces the body of the given page, bumps version.

The skill auto-detects from which flag is given. You can't pass both. If you want to convert "create-or-update" semantics (find by title under parent, create if missing, update if present), call the skill twice or extend it later.

## Mermaid via mermaid.ink

Confluence Cloud doesn't render mermaid natively in every space. Workaround: render to PNG via mermaid.ink (free service), embed as external media. This is what the skill does.

Why external media instead of uploaded attachments:
- Attachment upload requires a different token scope (some scoped Atlassian tokens can't upload — flagged this in 2026-05-06 session)
- External media is simpler: just a URL, no roundtrip
- mermaid.ink hosts the rendered PNG indefinitely and regenerates from the URL-encoded source

Tradeoff: relies on mermaid.ink uptime. If mermaid.ink is down, your diagrams 404. Acceptable for internal docs; reconsider for external-facing pages.

## Markdown subset supported

See `references/markdown-subset.md` for the complete list. Quick summary:

✅ Supported: headings (1-6), paragraphs, bullet/numbered lists, fenced code blocks (with language), pipe tables, inline `code`, **bold**, _italic_, [links](url), blockquotes, horizontal rules, mermaid blocks.

❌ Not supported (will be passed through as text or skipped): images (use mermaid for diagrams; for photos, attach manually after publish), LaTeX, footnotes, definition lists, task lists (use ADF taskList directly via API for those — different skill).

## Files in this skill

- `scripts/publish_markdown.py` — the workhorse. Reads markdown, converts to ADF, embeds mermaid, posts to Confluence.
- `references/markdown-subset.md` — exactly what markdown is and isn't supported
- `references/header-config-schema.md` — the optional header config format
- `assets/example-header.yaml` — sample config for the header info panel

## Auth

Same as `/jira-create-vertical-slices`: requires `ATLASSIAN_BASIC_AUTH` env var (auto-loaded via `~/.zshrc` → `~/.daily-agents.env`).

For Confluence specifically: the basic-auth token must support both:
- `GET /wiki/api/v2/pages/{id}` — for parent/page validation
- `PUT /wiki/api/v2/pages/{id}` — for body updates (works on scoped tokens)
- `POST /wiki/api/v2/pages` — for creating new pages

If `POST /wiki/api/v2/pages` fails with 404 (Atlassian's signal for "not permitted"), the token is too narrow. The skill falls back to using the Atlassian MCP `mcp__atlassian__createConfluencePage` for the initial create, then PUTs the body via REST. This hybrid path was empirically required during the 2026-05-06 session.

## When this skill is the wrong tool

- **Confluence page → markdown** → opposite direction; not supported.
- **Bulk-publish many markdowns at once** → run the skill in a loop. Or extend it to take a list-of-files spec.
- **Updating a single section of an existing page** → no, the skill replaces the whole body. Use the editor for surgical edits.
- **Pages with rich Confluence macros** → the markdown subset can't express macros. Drop into the editor.

## Idempotency

Update mode (`--page-id`) is idempotent: running twice with the same input produces the same final body (plus two version bumps). Create mode is **not** — running twice creates duplicate pages. To support create-or-update, look up by title under the parent first; the skill doesn't do this automatically because page-title fuzzy matching is unreliable.
