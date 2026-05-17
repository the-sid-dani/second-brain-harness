# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.18] - 2026-05-17

### Changed

- **Renamed: `second-brain-harness` → `second-brain-os`.** Public repo now at `github.com/the-sid-dani/second-brain-os`; old URL auto-redirects via GitHub permanently. "OS" framing aligns better with the project's intent — a personal AI workspace that runs on your computer — than "harness" (which sounded like internal scaffolding). 18 source-of-truth files updated across `scripts/`, root docs, persona templates, and 10 SKILL.md / script refs in `bootstrap`, `upgrade-harness`, `scaffold-engineering-project`, `confluence-publish-markdown`, `jira-decompose-epic`, `desktop-organizer`. Extract output path moved: `/tmp/second-brain-harness-export` → `/tmp/second-brain-os-export`. `upgrade-harness` skill name retained — it refers to the local Ouros sandbox (`.claude/tools/ouros_harness.py`), not the repo. LICENSE copyright string regenerated to "second-brain-os contributors". Historical references in v0.1.0–v0.1.17 CHANGELOG entries, daily memory logs, design-project docs, and `continuum/autonomous/` reports left intact — they accurately describe shipped state at the time. Existing forks/clones keep working via GitHub's permanent redirect; recommended cleanup is `git remote set-url origin https://github.com/the-sid-dani/second-brain-os.git`.
- **`scripts/install.sh` final message rewritten** — explicitly points fork users at `claude` → `/bootstrap` → `/mcp` as the three-step post-install flow. Previous message was a generic "install complete" with no next-step pointer.
- **`scripts/lib/verify.sh` "Post-install manual steps"** reordered with `/bootstrap` as Step 1 (was buried below MCP OAuth hints).
- **`/bootstrap` Step 2 now probes the CCv4 toolchain** (`bloks`, `tldr`, `fastedit`). New `ccv4_install_state` field (`all-present` / `partial` / `none`). When all three are missing, Step 2 surfaces a strong pre-gate prompt recommending the user abort and run `install.sh` first; Section 8's "What needs your attention" surfaces this case FIRST.
- **`beru-workspace/3-Resources/templates/persona/TOOLS-template.md` rewritten** as a structural reference, not a status-asserting file. Stripped misleading ✅ marks; added prominent header explaining `/bootstrap` Step 6c regenerates the live TOOLS.md from real probes. Added CCv4 toolchain section (was missing).
- **`README-template.md` skill counts corrected** — "26 design skills" → 14, "66 pre-built workflows" → 44, brand presets "73" → 72. Design category table now enumerates the 14 kept skills instead of the dropped variants.
- **Brand-preset count corrected** — `bootstrap/SKILL.md` and README claimed 73; disk has 72.

### Removed

- **21 `gws-*` skills dropped from the bundle.** They shelled out to the `gws` CLI; fork users without it on PATH got silently-dead skills. Bundle is now MCP-first. Source dirs remain at `~/.agents/skills/gws-*` for users who install the CLI separately.
- **12 niche `design-*` skills dropped:** `audio-jingle`, `digital-eguide`, `email-marketing`, `hyperframes`, `image-poster`, `magazine-poster`, `mobile-app`, `mobile-onboarding`, `replit-deck`, `social-carousel`, `video-shortform`, `wireframe-sketch`. Kept the 14 workhorses (`saas-landing`, `simple-deck`, `dashboard`, `web-prototype`, `blog-post`, `meeting-notes`, `pm-spec`, `docs-page`, `pricing-page`, `team-okrs`, `weekly-update`, `finance-report`, `tweaks`, `critique`). The dropped twelve were external-tool-bound (HeyGen / Suno / Seedance / gpt-image-2) or stylistic niches. `extract-template.sh` SHIPPED_SKILLS reduced 68 → 44.

## [0.1.17] - 2026-05-11

### Fixed

- **`api-keys.sh` silently exited at step 10 on fresh installs** — when `.env` either didn't exist or didn't yet contain a given key, the line `current_val="$(grep "^${name}=" "$file" 2>/dev/null | head -1 | cut -d= -f2-)"` returned grep's exit 1 (no match) through the pipeline. Combined with `set -o pipefail` + `set -e` in install.sh, the assignment killed the script silently — no error message, no API-key prompts, no verify step. The shell prompt came back as if the installer completed normally. Added `|| true` at the end of the pipeline so an empty `.env` is read as "no current value" instead of crashing. Caught by a live install run on a clean clone (the bug was masked on developer machines where `.env` already had stubs).

