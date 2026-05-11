# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
