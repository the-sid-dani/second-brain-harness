// resolve-project-root.mjs — runtime project-shape resolver for CCv4 hooks.
// Three resolvers + module-level parse cache. No external deps.
// Spec: ccv4-port-plan.md Phase 4 / VAL-017. Locked 2026-05-11.

import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";

// Per-process cache: repo_root -> { root, projects, coding, resources } | null
const configCache = new Map();

function walkUpForGit(start) {
  let cur = resolve(start);
  while (true) {
    if (existsSync(join(cur, ".git"))) return cur;
    const parent = dirname(cur);
    if (parent === cur) return null;
    cur = parent;
  }
}

// Find the canonical repo CLAUDE.md (outermost).
// Strategy: if a .git ancestor has a CLAUDE.md, that's the repo root.
// Otherwise fall back to the nearest CLAUDE.md (single-project / non-git case).
function walkUpForCLAUDE(start) {
  const gitRoot = walkUpForGit(start);
  if (gitRoot && existsSync(join(gitRoot, "CLAUDE.md"))) return gitRoot;
  let cur = resolve(start);
  while (true) {
    if (existsSync(join(cur, "CLAUDE.md"))) return cur;
    const parent = dirname(cur);
    if (parent === cur) return null;
    cur = parent;
  }
}

function parseConfig(repoRoot) {
  if (configCache.has(repoRoot)) return configCache.get(repoRoot);
  let cfg = null;
  try {
    const md = readFileSync(join(repoRoot, "CLAUDE.md"), "utf8");
    // Slice the "## Configuration" section up to the next "## " heading.
    const startIdx = md.search(/^##\s+Configuration\b/m);
    if (startIdx !== -1) {
      const tail = md.slice(startIdx);
      const nextIdx = tail.slice(2).search(/^##\s+/m); // skip the leading "##"
      const section = nextIdx === -1 ? tail : tail.slice(0, nextIdx + 2);
      const tokens = {};
      const re = /^- `([\w.]+)` = `([^`]+)`/gm;
      let m;
      while ((m = re.exec(section)) !== null) {
        tokens[m[1].trim()] = m[2].trim();
      }
      cfg = {
        root: tokens["workspace.root"] || null,
        projects: tokens["workspace.projects"] || null,
        coding: tokens["workspace.coding"] || null,
        resources: tokens["workspace.resources"] || null,
      };
    }
  } catch (err) {
    process.stderr.write(`[resolve-project-root] CLAUDE.md parse failed at ${repoRoot}: ${err.message}\n`);
  }
  configCache.set(repoRoot, cfg);
  return cfg;
}

function isDir(p) {
  try {
    return statSync(p).isDirectory();
  } catch {
    return false;
  }
}

export function resolveRepoRoot(cwd) {
  const fromClaude = walkUpForCLAUDE(cwd);
  if (fromClaude) return fromClaude;
  const fromGit = walkUpForGit(cwd);
  if (fromGit) return fromGit;
  return resolve(cwd);
}

export function resolveStateRoot(cwd) {
  const repoRoot = walkUpForCLAUDE(cwd);
  if (!repoRoot) return resolve(cwd);
  const cfg = parseConfig(repoRoot);
  if (cfg && cfg.root && (cfg.projects || cfg.coding)) {
    // Walk up from cwd looking for the multi-project shape.
    let cur = resolve(cwd);
    while (cur.startsWith(repoRoot) && cur !== repoRoot) {
      const rel = cur.slice(repoRoot.length + 1).split(sep);
      // <root>/<projects>/<slug>
      if (cfg.projects && rel.length >= 3 && rel[0] === cfg.root && rel[1] === cfg.projects) {
        return join(repoRoot, rel[0], rel[1], rel[2]);
      }
      // <root>/<coding>/<scope>/<name>
      if (cfg.coding && rel.length >= 4 && rel[0] === cfg.root && rel[1] === cfg.coding) {
        return join(repoRoot, rel[0], rel[1], rel[2], rel[3]);
      }
      cur = dirname(cur);
    }
  }
  return repoRoot;
}

export function resolveHandoffRoot(cwd) {
  const repoRoot = walkUpForCLAUDE(cwd);
  if (!repoRoot) {
    return join(resolveStateRoot(cwd), "thoughts", "shared");
  }
  const cfg = parseConfig(repoRoot);
  if (cfg && cfg.root && cfg.resources && isDir(join(repoRoot, cfg.root))) {
    return join(repoRoot, cfg.root, cfg.resources);
  }
  return join(resolveStateRoot(cwd), "thoughts", "shared");
}