## [0.1.16] - 2026-05-11

### Changed

- **Install order fix in README** — v0.1.13's three-tier section accidentally documented Lite CCv4 and Full as "do the Minimal flow first (clone + cd + claude + /bootstrap), then run install.sh". That's backwards: starting `claude` BEFORE install.sh means the session boots without CCv4 tooling on PATH and without hooks registered (hooks load at session-start, not on cd). The user would have to exit and restart Claude Code after install.sh — a frustrating extra step the README implied was normal. v0.1.16 rewrites Lite + Full as complete linear flows: `git clone` → `cd` → `./scripts/install.sh [flags]` → `claude` → `/bootstrap` + `/mcp` inside. Each tier is now a self-contained recipe with no "after the previous flow" phrasing.

## [0.1.15] - 2026-05-11

### Fixed

- **Bundled `.claude/agents/oracle.md` and `worker.md`** — these are subagent definitions that the ContinuousClaude V4.7 skills (`/autonomous`, `/premortem`, `/research`) dispatch via `subagent_type: worker` and `subagent_type: oracle`. v0.1.12-v0.1.14 silently shipped without them — fork users invoking `/autonomous` would have hit an "unknown subagent_type" error or silently fallen back to the broader `general-purpose` subagent (which has the full tool surface, defeating the worker-isolation design). Now bundled in-repo at `.claude/agents/`. `worker.md` (40 lines) defines a focused implementation worker restricted to `Read, Edit, Write, Bash, Grep, Glob`. `oracle.md` (208 lines) defines the external-research agent using the Ouros sandbox.
- **`extract-template.sh` PHASE 2.5 copies `.claude/agents/`** into the export tree alongside hooks/tools/settings.

### Notes

This was a real miss in the Day 1 bundle audit. The /autonomous skill referenced "workers" extensively in prose but Sid's session was loading the agent definitions from user-scope `~/.claude/agents/` — which fork users wouldn't have. Caught and fixed before any fork user tripped over it.

## [0.1.14] - 2026-05-11

### Changed

- **"Chat through it with Claude" prompt now handles install.sh** — the v0.1.13 README mentioned tiers but the agent-driven walkthrough prompt still only did `git clone` + handoff to `/bootstrap`, silently skipping the CCv4 tooling install in the same way the old README did. v0.1.14 patches the prompt template so Claude (the agent) asks the user which tier they want, then runs `./scripts/install.sh --skip-api-keys` (Full) or `./scripts/install.sh --no-fastedit-model --skip-api-keys` (Lite CCv4) for them — bypassing the interactive 5-key stdin prompts that would otherwise block. After install completes, the prompt instructs the user to fill in `.env` manually + run `/mcp` for OAuth.
- **Honest about Claude Code permission prompts** — the new prompt warns the user that install.sh fires many sub-commands (brew, npm, cargo, pip, uv) and Claude Code may prompt for each Bash type. Sets expectations so the user doesn't think the installer is broken.

## [0.1.13] - 2026-05-11

### Changed

- **README install section rewritten with three explicit tiers** — Minimal (chief-of-staff + design only, ~5 min, ~5 MB), Lite CCv4 (`--no-fastedit-model`, ~10-15 min, ~500 MB), Full (`./scripts/install.sh`, ~20-40 min, ~5 GB). Replaces two contradictory install sections from v0.1.12 that documented different flows on different pages. Each tier explicitly lists what tools land on disk, what skills become available, and approximate wall time. No script changes — `install.sh --no-fastedit-model` already handled the Lite tier; the fix is honesty in the docs.
- **Skill count claim corrected** — README now says "Skills (66 total)" instead of the stale "57 total" carried over from v0.1.11. The +9 is the ContinuousClaude V4.7 pipeline bundled in v0.1.12 (autonomous, autonomous-research, bootup, create-handoff, premortem, research, resume-handoff, review, upgrade-harness).
- **Skills category table** gains a "ContinuousClaude V4.7 pipeline (9)" row enumerating the bundled skills, so fork users can see what they get from each install tier.

## [0.1.12] - 2026-05-11

