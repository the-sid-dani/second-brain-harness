#!/usr/bin/env python3
"""End-to-end engineering project scaffold:
  1. Publish design doc + optional extras to Confluence (via /confluence-publish-markdown)
  2. Generate + create the project hub page (this script's unique logic)
  3. Bulk-create vertical-slice Stories under the Epic (via /jira-create-vertical-slices)

Usage:
    python scaffold.py --spec <path>                # full run
    python scaffold.py --spec <path> --validate-only  # pre-flight only

Spec: YAML or JSON. Schema in ../references/spec-schema.md.
Auth: ATLASSIAN_BASIC_AUTH env var (auto-loaded via ~/.zshrc → ~/.daily-agents.env).

This script delegates to two sibling skills:
- /confluence-publish-markdown
- /jira-create-vertical-slices
Both must be installed at sibling paths under .claude/skills/.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

CONF_BASE = "https://sambatv.atlassian.net/wiki"
TIMEOUT_SEC = 30

# ============================================================================
# Resolve sibling skill paths
# ============================================================================

SKILL_DIR = Path(__file__).resolve().parent.parent
SKILLS_ROOT = SKILL_DIR.parent

PUBLISH_MD_SCRIPT = SKILLS_ROOT / "confluence-publish-markdown" / "scripts" / "publish_markdown.py"
CREATE_SLICES_SCRIPT = SKILLS_ROOT / "jira-create-vertical-slices" / "scripts" / "create_slices.py"


def assert_sibling_skills_present() -> None:
    missing = []
    for label, path in [
        ("/confluence-publish-markdown", PUBLISH_MD_SCRIPT),
        ("/jira-create-vertical-slices", CREATE_SLICES_SCRIPT),
    ]:
        if not path.is_file():
            missing.append(f"  {label} → expected at {path}")
    if missing:
        sys.exit(
            "Required sibling skills not found:\n" + "\n".join(missing) +
            "\nInstall both atomic skills before running this wrapper."
        )


# ============================================================================
# Spec loading + validation
# ============================================================================

def load_spec(path: Path) -> dict[str, Any]:
    suffix = path.suffix.lower()
    text = path.read_text()
    if suffix in (".yaml", ".yml"):
        try:
            import yaml  # type: ignore
        except ImportError:
            sys.exit("Spec is YAML but PyYAML missing. uv pip install pyyaml")
        return yaml.safe_load(text)
    if suffix == ".json":
        return json.loads(text)
    sys.exit(f"Unsupported spec extension: {suffix}")


REQUIRED_TOP_KEYS = {
    "project_name", "project_prefix", "epic_key", "cloud_id", "project_key",
    "assignee_account_id", "team_uuid", "ai_category", "label",
    "repo_url", "confluence_space_id", "confluence_parent_id",
    "hub_page_title", "design_doc", "slices",
}

REQUIRED_DESIGN_DOC_KEYS = {"path", "title"}


def validate_spec(spec: dict[str, Any], spec_path: Path) -> list[str]:
    errors: list[str] = []
    missing = REQUIRED_TOP_KEYS - spec.keys()
    if missing:
        errors.append(f"Top-level missing keys: {sorted(missing)}")

    # design_doc nested
    dd = spec.get("design_doc", {})
    if not isinstance(dd, dict):
        errors.append("`design_doc` must be a dict with `path` and `title`")
    else:
        dd_missing = REQUIRED_DESIGN_DOC_KEYS - dd.keys()
        if dd_missing:
            errors.append(f"design_doc missing keys: {sorted(dd_missing)}")
        else:
            # Resolve path relative to the spec file's directory
            full_path = (spec_path.parent / dd["path"]).resolve()
            if not full_path.is_file():
                errors.append(f"design_doc.path not found: {full_path}")

    # extra_children optional
    extras = spec.get("extra_children", [])
    if extras and not isinstance(extras, list):
        errors.append("`extra_children` must be a list of {path, title} dicts")
    else:
        for i, e in enumerate(extras):
            if not isinstance(e, dict) or "path" not in e or "title" not in e:
                errors.append(f"extra_children[{i}] must have `path` and `title`")
                continue
            full_path = (spec_path.parent / e["path"]).resolve()
            if not full_path.is_file():
                errors.append(f"extra_children[{i}].path not found: {full_path}")

    # Slices basic shape (delegates fuller validation to /jira-create-vertical-slices)
    slices = spec.get("slices", [])
    if not isinstance(slices, list) or not slices:
        errors.append("`slices` must be a non-empty list")

    return errors


# ============================================================================
# Atlassian REST + auth
# ============================================================================

def get_basic_auth() -> str:
    auth = os.environ.get("ATLASSIAN_BASIC_AUTH")
    if not auth:
        sys.exit("ATLASSIAN_BASIC_AUTH not set. Source ~/.daily-agents.env.")
    return auth


def conf_get(path: str) -> dict | None:
    """GET on Confluence v2. Returns JSON body or exits on error."""
    auth = get_basic_auth()
    req = Request(f"{CONF_BASE}{path}", headers={
        "Authorization": f"Basic {auth}",
        "Accept": "application/json",
    })
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as r:
            if r.getcode() != 200:
                sys.exit(f"GET {path} returned {r.getcode()}")
            return json.loads(r.read())
    except HTTPError as e:
        sys.exit(f"GET {path} HTTPError {e.code}: {e.read().decode()}")
    except URLError as e:
        sys.exit(f"GET {path} URLError: {e}")


def conf_post_page(space_id: str, parent_id: str, title: str, adf: dict) -> str:
    """POST a new page via Confluence v2. Returns page ID.
    Falls back to instructing manual MCP create on 404 (scoped token)."""
    auth = get_basic_auth()
    payload = {
        "spaceId": space_id,
        "status": "current",
        "title": title,
        "parentId": parent_id,
        "body": {
            "representation": "atlas_doc_format",
            "value": json.dumps(adf),
        },
    }
    req = Request(
        f"{CONF_BASE}/api/v2/pages",
        method="POST",
        headers={
            "Authorization": f"Basic {auth}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
        data=json.dumps(payload).encode("utf-8"),
    )
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as r:
            body = json.loads(r.read())
            if r.getcode() == 200 and body.get("id"):
                return body["id"]
            sys.exit(f"POST /api/v2/pages returned {r.getcode()}: {body}")
    except HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        if e.code == 404:
            sys.exit(
                "POST /api/v2/pages returned 404 — token lacks page-create scope.\n"
                "Workaround:\n"
                "  1. Manually create the hub page via mcp__atlassian__createConfluencePage\n"
                "     (any placeholder body) under parent " + parent_id + "\n"
                "  2. Re-run this script with --hub-page-id <new id> to update\n"
                "     and continue with the slice creation step.\n"
                f"Response: {body_text}"
            )
        sys.exit(f"POST /api/v2/pages HTTPError {e.code}: {body_text}")
    except URLError as e:
        sys.exit(f"POST /api/v2/pages URLError: {e}")


def conf_put_page(page_id: str, title: str, adf: dict, current_version: int) -> None:
    auth = get_basic_auth()
    payload = {
        "id": page_id,
        "status": "current",
        "title": title,
        "body": {"representation": "atlas_doc_format", "value": json.dumps(adf)},
        "version": {"number": current_version + 1, "message": "Updated by scaffold-engineering-project"},
    }
    req = Request(
        f"{CONF_BASE}/api/v2/pages/{page_id}",
        method="PUT",
        headers={
            "Authorization": f"Basic {auth}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
        data=json.dumps(payload).encode("utf-8"),
    )
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as r:
            if r.getcode() != 200:
                sys.exit(f"PUT page {page_id} returned {r.getcode()}")
    except HTTPError as e:
        sys.exit(f"PUT page {page_id} HTTPError {e.code}: {e.read().decode()}")


# ============================================================================
# Hub-page ADF builder
# ============================================================================
# Mirrors the trf-benchmark-dashboard hub shape: info panel, status lozenges,
# links table, architecture summary, children list, out-of-scope panel, footer.

def _t(text: str, marks: list | None = None) -> dict:
    n: dict = {"type": "text", "text": text}
    if marks: n["marks"] = marks
    return n
def _strong(t): return _t(t, marks=[{"type": "strong"}])
def _em(t): return _t(t, marks=[{"type": "em"}])
def _code(t): return _t(t, marks=[{"type": "code"}])
def _link(t, href): return _t(t, marks=[{"type": "link", "attrs": {"href": href}}])
def _para(*content): return {"type": "paragraph", "content": list(content)}
def _heading(level, *content): return {"type": "heading", "attrs": {"level": level}, "content": list(content)}
def _panel(ptype, *content): return {"type": "panel", "attrs": {"panelType": ptype}, "content": list(content)}
def _status(text_, color="neutral", lid="status"):
    return {"type": "status", "attrs": {"text": text_, "color": color, "localId": lid, "style": ""}}
def _bullet_list(*items):
    return {"type": "bulletList", "content": [
        {"type": "listItem", "content": [_para(*item) if isinstance(item, list) else _para(item)]}
        for item in items
    ]}
def _th(*content):
    return {"type": "tableHeader", "attrs": {}, "content": [_para(*content) if content else _para()]}
def _td(*content):
    return {"type": "tableCell", "attrs": {}, "content": [_para(*content) if content else _para()]}
def _tr(*cells):
    return {"type": "tableRow", "content": list(cells)}
def _table(*rows):
    return {"type": "table", "attrs": {"layout": "default", "isNumberColumnEnabled": False}, "content": list(rows)}
def _rule():
    return {"type": "rule"}


def build_hub_adf(spec: dict, design_url: str, design_title: str,
                  extra_pages: list[tuple[str, str]]) -> dict:
    """Build the hub page ADF.

    extra_pages: list of (title, url) tuples for any extra Confluence children.
    """
    epic_key = spec["epic_key"]
    repo = spec["repo_url"]
    live = spec.get("live_url")
    project_name = spec["project_name"]
    project_owner = spec.get("project_owner", "")
    audience = spec.get("audience", "")
    architecture_summary = spec.get("architecture_summary",
        "Design pending; see the System Design page for details.")
    out_of_scope = spec.get("out_of_scope", [])

    content: list[dict] = []

    # 1. Info panel: goal + audience + status
    info_paras: list[dict] = []
    if spec.get("project_goal"):
        info_paras.append(_para(_strong("Goal: "), _t(spec["project_goal"])))
    if audience:
        info_paras.append(_para(_strong("Audience: "), _t(audience)))
    if project_owner:
        info_paras.append(_para(_strong("Owner: "), _t(project_owner)))
    if not info_paras:
        info_paras.append(_para(_t(f"{project_name} — project hub.")))
    content.append(_panel("info", *info_paras))

    # 2. Status lozenges row
    phases = spec.get("phases", [
        {"label": "DESIGNED", "color": "yellow"},
        {"label": "BUILD PENDING", "color": "yellow"},
    ])
    lozenge_nodes: list[dict] = [_strong("Phase status:  ")]
    for i, ph in enumerate(phases):
        if i > 0:
            lozenge_nodes.append(_t("  "))
        lozenge_nodes.append(_status(ph["label"], color=ph.get("color", "neutral"),
                                     lid=f"phase-{i}"))
    content.append(_para(*lozenge_nodes))

    # 3. Active links table
    content.append(_heading(2, _t("Active links")))
    rows = [_tr(_th(_strong("Resource")), _th(_strong("Link")))]
    rows.append(_tr(_td(_t(f"Jira Epic ({epic_key})")),
                    _td(_link(epic_key, f"https://sambatv.atlassian.net/browse/{epic_key}"))))
    rows.append(_tr(_td(_t("System Design")), _td(_link(design_title, design_url))))
    for title, url in extra_pages:
        rows.append(_tr(_td(_t(title)), _td(_link(title, url))))
    rows.append(_tr(_td(_t("Repo")),
                    _td(_link(repo.replace("https://", ""), repo))))
    if live:
        rows.append(_tr(_td(_t("Live")), _td(_link(live.replace("https://", ""), live))))
    content.append(_table(*rows))

    # 4. Architecture summary
    content.append(_heading(2, _t("Architecture")))
    content.append(_para(_t(architecture_summary)))
    content.append(_para(_em("Full architecture, BQ schema, validation gate: see the "),
                         _link("System Design page", design_url), _em(".")))

    # 5. Children list
    if extra_pages or design_url:
        content.append(_heading(2, _t("Detailed pages")))
        items: list[Any] = []
        items.append([_link(design_title, design_url),
                      _t(" — full system design (architecture, schema, validation)")])
        for title, url in extra_pages:
            items.append([_link(title, url)])
        content.append(_bullet_list(*items))

    # 6. Out-of-scope panel
    if out_of_scope:
        content.append(_heading(2, _t("What's NOT in scope")))
        content.append(_panel("note",
            _bullet_list(*[
                [_t(item)] if isinstance(item, str) else item
                for item in out_of_scope
            ])
        ))

    # 7. Footer
    content.append(_rule())
    footer_nodes = [_em(f"Maintained by {project_owner or 'project owner'}  ·  Source-of-truth: "),
                    _code("system-design.md"), _em(" in the repo.")]
    content.append(_para(*footer_nodes))

    return {"version": 1, "type": "doc", "content": content}


# ============================================================================
# Subprocess helpers — call atomic skills
# ============================================================================

def run_publish_markdown(*, markdown_path: Path, parent_id: str, title: str,
                         header_config_path: Path | None = None,
                         page_id: str | None = None,
                         validate_only: bool = False) -> dict:
    """Call /confluence-publish-markdown. Returns parsed output for the URL/ID."""
    cmd = [
        sys.executable, str(PUBLISH_MD_SCRIPT),
        "--markdown", str(markdown_path),
        "--title", title,
    ]
    if page_id:
        cmd += ["--page-id", page_id]
    else:
        cmd += ["--parent-id", parent_id]
    if header_config_path:
        cmd += ["--header-config", str(header_config_path)]
    if validate_only:
        cmd += ["--validate-only"]

    print(f"  $ {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(
            f"Atomic skill /confluence-publish-markdown failed:\n"
            f"  stdout: {proc.stdout}\n"
            f"  stderr: {proc.stderr}"
        )
    print(proc.stdout)

    # Parse the published URL/ID from output
    if validate_only:
        return {}
    page_url = None
    page_id_out = None
    for line in proc.stdout.splitlines():
        line = line.strip()
        if line.startswith("Published:"):
            page_url = line.split("Published:", 1)[1].strip()
        elif line.startswith("Page ID:"):
            page_id_out = line.split("Page ID:", 1)[1].strip()
    if not page_url or not page_id_out:
        sys.exit("Failed to parse Confluence URL/ID from publish output")
    return {"url": page_url, "id": page_id_out}


def run_create_slices(spec_path: Path, validate_only: bool = False) -> None:
    cmd = [sys.executable, str(CREATE_SLICES_SCRIPT), "--spec", str(spec_path)]
    if validate_only:
        cmd += ["--validate-only"]
    print(f"  $ {' '.join(cmd)}")
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(
            f"Atomic skill /jira-create-vertical-slices failed:\n"
            f"  stdout: {proc.stdout}\n"
            f"  stderr: {proc.stderr}"
        )
    print(proc.stdout)


# ============================================================================
# Header config helpers
# ============================================================================

def write_header_config(spec: dict, jira_epic: str, confluence_hub: str | None,
                        out_path: Path) -> None:
    """Materialize a header config YAML for /confluence-publish-markdown."""
    cfg = {
        "summary": spec.get("project_status_line", ""),
        "repo_url": spec["repo_url"],
        "jira_epic": jira_epic,
    }
    if spec.get("live_url"):
        cfg["live_url"] = spec["live_url"]
    if confluence_hub:
        cfg["confluence_hub"] = confluence_hub

    import yaml  # already imported successfully if we got this far
    out_path.write_text(yaml.safe_dump(cfg, sort_keys=False))


def materialize_slice_spec(spec: dict, hub_url: str, design_url: str,
                           out_path: Path) -> None:
    """Build the per-/jira-create-vertical-slices/ spec from the wrapper spec.

    Inserts the just-created Confluence URLs into the slice spec block."""
    slice_spec = {
        "epic_key": spec["epic_key"],
        "cloud_id": spec["cloud_id"],
        "project_key": spec["project_key"],
        "assignee_account_id": spec["assignee_account_id"],
        "team_uuid": spec["team_uuid"],
        "ai_category": spec["ai_category"],
        "label": spec["label"],
        "confluence_hub_url": hub_url,
        "confluence_design_url": design_url,
        "repo_url": spec["repo_url"],
        "slices": spec["slices"],
    }
    import yaml
    out_path.write_text(yaml.safe_dump(slice_spec, sort_keys=False))


# ============================================================================
# Main pipeline
# ============================================================================

def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--hub-page-id",
                        help="If hub page already exists (e.g. recovery from partial run), "
                             "update it instead of creating new.")
    args = parser.parse_args()

    if not args.spec.is_file():
        sys.exit(f"Spec not found: {args.spec}")

    assert_sibling_skills_present()

    spec = load_spec(args.spec)
    errors = validate_spec(spec, args.spec)
    if errors:
        print("Spec validation failed:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Pre-flight: {spec['project_name']}")
    print(f"  Epic: {spec['epic_key']}")
    print(f"  Confluence parent: {spec['confluence_parent_id']}")
    print(f"  Design doc: {spec['design_doc']['path']}")
    print(f"  Extra children: {len(spec.get('extra_children', []))}")
    print(f"  Slices: {len(spec['slices'])}")

    # Validate Epic + parent page
    print(f"\n  GET Confluence parent {spec['confluence_parent_id']} ...", end=" ", flush=True)
    body = conf_get(f"/api/v2/pages/{spec['confluence_parent_id']}")
    print(f"OK — {body.get('title', '?')!r}")
    print(f"  GET Jira epic {spec['epic_key']} ...", end=" ", flush=True)
    auth = get_basic_auth()
    req = Request(f"https://sambatv.atlassian.net/rest/api/3/issue/{spec['epic_key']}",
                  headers={"Authorization": f"Basic {auth}", "Accept": "application/json"})
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as r:
            body = json.loads(r.read())
            print(f"OK — {body['fields']['summary']!r}")
    except HTTPError as e:
        sys.exit(f"GET Jira epic failed: {e.code}")

    if args.validate_only:
        # Validate atomic skills run cleanly
        print("\nValidating atomic skill specs ...")
        spec_dir = args.spec.parent
        # Validate the design markdown via /confluence-publish-markdown
        design_md = (spec_dir / spec["design_doc"]["path"]).resolve()
        run_publish_markdown(
            markdown_path=design_md,
            parent_id=spec["confluence_parent_id"],
            title=spec["design_doc"]["title"],
            validate_only=True,
        )
        # Validate slices via /jira-create-vertical-slices
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as tf:
            slice_spec_path = Path(tf.name)
        materialize_slice_spec(spec, "<hub-pending>", "<design-pending>", slice_spec_path)
        run_create_slices(slice_spec_path, validate_only=True)
        slice_spec_path.unlink()
        print("\n--validate-only: pre-flight OK across all atomic skills.")
        return

    # ====== Phase 1: Publish design page ======
    print(f"\n{'='*60}\nPhase 1: Publish design page\n{'='*60}")
    spec_dir = args.spec.parent
    design_md = (spec_dir / spec["design_doc"]["path"]).resolve()

    # Header config — temp file with project metadata
    header_path = Path(tempfile.mkdtemp()) / "header.yaml"
    write_header_config(spec, spec["epic_key"], confluence_hub=None, out_path=header_path)

    design_result = run_publish_markdown(
        markdown_path=design_md,
        parent_id=spec["confluence_parent_id"],
        title=spec["design_doc"]["title"],
        header_config_path=header_path,
    )
    design_url = design_result["url"]
    design_id = design_result["id"]
    print(f"\n  Design page: {design_url}")

    # ====== Phase 2: Publish extra child pages ======
    extra_pages: list[tuple[str, str]] = []
    extras = spec.get("extra_children", [])
    if extras:
        print(f"\n{'='*60}\nPhase 2: Publish {len(extras)} extra child page(s)\n{'='*60}")
        for e in extras:
            full_path = (spec_dir / e["path"]).resolve()
            r = run_publish_markdown(
                markdown_path=full_path,
                parent_id=spec["confluence_parent_id"],
                title=e["title"],
                header_config_path=header_path,
            )
            extra_pages.append((e["title"], r["url"]))
            print(f"  Extra page: {r['url']}")

    # ====== Phase 3: Build + create the hub page ======
    print(f"\n{'='*60}\nPhase 3: Build hub page\n{'='*60}")
    hub_adf = build_hub_adf(spec, design_url, spec["design_doc"]["title"], extra_pages)
    if args.hub_page_id:
        hub_meta = conf_get(f"/api/v2/pages/{args.hub_page_id}")
        conf_put_page(args.hub_page_id, spec["hub_page_title"], hub_adf,
                      hub_meta["version"]["number"])
        hub_id = args.hub_page_id
        print(f"  Updated existing hub page: {args.hub_page_id}")
    else:
        hub_id = conf_post_page(
            spec["confluence_space_id"],
            spec["confluence_parent_id"],
            spec["hub_page_title"],
            hub_adf,
        )
        print(f"  Created hub page: {hub_id}")

    hub_url = f"{CONF_BASE}/spaces/ATF/pages/{hub_id}"
    print(f"  Hub URL: {hub_url}")

    # ====== Phase 4: Create slice tickets ======
    print(f"\n{'='*60}\nPhase 4: Create slice tickets via /jira-create-vertical-slices\n{'='*60}")
    slice_spec_path = Path(tempfile.mkdtemp()) / "slice-spec.yaml"
    materialize_slice_spec(spec, hub_url, design_url, slice_spec_path)
    run_create_slices(slice_spec_path)

    # ====== Final summary ======
    print(f"\n{'='*60}\nScaffold complete: {spec['project_name']}\n{'='*60}")
    print(f"\nConfluence:")
    print(f"  Hub:    {hub_url}")
    print(f"  Design: {design_url}")
    for title, url in extra_pages:
        print(f"  {title}: {url}")
    print(f"\nJira:")
    print(f"  Epic:   https://sambatv.atlassian.net/browse/{spec['epic_key']}")
    print(f"  Slices: search via JQL: labels = \"{spec['label']}\" ORDER BY key ASC")
    print(f"\nNext step: spot-check the hub page renders correctly, then update the Epic")
    print(f"description manually to link back to the hub if desired.")


if __name__ == "__main__":
    main()
