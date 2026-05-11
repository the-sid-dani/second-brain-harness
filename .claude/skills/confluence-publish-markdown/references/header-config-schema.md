# confluence-publish-markdown — header config schema

The `--header-config <path>` flag points at a YAML or JSON file. The skill prepends an info-panel to the published page using these fields. All fields are optional, but the panel must include at least one link or summary.

## Schema

```yaml
# Optional one-line summary at the top of the panel (italicized).
# Use it to give the page a one-sentence tagline.
summary: "v2 design locked 2026-05-06. Build pending design approval."

# Optional. URL of the source repo. Goes into the panel as: "Repo: <displayed-url>".
repo_url: https://github.com/your-org/example-project

# Optional. URL of a deployed/live version of whatever this doc describes.
live_url: https://trf-benchmark.pages.dev

# Optional. Confluence URL of the project's hub page. Useful for cross-doc nav.
confluence_hub: https://sambatv.atlassian.net/wiki/spaces/ATF/pages/14810218661/...

# Optional. Jira Epic key (just the key, like "ATF-450" — the skill builds the URL).
jira_epic: ATF-450

# Optional. Any additional links not covered above.
extra_links:
  - label: "Related ADR: ADR-042"
    url: https://your-company.atlassian.net/wiki/spaces/EXAMPLE/pages/123456789/ADR-042
  - label: "Pipeline Audit (source spec)"
    url: file:///path/to/local/spec.html
```

## Rendered output

The above config produces an ADF info panel containing:

1. An italicized summary line (if `summary` provided)
2. A single paragraph with bolded labels + linked URLs, separated by `  ·  `:

```
[INFO PANEL]
v2 design locked 2026-05-06. Build pending design approval.

Repo: github.com/your-org/example-project  ·  Live: example.pages.dev  ·  Confluence hub: Confluence hub  ·  Jira Epic (ABC-123): Jira Epic (ABC-123)  ·  Related ADR: ADR-042
```

(The `·` separator and bolded labels match the trf-benchmark-dashboard hub page rendering from 2026-05-06.)

## Field semantics

| Field | Required? | Type | Notes |
|---|---|---|---|
| `summary` | no | string | One-line italicized intro |
| `repo_url` | no | URL | Display: `github.com/...` (https stripped) |
| `live_url` | no | URL | Display: hostname (https stripped) |
| `confluence_hub` | no | URL | Display: "Confluence hub" |
| `jira_epic` | no | string (key) | Skill auto-builds `https://sambatv.atlassian.net/browse/<key>` |
| `extra_links` | no | list of `{label, url}` | Appended after the canned links |

## Empty config = error

If neither `summary` nor any link is provided, the skill exits with an error. An empty header panel adds clutter, not value — better to omit `--header-config` entirely.

## Why YAML and JSON both?

Same as `/jira-create-vertical-slices` — YAML for human editing, JSON for tool-generated configs. Auto-detected by extension.