### Added

- **One-command installer** — `./scripts/install.sh` orchestrates an 11-step setup for fresh forks. Detects existing tooling (Homebrew, Claude Code, samba-onboarding artifacts via `gh + gws + claude` on PATH) and skips foundation steps when already configured. Idempotent at every step — safe to re-run. Flags: `--no-fastedit-model` (skip the ~3GB FastEdit model), `--skip-api-keys` (write empty `.env` stubs), `--verbose`, `--reconfigure` (re-prompt for keys), `--help`.
- **`scripts/lib/` — 12 installer modules.** Four copied verbatim from samba-onboarding (`ui.sh`, `detect.sh`, `prereqs.sh`, `claude.sh`). Eight new CCv4-specific modules: `sys-extras.sh` (ripgrep/ffmpeg/yt-dlp), `rust.sh`, `uv.sh`, `ccv4-bins.sh` (bloks + tldr-cli via cargo), `ccv4-python.sh` (requirements.txt + `fastedits[mlx,mcp]` via uv pip install --system, handles PEP 668), `fastedit-mcp.sh` (idempotent `.mcp.json` edit via jq), `api-keys.sh` (interactive prompts for 5 keys), `verify.sh` (binary probes + manual OAuth checklist).
- **`scripts/lib/CONVENTIONS.md`** — codifies the installer-lib conventions: 1-arg `step()` banner form, one function per lib, idempotency via presence-check, bash-3.2 portability, env-var cross-lib comms.
- **`INSTALL.md`** — manual install fallback for users who prefer step-by-step control over `install.sh`. ~220 lines: prerequisites, 11-step install, post-install OAuth (Slack/Figma/GWS), troubleshooting.
- **CCv4 hooks bundled in-repo.** `.claude/settings.json` declares `statusLine` + 4 hook events using `$CLAUDE_PROJECT_DIR`: `PreToolUse:Read→tldr-read`, `PreCompact→pre-compact`, `PostToolUse:Edit|Write|MultiEdit|Update→post-edit-diagnostics`, `Stop→auto-handoff-stop`. Existing `UserPromptSubmit:intent-detector` preserved.
- **`.env.example` rewritten** with 5 CCv4 keys (`ANTHROPIC_API_KEY`, `EXA_API_KEY`, `NIA_API_KEY`, `HF_TOKEN`, `ATLASSIAN_BASIC_AUTH`) and acquisition URLs for each.

### Changed

- **`extract-template.sh`** appends 9 CCv4 skills to `SHIPPED_SKILLS` (autonomous, autonomous-research, bootup, create-handoff, premortem, research, resume-handoff, review, upgrade-harness) and adds a `PHASE 2.5` block that copies hooks (5 mjs + 2 lib mjs), Python tools (4 files), `.claude/settings.json`, `scripts/install.sh`, and `scripts/lib/*.sh` into the export tree.
- **`TOOLS.md`** new "ContinuousClaude V4.7 bundle" section listing the 9 skills, 5+2 hooks, 4 Python tools, and the installer.
- **`README.md` project map** expanded with `.claude/{skills,hooks,tools}/` and `scripts/` lines; new Quick Reference row pointing fork users at `./scripts/install.sh`.

### Fixed

- **`ui.sh` exports `die` and `err`** — samba's `ui.sh` only defined `info`/`warn`, but CCv4 libs assumed all four. Calls to `die` crashed with `die: command not found` on error paths. Added one-line `err()` and `die()`.
- **PEP 668 / externally-managed-environment** — macOS Homebrew Python now refuses `pip install` system-wide. `ccv4-python.sh` switched to `uv pip install --system` with `--break-system-packages` fallback. uv is already a hard dep (installed at step 6).
- **`verify_all` respects `--no-fastedit-model`** — was flagging `fastedit` as MISSING and returning exit 1 even when the flag intentionally skipped its install. Now conditional on `NO_FASTEDIT_MODEL=0`.

## [0.1.11] - 2026-05-11

### Changed

