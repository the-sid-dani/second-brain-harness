# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-10

First public release — the daily-agents harness extracted from Sid's private workspace.

### Added

- PARA workspace skeleton: `0-Inbox/` / `1-Projects/` / `2-Coding/` (`work`, `personal`, `forks`, `archive`) / `3-Resources/` (`contacts`, `meetings`, `reference`, `research`, `templates`, `design-systems`) / `4-Archive/`.
- Interactive `/bootstrap` skill — first-run setup walking through identity, persona, design-system pick, workspace skeleton, and tool detection. Tiger invariants T1–T4: never overwrites edited persona files, refuses to re-run on a configured fork without `--reconfigure`, never auto-commits, never installs tools.
- 74 shipped skills across 5 categories:
  - **15 first-party lifecycle**: `archive-project`, `bootstrap`, `briefing`, `budget-tracker`, `contact`, `contact-log`, `desktop-organizer`, `find`, `inbox-process`, `new-project`, `prune-projects`, `save-resource`, `skill-creator`, `sync-indexes`, `thinking-partner`.
  - **2 research**: `company-research`, `people-research`.
  - **3 Atlassian**: `confluence-publish-markdown`, `jira-create-vertical-slices`, `scaffold-engineering-project`.
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
