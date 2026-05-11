#!/usr/bin/env python3
"""Bulk-create Jira Story tickets under an existing Epic from a spec file.

Usage:
    python create_slices.py --spec <path>                # create everything
    python create_slices.py --spec <path> --validate-only  # pre-flight only

Spec file: YAML (.yaml/.yml) or JSON (.json). Schema in ../references/spec-schema.md.

Auth: ATLASSIAN_BASIC_AUTH env var (auto-loaded via ~/.zshrc → ~/.second-brain-harness.env).

Models the trf-benchmark-dashboard pattern (ATF-450) — header info panel,
ADF taskList for AC, parent linkage, custom fields, and Blocks-link dependency chain.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any
from urllib.parse import quote

# urllib stdlib (avoids requests dep)
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

JIRA_BASE = os.environ.get("ATLASSIAN_BASE_URL", "https://your-org.atlassian.net")
TIMEOUT_SEC = 30
RETRY_DELAY_SEC = 2


# ---------- spec parsing -----------------------------------------------------

def load_spec(path: Path) -> dict[str, Any]:
    suffix = path.suffix.lower()
    text = path.read_text()
    if suffix in (".yaml", ".yml"):
        try:
            import yaml  # type: ignore
        except ImportError:
            sys.exit(
                "Spec file is YAML but PyYAML is not installed. Either:\n"
                "  - convert spec to JSON, or\n"
                "  - run: pip install pyyaml"
            )
        return yaml.safe_load(text)
    if suffix == ".json":
        return json.loads(text)
    sys.exit(f"Unsupported spec extension: {suffix} (expected .yaml/.yml/.json)")


REQUIRED_TOP_KEYS = {
    "epic_key", "cloud_id", "project_key", "assignee_account_id",
    "team_uuid", "ai_category", "label",
    "confluence_hub_url", "confluence_design_url", "repo_url", "slices"
}

REQUIRED_SLICE_KEYS = {"letter", "summary", "sd_sections", "what_to_build", "ac_items"}


def validate_spec(spec: dict[str, Any]) -> list[str]:
    """Return list of error strings; empty list = valid."""
    errors: list[str] = []
    missing_top = REQUIRED_TOP_KEYS - spec.keys()
    if missing_top:
        errors.append(f"Top-level missing keys: {sorted(missing_top)}")

    slices = spec.get("slices", [])
    if not isinstance(slices, list) or not slices:
        errors.append("`slices` must be a non-empty list")
        return errors

    letters_seen: set[str] = set()
    for i, s in enumerate(slices):
        prefix = f"slices[{i}]"
        missing = REQUIRED_SLICE_KEYS - s.keys()
        if missing:
            errors.append(f"{prefix} missing keys: {sorted(missing)}")
            continue
        letter = s["letter"]
        if not isinstance(letter, str) or len(letter) != 1:
            errors.append(f"{prefix}.letter must be a single character (got {letter!r})")
        if letter in letters_seen:
            errors.append(f"{prefix}.letter={letter!r} is duplicated")
        letters_seen.add(letter)
        if not isinstance(s["ac_items"], list) or not s["ac_items"]:
            errors.append(f"{prefix}.ac_items must be a non-empty list")
        if not isinstance(s["what_to_build"], list) or not s["what_to_build"]:
            errors.append(f"{prefix}.what_to_build must be a non-empty list")

    # blocked_by_letter must reference a letter that exists
    for i, s in enumerate(slices):
        bl = s.get("blocked_by_letter")
        if bl and bl not in letters_seen:
            errors.append(
                f"slices[{i}].blocked_by_letter={bl!r} not found among slice letters {sorted(letters_seen)}"
            )

    return errors


# ---------- auth + HTTP ------------------------------------------------------

def get_basic_auth() -> str:
    auth = os.environ.get("ATLASSIAN_BASIC_AUTH")
    if not auth:
        sys.exit(
            "ATLASSIAN_BASIC_AUTH env var not set.\n"
            "Source ~/.second-brain-harness.env or run from a fresh shell."
        )
    return auth


def jira_request(
    method: str, path: str, body: dict | None = None, *,
    expect_status: tuple[int, ...] = (200, 201, 204)
) -> tuple[int, dict | None]:
    """Single Jira REST call. Returns (status, parsed_json_or_None)."""
    auth = get_basic_auth()
    url = f"{JIRA_BASE}{path}"
    headers = {
        "Authorization": f"Basic {auth}",
        "Accept": "application/json",
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = Request(url, method=method, headers=headers, data=data)
    try:
        with urlopen(req, timeout=TIMEOUT_SEC) as resp:
            status = resp.getcode()
            raw = resp.read()
            parsed = json.loads(raw) if raw else None
            if status not in expect_status:
                sys.exit(f"{method} {path} returned {status} (expected {expect_status}): {parsed}")
            return status, parsed
    except HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        sys.exit(f"{method} {path} HTTPError {e.code}: {body_text}")
    except URLError as e:
        sys.exit(f"{method} {path} URLError: {e}")


# ---------- ADF builders -----------------------------------------------------

def text(t: str, marks: list | None = None) -> dict:
    n: dict = {"type": "text", "text": t}
    if marks:
        n["marks"] = marks
    return n


def strong(t: str) -> dict: return text(t, marks=[{"type": "strong"}])
def em(t: str) -> dict:     return text(t, marks=[{"type": "em"}])
def code(t: str) -> dict:   return text(t, marks=[{"type": "code"}])
def link(t: str, href: str) -> dict:
    return text(t, marks=[{"type": "link", "attrs": {"href": href}}])


def coerce(node: Any) -> dict:
    """Allow string shorthand (treated as plain text) or a passthrough ADF dict."""
    if isinstance(node, str):
        return parse_inline_markdown(node)
    return node


# Lightweight inline-markdown parser for AC items + what_to_build paragraphs.
# Handles: `code`, **strong**, _em_, [text](href). Returns either a single
# text node or a list of text nodes wrapped in a paragraph-content array.
import re

_INLINE_TOKEN_RE = re.compile(
    r"(`[^`]+`|\*\*[^*]+\*\*|_[^_]+_|\[[^\]]+\]\([^)]+\))"
)


def parse_inline_markdown(s: str) -> Any:
    """Parse a single string into ADF text nodes preserving inline markup.

    Returns either a single text node (if no markup) or a list of nodes.
    Caller wraps in paragraph as needed.
    """
    parts = _INLINE_TOKEN_RE.split(s)
    nodes: list[dict] = []
    for part in parts:
        if not part:
            continue
        if part.startswith("`") and part.endswith("`"):
            nodes.append(code(part[1:-1]))
        elif part.startswith("**") and part.endswith("**"):
            nodes.append(strong(part[2:-2]))
        elif part.startswith("_") and part.endswith("_"):
            nodes.append(em(part[1:-1]))
        elif part.startswith("[") and "](" in part and part.endswith(")"):
            mtxt, _, rest = part[1:].partition("](")
            href = rest[:-1]
            nodes.append(link(mtxt, href))
        else:
            nodes.append(text(part))
    if len(nodes) == 1:
        return nodes[0]
    return nodes


def p(*content: Any) -> dict:
    nodes: list[dict] = []
    for c in content:
        coerced = coerce(c)
        if isinstance(coerced, list):
            nodes.extend(coerced)
        else:
            nodes.append(coerced)
    return {"type": "paragraph", "content": nodes}


def heading(level: int, *content: Any) -> dict:
    nodes: list[dict] = []
    for c in content:
        coerced = coerce(c)
        if isinstance(coerced, list):
            nodes.extend(coerced)
        else:
            nodes.append(coerced)
    return {"type": "heading", "attrs": {"level": level}, "content": nodes}


def panel(panel_type: str, *content: dict) -> dict:
    return {"type": "panel", "attrs": {"panelType": panel_type}, "content": list(content)}


def bullet_list(*items: Any) -> dict:
    list_items: list[dict] = []
    for item in items:
        if isinstance(item, dict) and item.get("type") in ("paragraph", "bulletList", "orderedList"):
            list_items.append({"type": "listItem", "content": [item]})
        else:
            list_items.append({"type": "listItem", "content": [p(item)]})
    return {"type": "bulletList", "content": list_items}


def task_list(items: list[Any], local_id_prefix: str = "ac") -> dict:
    task_items: list[dict] = []
    for i, item in enumerate(items):
        coerced = coerce(item)
        content = coerced if isinstance(coerced, list) else [coerced]
        task_items.append({
            "type": "taskItem",
            "attrs": {"localId": f"{local_id_prefix}-task-{i+1}", "state": "TODO"},
            "content": content,
        })
    return {
        "type": "taskList",
        "attrs": {"localId": f"{local_id_prefix}-tasklist"},
        "content": task_items,
    }


# ---------- description builder ---------------------------------------------

def build_slice_adf(spec: dict, slice_spec: dict, letter_to_key: dict[str, str]) -> dict:
    """Build the full ADF body for one slice's description.

    letter_to_key: mapping populated as slices are created so we can
    interpolate the actual issue keys into the Blocked-by section.
    """
    epic_key = spec["epic_key"]
    hub = spec["confluence_hub_url"]
    design = spec["confluence_design_url"]
    repo = spec["repo_url"]
    sd_sections = slice_spec["sd_sections"]
    sd_summary = ", ".join(f"§{s}" for s in sd_sections)

    content: list[dict] = []

    # 1. Top info panel
    content.append(panel(
        "info",
        p(strong("Parent Epic: "), link(epic_key, f"{JIRA_BASE}/browse/{epic_key}")),
        p(strong("Confluence hub: "), link("Project hub", hub)),
        p(strong("System Design: "), link(f"{sd_summary} (sections this slice implements)", design)),
        p(strong("Repo: "), link(repo.replace("https://", ""), repo)),
    ))

    # 2. Parent heading
    content.append(heading(2, "Parent"))
    content.append(p(link(epic_key, f"{JIRA_BASE}/browse/{epic_key}")))

    # 3. What to build
    content.append(heading(2, "What to build"))
    for paragraph_text in slice_spec["what_to_build"]:
        content.append(p(paragraph_text))

    # 4. Reference docs
    content.append(heading(3, "Reference docs"))
    refs = [
        [link("Confluence: System Design", design), text(f" — sections {sd_summary}")],
    ]
    extra_refs = slice_spec.get("extra_refs", [])
    for ref_text in extra_refs:
        # Each extra_ref is a markdown-formatted string
        refs.append([parse_inline_markdown(ref_text)] if isinstance(parse_inline_markdown(ref_text), dict) else parse_inline_markdown(ref_text))
    content.append(bullet_list(*refs))

    # 5. AC as taskList
    content.append(heading(2, "Acceptance criteria"))
    content.append(task_list(slice_spec["ac_items"], local_id_prefix=f"slice-{letter_to_key.get(slice_spec['letter'], 'x').lower().replace('-', '')}-ac"))

    # 6. Slice type
    slice_type = slice_spec.get("slice_type", "AFK")
    content.append(heading(2, "Slice type"))
    if slice_type == "AFK":
        content.append(p("AFK (away-from-keyboard, no human input needed mid-task). Once approved, an agent or the assignee can implement it."))
    else:
        content.append(p(strong("HITL"), text(" — human-in-the-loop step required mid-task.")))

    # 7. Blocked by
    content.append(heading(2, "Blocked by"))
    bl = slice_spec.get("blocked_by_letter")
    bl_note = slice_spec.get("blocked_by_note")
    if bl:
        blocker_key = letter_to_key.get(bl)
        if blocker_key:
            line = [link(blocker_key, f"{JIRA_BASE}/browse/{blocker_key}")]
            if bl_note:
                line.append(text(f" — Slice {bl} — {bl_note}"))
            else:
                line.append(text(f" — Slice {bl}"))
            content.append(p(*line))
        else:
            # Slice referenced before created — should not happen if order respected
            content.append(p(text(f"Slice {bl} (key not yet known — pre-flight check should have caught this)")))
    elif bl_note:
        content.append(p(bl_note))
    else:
        content.append(p("None."))

    # 8. Notes
    notes = slice_spec.get("notes", [])
    if notes:
        content.append(heading(2, "Notes"))
        for n in notes:
            # Italicize whole note by wrapping in em
            content.append({"type": "paragraph", "content": [{"type": "text", "text": n, "marks": [{"type": "em"}]}]})

    return {"version": 1, "type": "doc", "content": content}


# ---------- main pipeline ----------------------------------------------------

def preflight(spec: dict) -> None:
    errors = validate_spec(spec)
    if errors:
        print("Spec validation failed:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

    # Confirm Epic exists
    epic_key = spec["epic_key"]
    print(f"Pre-flight: GET /rest/api/3/issue/{epic_key} ...", end=" ", flush=True)
    status, body = jira_request("GET", f"/rest/api/3/issue/{quote(epic_key)}")
    epic_summary = body.get("fields", {}).get("summary", "?") if body else "?"
    print(f"OK — {epic_key}: {epic_summary!r}")

    # Confirm auth perms by attempting a no-op edit (just metadata fetch — already tested above)
    print(f"Pre-flight: {len(spec['slices'])} slices to create.")
    for s in spec["slices"]:
        bl = s.get("blocked_by_letter")
        bl_str = f" (blocked by {bl})" if bl else ""
        print(f"  - Slice {s['letter']}: {s['summary']}{bl_str}")
    print("Pre-flight OK.")


def create_slice(spec: dict, slice_spec: dict) -> str:
    """Create one Story; return its key. Description is a placeholder; PUT happens after."""
    payload = {
        "fields": {
            "project": {"key": spec["project_key"]},
            "issuetype": {"name": "Story"},
            "summary": slice_spec["summary"],
            "description": {
                "version": 1,
                "type": "doc",
                "content": [{"type": "paragraph", "content": [{"type": "text", "text": "_Initializing — full ADF arrives in next revision._", "marks": [{"type": "em"}]}]}],
            },
            "assignee": {"accountId": spec["assignee_account_id"]},
            "parent": {"key": spec["epic_key"]},
            "labels": [spec["label"]],
            "customfield_10001": spec["team_uuid"],
            "customfield_11335": {"value": spec["ai_category"]},
        },
    }
    status, body = jira_request("POST", "/rest/api/3/issue", body=payload, expect_status=(201,))
    if not body or "key" not in body:
        sys.exit(f"Slice {slice_spec['letter']} create returned no key: {body}")
    return body["key"]


def put_description(key: str, adf: dict) -> None:
    payload = {"fields": {"description": adf}}
    jira_request("PUT", f"/rest/api/3/issue/{quote(key)}", body=payload, expect_status=(204,))


def create_blocks_link(blocker_key: str, blocked_key: str) -> None:
    payload = {
        "type": {"name": "Blocks"},
        "inwardIssue": {"key": blocker_key},
        "outwardIssue": {"key": blocked_key},
    }
    jira_request("POST", "/rest/api/3/issueLink", body=payload, expect_status=(201,))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--spec", required=True, type=Path, help="Path to YAML or JSON spec file")
    parser.add_argument("--validate-only", action="store_true", help="Run pre-flight only, don't create anything")
    args = parser.parse_args()

    if not args.spec.is_file():
        sys.exit(f"Spec file not found: {args.spec}")

    spec = load_spec(args.spec)
    preflight(spec)

    if args.validate_only:
        print("\n--validate-only: stopping before create.")
        return

    # Phase 1: create all slices, collect keys
    letter_to_key: dict[str, str] = {}
    print("\nCreating slices ...")
    for s in spec["slices"]:
        print(f"  Slice {s['letter']}: creating ...", end=" ", flush=True)
        key = create_slice(spec, s)
        letter_to_key[s["letter"]] = key
        print(f"{key}")
        time.sleep(0.2)  # polite to Jira

    # Phase 2: PUT full ADF descriptions
    print("\nUpdating descriptions with full ADF ...")
    for s in spec["slices"]:
        key = letter_to_key[s["letter"]]
        adf = build_slice_adf(spec, s, letter_to_key)
        print(f"  {key} (Slice {s['letter']}): PUT description ...", end=" ", flush=True)
        put_description(key, adf)
        print("204")
        time.sleep(0.2)

    # Phase 3: wire Blocks links
    print("\nWiring Blocks links ...")
    link_count = 0
    for s in spec["slices"]:
        bl = s.get("blocked_by_letter")
        if not bl:
            continue
        blocker_key = letter_to_key[bl]
        blocked_key = letter_to_key[s["letter"]]
        print(f"  {blocker_key} → blocks → {blocked_key} ...", end=" ", flush=True)
        create_blocks_link(blocker_key, blocked_key)
        link_count += 1
        print("OK")
        time.sleep(0.2)

    # Summary
    print(f"\n{'─'*60}")
    print(f"Created {len(letter_to_key)} slices, wired {link_count} Blocks links.")
    print(f"\nKeys created (in order):")
    for letter, key in letter_to_key.items():
        print(f"  Slice {letter}: {key} — {JIRA_BASE}/browse/{key}")
    print(f"\nFind them all later with:")
    print(f"  JQL: labels = \"{spec['label']}\" AND \"Epic Link\" = {spec['epic_key']} ORDER BY key ASC")
    print(f"  Or:  labels = \"{spec['label']}\" ORDER BY key ASC")


if __name__ == "__main__":
    main()