- **SKILL.md frontmatter cleanup** — verified the spec against authoritative Claude Code docs and corrected the harness:
  - Removed `context: fork` from 14 first-party skills. The field is real but only takes effect when paired with `agent:` — without that companion, Claude Code silently ignores it. Was vestigial.
  - Added per-skill `allowed-tools` to 15 high-impact skills (briefing, bootstrap, find, contact, contact-log, new-project, archive-project, prune-projects, inbox-process, save-resource, sync-indexes, thinking-partner, samba-publish, company-research, people-research). `allowed-tools` is the real Claude Code field that grants no-prompt access to listed tools when a skill is active. Total skills with `allowed-tools`: 4 → 19.
- **Trimmed top-5 SKILL.md descriptions** that were exceeding the per-entry cap and suppressing other skills from the session-start listing:
  - `briefing` 2941 → 803 chars
  - `bootstrap` 2921 → 897 chars
  - `contact-log` 2006 → 658 chars
  - `contact` 1743 → 754 chars
  - `inbox-process` 1609 → 630 chars (was being dropped entirely)
  - Net ~7,478 chars / ~1,870 tokens reclaimed. Trigger phrases, invariants, composition notes, and historical pointers moved out of the description into the SKILL.md body where they belong.
- **`/briefing` v0.2.0** — output switched from `morning-briefing-YYYY-MM-DD.md` to `morning-briefing-YYYY-MM-DD.html`. Full DOM with `data-od-id` slugs follows the `design-dashboard` pattern (sidebar nav + topbar + KPI row + section panels + Tools-used footer). Self-contained: no `<script>`, no external links/fonts/CSS, no `http://` refs, inline SVG only.
- **Atlassian skill scripts parameterized** — `jira-create-vertical-slices/scripts/create_slices.py`, `scaffold-engineering-project/scripts/scaffold.py`, and `confluence-publish-markdown/scripts/publish_markdown.py` now read `ATLASSIAN_BASE_URL` (and `ATLASSIAN_CONF_SPACE` for the latter) from env with `<your-org>` placeholder fallback. No more hardcoded `sambatv.atlassian.net` references.

## [0.1.0] - 2026-05-10

First public release — the daily-agents harness extracted from Sid's private workspace.

### Added

- PARA workspace skeleton: `0-Inbox/` / `1-Projects/` / `2-Coding/` (`work`, `personal`, `forks`, `archive`) / `3-Resources/` (`contacts`, `meetings`, `reference`, `research`, `templates`, `design-systems`) / `4-Archive/`.
- Interactive `/bootstrap` skill — first-run setup walking through identity, persona, design-system pick, workspace skeleton, and tool detection. Tiger invariants T1–T4: never overwrites edited persona files, refuses to re-run on a configured fork without `--reconfigure`, never auto-commits, never installs tools.
- 74 shipped skills across 5 categories:
  - **15 first-party lifecycle**: `archive-project`, `bootstrap`, `briefing`, `budget-tracker`, `contact`, `contact-log`, `desktop-organizer`, `find`, `inbox-process`, `new-project`, `prune-projects`, `save-resource`, `skill-creator`, `sync-indexes`, `thinking-partner`.
  - **2 research**: `company-research`, `people-research`.
  - **3 Atlassian**: `confluence-publish-markdown`, `jira-decompose-epic`, `scaffold-engineering-project`.
  - **36 design**: `saas-landing`, `dashboard`, `blog-post`, `hyperframes`, `video`, etc.
  - **10 persona**: `exec-assistant`, `sales-ops`, `content-creator`, `project-manager`, `team-lead`, `hr-coordinator`, `it-admin`, `customer-support`, `event-coordinator`, `researcher`.
  - **1 samba-publish**: reference SSO-gated Cloudflare Pages publisher — non-Samba forks adapt domain + token.
- 73-brand design-system library — swap the active brand with `/use-design <brand>`.
- Dual-folder memory model — auto-memory at `~/.claude/projects/.../memory/` (per-machine, `MEMORY.md` index) plus a curated git-tracked `memory/` folder (daily logs, writing-style, learned-preferences).
- `intent-detector.mjs` hook v1 (fork-portable, passive logging).
- `gemini-vision` MCP server (free Gemini tier, multi-modal: image / OCR / document / video / YouTube).

### Not shipped (intentional)

- `gws-*` + `recipe-*` skills (47) — install the `gws` CLI separately to pick these up.
- `*-workspace` eval scratch directories (6).

[Unreleased]: https://github.com/the-sid-dani/daily-agents/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/the-sid-dani/daily-agents/releases/tag/v0.1.0
