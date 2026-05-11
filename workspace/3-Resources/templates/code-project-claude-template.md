---
status: active           # active | paused | done
created: YYYY-MM-DD
stack: [TypeScript, Node]
github: github.com/<user.github>/<repo-name>
deploy: <prod URL or "local-only">
---

# <repo-name>

<one-line description of what this repo does>

## Stack

- Language: <TS / Python / Rust / etc.>
- Runtime: <Node 20 / Python 3.12 / etc.>
- Key dependencies: <MCP SDK, FastAPI, etc.>

## Build / test / deploy

```bash
# install
<command>

# build
<command>

# test
<command>

# run locally
<command>

# deploy
<command>
```

## Key files

- `src/<entry>` — entry point
- `<other-key-file>` — <purpose>

## Architectural decisions

Decisions go in `memory.md` (append-only). Don't accumulate them here.

## Related project meta

If this code repo has strategic / planning / stakeholder work that lives as a separate <agent> project:
- Path: `<workspace.root>/<workspace.projects>/YYYY-MM-<repo>-meta/`

If no meta-project exists, leave this section blank.

---

*Inherits the root `CLAUDE.md` (workspace-wide instructions, identity, configuration) at the workspace root. This file adds code-specific overrides only. The `<user.github>` value above resolves to the GitHub username defined in root CLAUDE.md's Configuration section — it's substituted by `/new-project` when the repo is created.*
