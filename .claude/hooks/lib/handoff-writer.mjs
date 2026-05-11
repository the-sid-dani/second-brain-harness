// handoff-writer.mjs — single entry point for handoff file writes.
//
// Why this matters: structural enforcement of the `project_root:` invariant.
// The handoff-at-workspace + state-at-project split that `/resume-handoff`
// depends on lives or dies on every handoff carrying its origin in YAML
// frontmatter. Two writers exist today (pre-compact.mjs + /create-handoff),
// a third is likely future-state. Without a shared helper, the invariant
// is a written rule that drifts the moment a new writer ships. Every
// handoff goes through one code path. Don't bypass — extend.
//
// Spec: ccv4-port-plan.md Phase 4 / VAL-018. Locked 2026-05-11.
// VAL-020/VAL-021 update 2026-05-11: accept optional `extra` field so callers
// (pre-compact.mjs) can pass trigger/session metadata without emitting their
// own competing frontmatter block. Single frontmatter == one parseable YAML
// block, which is what /resume-handoff actually consumes.

import { mkdirSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";
import {
  resolveRepoRoot,
  resolveStateRoot,
  resolveHandoffRoot,
} from "./resolve-project-root.mjs";

export function writeHandoff(opts) {
  const { kind, sessionName, body, ts, cwd, extra } = opts;

  const repoRoot = resolveRepoRoot(cwd);
  const stateRoot = resolveStateRoot(cwd);
  const handoffRoot = resolveHandoffRoot(cwd);

  // Single-project mode: repoRoot === stateRoot. relative() returns ''; use '.'.
  let projectRootRelative = relative(repoRoot, stateRoot);
  if (!projectRootRelative) projectRootRelative = ".";

  // Merge optional `extra` fields between date/type and project_root/repo_root.
  // Skip falsy values; serialize as YAML scalars (strings without special chars
  // work cleanly; complex values are caller's responsibility).
  const extraLines = [];
  if (extra && typeof extra === "object") {
    for (const [key, value] of Object.entries(extra)) {
      if (!value) continue;
      extraLines.push(`${key}: ${value}`);
    }
  }

  const frontmatter = [
    "---",
    `date: ${ts}`,
    `type: ${kind}`,
    ...extraLines,
    `project_root: ${projectRootRelative}`,
    `repo_root: ${repoRoot}`,
    "---",
    "",
  ].join("\n");

  const handoffDir = join(handoffRoot, "handoffs", sessionName);
  mkdirSync(handoffDir, { recursive: true });

  // Filename gets colon-stripped + ms-trimmed ISO (filesystem-safe).
  // Frontmatter `date:` keeps the canonical ISO with colons (parseable).
  const tsSafe = ts.replace(/:/g, "-").replace(/\.\d+Z$/, "");
  const filename =
    kind === "auto-handoff" ? `auto-handoff-${tsSafe}.md` : `${kind}-${tsSafe}.md`;
  const path = join(handoffDir, filename);

  writeFileSync(path, frontmatter + body);

  return { path, projectRoot: projectRootRelative, handoffRoot };
}
