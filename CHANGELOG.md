# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — v0.2.1 (ships 3 skills + 2 hooks that were missing from v0.2.0)

The v0.2.0 release inadvertently shipped without three productivity skills and two SessionStart/PreToolUse hooks that already worked on the development fork. v0.2.1 adds them to the extractor allowlist and ships them publicly. Plus a PII scrub of the new ship surface caught and fixed before the bundle ever left.

**Skills (3):**
- **`/todo`** — Task tracking in personal Notion Action Items [DB]. Read-mostly skill: surfaces today's/tomorrow's tasks (`/todo today`), supports quick capture (`/todo add "..."`), and completion (`/todo done "..."`). Respects a PARA-aligned schema (1st-5th Priority, LNO Category, Kanban Status, Projects [DB] relation). Wraps the official `ntn` CLI + Notion HTTP API. Token + DS IDs auto-load from `~/.second-brain-os.env`. Never creates databases, renames properties, or deletes tasks (only Done/Archived status changes).
- **`/end-of-day`** — Nightly task reconciliation. Cross-references today's calendar / meeting transcripts / sent emails / (optionally) Slack outbound messages against open Notion Action Items to PROPOSE done-candidates and surface new commitments not yet tracked. Never auto-marks done — returns a proposed batch for confirmation. Closes the loop where overdue items get done same-day but stay flagged "overdue", and tasks with no due date never surface in "today" views.
- **`/atlassian-attach`** — Upload files (screenshots, diagrams, PDFs) as attachments to a Jira issue or Confluence page. Fills the gap the official Atlassian MCP leaves open (no attachment-upload tools). Pure stdlib Python via REST API. Pairs with `/confluence-publish-markdown` and `/jira-decompose-epic`. Auth via `ATLASSIAN_BASIC_AUTH` env var (classic API token only — scoped tokens cannot upload). Instance set via `ATLASSIAN_INSTANCE` env or `--instance <name>` CLI flag.

**Hooks (2):**
- **`session-start-tasks.mjs`** — SessionStart hook that injects current Notion task state (overdue + due today, 1st Priority) into session context, so the assistant is always aware of pending tasks before responding. Fails silently if `NOTION_API_TOKEN` / `NOTION_ACTION_ITEMS_DS` env vars are missing. Pairs with `/todo`.
- **`pre-slack-draft-contact-check.mjs`** — PreToolUse hook that, when drafting/sending a Slack message to a known contact, emits the contact-file context to stderr so the model sees relationship + open commitments + tone notes BEFORE the draft lands. Requires a `.claude/.slack-id-map.json` (Slack user IDs → contact slugs) and contact files at `<workspace.root>/3-Resources/contacts/<slug>.md`. Auto-discovers workspace root by globbing; fails silently if map or contacts missing.

### Changed

- **`scripts/extract-template.sh` allowlist updated**: 45 → 48 skills (added `atlassian-attach`, `end-of-day`, `todo`); 7 → 9 hooks copied (added `session-start-tasks`, `pre-slack-draft-contact-check`). Header comment updated to reflect new counts.
- **`pre-slack-draft-contact-check.mjs` workspace-path auto-discovery**: previously hardcoded `beru-workspace/3-Resources/contacts/`. Now globs `*/3-Resources/contacts/` at project root, so it works for any workspace name (`workspace`, `brain`, `vault`, etc.) — set by `/bootstrap` or fork user.
- **`atlassian-attach` scripts/attach.py**: removed `sambatv` hardcoded default for Atlassian subdomain; now empty default with a clear error message pointing to `ATLASSIAN_INSTANCE` env var or `--instance` flag. Example issue keys in docs changed from `AITF-450` (Samba's Atlassian project key) to generic `PROJ-450`.

### Fixed (PII scrub before ship)

Caught and fixed before the v0.2.1 bundle left the dev repo:

- `session-start-tasks.mjs` — "Beru is always aware" → "the assistant is always aware"; "When Sid says..." → "When the user says..."
- `pre-slack-draft-contact-check.mjs` — header rewritten to remove the specific 2026-05-18 incident reference (named a real colleague + their location); path reference genericized; closing message "before Sid sees it" → "before the user sees it"
- `todo/SKILL.md` — "Token authorized against Samba TV workspace" + `siddani09@gmail.com` reference rewritten to generic "work / shared Notion workspace"; "Sid promised X to Y" example → "<user.name> promised X to Y"
- `todo/lib/ntn.sh` — "Sid's convention from MEMORY" → "PARA-aligned convention"
- `atlassian-attach/references/usage.md` — all `sambatv.atlassian.net` URLs → `acme.atlassian.net`; "Different Atlassian instance (not sambatv)" → "Different Atlassian instance (override the default)"; "Defaults to `sambatv`" → "Defaults to whatever `ATLASSIAN_INSTANCE` env var is set to"
- `atlassian-attach/scripts/attach.py` — `__pycache__/*.pyc` stale bytecode removed from skill directory (already gitignored, but a local run had left an artifact)

### Removed

- `.claude/.slack-id-map.json` now in `.gitignore` (Sid's personal Slack user-ID → contact-slug map; locally configured, never ship). Defense-in-depth against future accidental commits.

### Notes

- All three Phase 10 extractor leakage passes (PII / path-refs / samba-tools-setup) clean on the v0.2.1 export.
- The v0.2.1 skill/hook PII scrubs and extractor allowlist updates landed in daily-agents before re-extraction.

---

### Added — v0.2.0 bundle (WFS-simplify-install, 2026-05-19)

- **`--with-coding` tier flag.** `./scripts/install.sh` now ships a knowledge-worker default tier (foundation + jq + `.env.example` + verify, ~3-5 min) and gates Rust/uv/CCv4 binaries/CCv4 Python deps/FastEdit-MCP behind `--with-coding`. Coding tier is required for `/research`, `/autonomous`, and FastEdit-MCP-backed edits — KW flows (`/briefing`, `/todo`, `/find`) don't need it.
- **`SBOS_TIER` marker.** Installer writes `SBOS_TIER=minimal|coding` idempotently to `~/.second-brain-os.env` (macOS-portable sed; preserves existing vars). `/bootstrap` Step 2 reads the marker — on minimal it renders a "skipped, not missing" panel for the CCv4 toolchain instead of a missing-tool warning.
- **`--with-ripgrep` opt-in flag.** ripgrep is no longer auto-installed; `/find` skill works with `grep -r` fallback. Pass `--with-ripgrep` for the faster path.
- **ASCII logo + closing summary card + duration.** `./scripts/install.sh` now opens with a banner, prints a tabular installed-tools card on exit (tier-aware columns), reports total install time, and tees output to `~/.claude/install.log`.
- **3-layer closing banner.** Final install message frames the journey as Layer 1 (system tools — done) → Layer 2 (`/bootstrap`) → Layer 3 (optional `.env` keys). Coding-tier hint shown only on minimal install.
- **`.mcp.json` interactive opt-in via `/bootstrap` Step 2.5.** Default `.mcp.json` ships **3 universals only** (gemini-vision / exa / firecrawl) — zero red errors on a fresh `claude` launch. Slack / Atlassian / Figma canonical entries live in `.mcp.json` `_notes.opt_in_*` (single source of truth) and get appended to `mcpServers` interactively when the fork user picks them during bootstrap.
- **firecrawl MCP** added as the third universal default — official remote MCP at `https://mcp.firecrawl.dev/v2/mcp`, auth via `FIRECRAWL_API_KEY` env var.
- **`assistant.pronoun` field** added to `/bootstrap` Step 4a (options: she / he / they / no-pronouns). Configuration block now includes `assistant.pronoun = X`; all `<him/her/them>` placeholder strings resolve to the chosen pronoun in bootstrap output.
- **Day 2+ rhythms externalized** to `beru-workspace/3-Resources/onboarding/day-2-plus.md`. `/bootstrap` final message links to it instead of inlining the content.

### Changed

- **`/bootstrap` SKILL.md slimmed 929 → 498 LOC (-46%)**. 8 narrated steps merged into 6. T1-T4 invariants kept canonical-only in their dedicated section; point-of-use full paragraphs replaced with single-line refs in step headers. Failure-modes table trimmed 18 → 10 rows. Step 4b (voice synthesis) three branches collapsed into one spec with a single preview-before-write gate. Affective moments preserved verbatim: "Meet your assistant:" echo-back, voice-synthesis preview gate.
- **`.env.example` rewritten.** Sections split by purpose (default-MCP keys / skill-only keys / opt-in connector keys). Added `GEMINI_API_KEY` and `FIRECRAWL_API_KEY` entries with shell-export notes. Removed the stale "installer prompts interactively — re-run with `--reconfigure` to rotate" copy (installer no longer prompts).
- **`INSTALL.md` rewritten for the tier model.** Was: 11 mandatory steps with ffmpeg/yt-dlp/Rust/CCv4 unconditional. Now: Path A (minimal, 5 steps) and Path B (coding, +5 steps), tier marker + post-install OAuth flow updated for the opt-in MCP model.
- **`TOOLS.md` MCP + env sections** rewritten to lead with the 3 default MCPs; opt-in connectors documented as "added during `/bootstrap`, not by hand-editing `.mcp.json`". Added `FIRECRAWL_API_KEY` and `SBOS_TIER` to the Environment files section.
- **`README.md` Forking section** updated with the 2-layer install model (system tools / persona + workspace), tier flag mention, and the v0.2.0 MCP defaults paragraph. Quick Reference table adds tier-aware install rows.
- **Bootstrap Step 2 panel copy** swapped to the literal UX-flagged text from synthesis-spec §Q5 — "Optional coding-tier tools — Skipped, not missing" instead of the older CCv4-missing-warning copy.

### Removed

- **ffmpeg + yt-dlp auto-install** dropped from `scripts/lib/sys-extras.sh` (zero active skills consume them; pre-existing brew installs untouched).
- **ffmpeg / yt-dlp probes** dropped from `scripts/lib/verify.sh`.
- **TOOLS.md rows** for ffmpeg + yt-dlp removed (the binaries may still exist on Sid's machine but are no longer managed by the installer).
- **Slack / Atlassian / Figma** removed from default `.mcp.json` `mcpServers` (preserved in `_notes.opt_in_*` for bootstrap re-add). Fresh-fork `/mcp` now shows 3 entries, zero red errors. Sid's existing fork: project-scope entries gone; user-scope registrations via samba-onboarding unaffected.
- **`SAMBA_ONBOARDING_DETECTED` block dropped from `scripts/install.sh`.** The Samba-employee detection branch + closing-banner hints leaked the private path `beru-workspace/2-Coding/samba-onboarding/` into the public OS bundle. Caught by `extract-template.sh` PHASE 10 path-ref leakage probe before shipping to `second-brain-os`. Samba employees still install their internal CLIs by running samba-onboarding directly — they don't need the daily-agents installer to surface that fact.

### Notes

- v0.2.0 acceptance gate (per IMPL_PLAN §7) met structurally: bootstrap LOC <500 ✅ (498); MCP defaults clean ✅ (3 universals); tier gating ✅; zero "what's bloks?" jargon on minimal tier ✅ (bootstrap Step 2 panel uses the "Skipped, not missing" wording). Empirical M1/M2 (time-to-first-`/briefing` <15 min; default install <5 min) require fresh-VM smoke test before tagging.
- **Not in v0.2.0**: cross-platform Python rewrite (W4, ~14-18h) and Windows port — deferred to v0.3.0. `--doctor` flag is a no-op stub in v0.2.0; full implementation is part of v0.3.0 (W5).

## [0.1.23] - 2026-05-17

### Removed

- **Extractor's Phase 6 `~/.daily-agents.env` → `~/.second-brain-os.env` sed step** — added in v0.1.20 to compensate for `72e9129` (which had drifted the atlassian-skill env paths to `.daily-agents.env`). Since `fca6c97` reverted the source files back to `.second-brain-os.env` directly, the sed had become a no-op. 12 lines of dead defensive code removed. Phase 10's `daily-agents` leakage scan still catches accidental regressions if any future commit reintroduces the wrong path.

### Notes

- Extractor-only change. No skill bodies, hooks, root docs, or installer affected.

## [0.1.22] - 2026-05-17

### Changed

- **README restructured to lead with concepts, not commands.** The v0.1.21 README jumped straight into the install tier table + 3 install commands before explaining what the OS is, what a "skill" is, or what `/bootstrap` does. Fork users landed on a wall of shell commands without context. New structure:
  1. **What is this?** (concept first)
  2. **How it works** — new section explaining the three layers (skills / PARA workspace / Configuration tokens) and the two-stage setup model (shell `install.sh` for power-user toolchain, Claude `/bootstrap` for personalization)
  3. **Install** — now framed as "you're trying to reach `/bootstrap`; everything else is plumbing." Path A (Minimal) is `clone → cd → claude → /bootstrap`; Path B (Lite CCv4) adds `./scripts/install.sh --no-fastedit-model` before `claude`; Path C (Full) drops the flag.
  4. **The PARA workspace** — explains each of the 5 folders (`0-Inbox`, `1-Projects`, `2-Coding`, `3-Resources`, `4-Archive`) with a "what goes in it" + "why it exists" column. New callout that `/bootstrap` creates the empty folder skeleton; skills own the content.
  5. Reference sections (Project map, Configuration tokens, Update Rules, What's included, Quick reference) come after.
- **`/bootstrap` reframed as the central setup step.** Previous README treated `install.sh` and `/bootstrap` as equally-weighted install steps. The new framing: `/bootstrap` is THE step that personalizes the OS to you; `install.sh` is optional plumbing that only matters if you want `/research`, `/autonomous`, `/premortem`, `/review`. Minimal-tier users skip `install.sh` entirely.

### Notes

- README-template.md grew from 438 → 482 lines (+44, mostly the new "How it works" section).
- No skill bodies, hooks, or scripts changed in v0.1.22 — README-only release.

## [0.1.21] - 2026-05-17

### Changed

- **Persona templates rebranded to "Second-Brain OS".** Fork users were seeing the old "Second-Brain Harness" name in their regenerated `CLAUDE.md` and `README.md` (CLAUDE-template.md heading + body, README-template.md heading) — leftover from the v0.1.18 rename that didn't catch the templates. Fixed at the source so the next `/bootstrap` produces correctly-branded persona files.
- **Removed stale `hyperframes` references** from the shipped bundle. The `design-hyperframes` skill was dropped in v0.1.13 (external HeyGen tool), but the name lingered in `TOOLS-template.md` ("video/transcript flows (hyperframes, transcript-extract.sh)"), `INSTALL.md` ("ffmpeg for video encoding (used by hyperframes / design skills)"), and a `README-template.md` example query ("what did I save about Hyperframes?"). Cleaned in 3 spots.
- **`.env.example` header** "Second-brain-harness API keys" → "second-brain-os API keys".
- **EXAMPLE-CONFIG.md** now documents the `assistant.vibe` field (was missing from the example block and field-reference table — `vibe` is referenced in CLAUDE.md Configuration but the worked example didn't show it).
- **Stray `decision #N` and `system-design.md` cross-references scrubbed from 6 shipping skills** (`thinking-partner`, `archive-project`, `save-resource`, `new-project`, `sync-indexes`, `briefing`). These were parenthetical citations like "per decision #15", "decision #23 token-isolation", "Locked by decision #22" — fork users don't have the `system-design.md` source file the numbers reference. The principles remain in the skill bodies as principles; the broken citations are gone. Legitimate references to `system-design.md` as a user-input file (in `jira-decompose-epic`, `scaffold-engineering-project`, `confluence-publish-markdown` — where the user's own design doc is the expected input) are preserved.

### Notes

- This was a polish-pass surfaced by manual review of the v0.1.20 export — the v0.1.20 release already had these residual refs; the bundle worked fine but the wording was sloppy for first-time forkers. v0.1.21 is the cleanup.

## [0.1.20] - 2026-05-17

### Changed

- **Installer rebrand — fork users now see "Second-Brain OS Installer" instead of "Samba Onboarding".** Stale `samba-onboarding`-named language was leaking into the user-facing surfaces of the v0.1.19 bundle — the installer header, log file (`~/samba-onboarding.log`), shell-rc comment block, runtime "samba-onboarding artifacts detected" message, and the `INSTALL.md` troubleshooting section all referenced the company-internal install tool that fork users don't have. Renamed in 6 files: `scripts/lib/ui.sh` (header + subtitle + log filename), `scripts/lib/prereqs.sh` (shell-rc comment + stale "Installing Samba CLIs" reference), `scripts/lib/verify.sh` (post-install hints), `scripts/install.sh` (top-of-file comment + variable rename `SAMBA_DONE`→`FOUNDATION_INSTALLED` + foundation-detection message), `INSTALL.md` (troubleshooting section), and `beru-workspace/3-Resources/templates/scripts/transcript-extract.sh` (comment). Detection logic widened from `gh + gws + claude` to `gh + claude` (gws isn't shipped in this bundle).
- **`os-guide` skill body genericized.** Removed ~15 abstract `decision #N` and `system-design.md` cross-references that wouldn't resolve for fork users (the design log is maintainer-private). Skill remains operative: still routes OS-shaped questions to canonical sources, still cites with file:line refs. Dropped the "Locked design decisions" routing-table subsection entirely (was Sid-private). Replaced "After locking a new decision in `system-design.md` §7" with "in your fork's design log (if you keep one)". Cleaner for forkers, no functional change for the maintainer.
- **Contact-skill examples genericized to placeholder names.** `contact/SKILL.md` and `contact-log/SKILL.md` taught the fuzzy-match algorithm using literal Samba colleague names (Omar Zennadi / Jaya Aswani / Alyson Sprague / Bob van Toorn / Lena Kincaid / Michael Zennadi). Replaced consistently across the skill bodies with placeholder names (Alex Chen / Priya Patel / Jordan Rivera / Robin van Pelt / Lena Okoye / Michael Chen + michele anti-regression example) that preserve the algorithmic structure including the substring-vs-token anti-regression rule.
- **Briefing skill body genericized.** `briefing/SKILL.md`: 9 literal "Sid" references replaced with `<user.name>` or "the user"; tagline examples changed from "Omar's waiting on you" to "Alex is waiting on you"; the "Origin incident" callout that named real colleagues (Bob/Jay/Walter/Phillip group DM) replaced with the abstract "a multi-person DM thread containing the highest-leverage open question was invisible" version that preserves the technical lesson.
- **External-action-guard hook message** changed from "explicit Sid approval" to "explicit user approval".

### Fixed

- **`scripts/lib/prereqs.sh` `install_jq` comment** referenced `validate_oauth_json` and "step 5 (Installing Samba CLIs)" — neither exists in the public bundle. Rewrote to point at the real consumers (`.claude/tools/*`, extract-template.sh settings-filter, MCP config parsing).

### Known issues remaining (cosmetic)

- Brand-preset count in v0.1.19 CHANGELOG narrative says 72 but the actual export ships 73. Cosmetic.

## [0.1.19] - 2026-05-17

### Added

- **`os-guide` skill** — runtime-read librarian over the OS's canonical source files. Answers "how does X work in this OS?" by routing the question to its canonical source (CLAUDE.md / README.md / SOUL.md / TOOLS.md / SKILL.md files), reading at runtime, and citing with file:line refs. Two-audience design: (a) Claude Code self-correcting mid-session before writing an OS-shaped claim from memory, (b) fork users in their first 30 days. Read-only by default; `/os-guide --sync` is the only mutation mode and refreshes the routing table after new tools / skills / brands / decisions are added. Locked principle: explainer skills must be runtime-read librarians, not textbooks — referencing canonical sources, never reproducing them.
- **`external-action-guard.mjs` hook** — PreToolUse show-and-confirm friction on irreversible external actions: Slack send (`mcp__slack__slack_send_message` + `slack_schedule_message`), GitHub destructive push (`git push --force` or `git push` targeting main/master), Atlassian writes (Jira issue create/edit/transition + Confluence page create/update), `rm -rf` outside whitelisted paths (`/tmp/`, `node_modules/`, `__pycache__/`, `.venv/`, `dist/`, `build/`, `.tldr/`, `.workflow/`). Emits `permissionDecision: "ask"` via modern `hookSpecificOutput` format — block is show-and-confirm, not show-and-deny. Goal: friction at the moment of action, not refusal. Fails open on any error.
- **`/os-guide` consult section in CLAUDE-template.md** — tells Claude to invoke `/os-guide` instead of answering OS-shaped questions from memory. Specifically applies before writing a workspace path, Configuration value, schema field, skill-behavior claim, or tool-connection-state claim into a user-facing response.
- **"What is PARA in this OS?" section in README-template.md** — table explaining the 5-folder workspace layout (`0-Inbox`, `1-Projects`, `2-Coding`, `3-Resources`, `4-Archive`) with a Configuration-token bridge and a "Areas was deliberately cut" callout. Helps fork users distinguish the in-this-OS implementation from Tiago Forte's generic PARA framework.
- **"How to add a tool" section in TOOLS-template.md** — step-by-step guide for adding MCP servers (declare in `.mcp.json` → authorize via `/mcp` → probe → flip status → `/os-guide --sync`) and CLI tools (install → auth probe → add row → `/os-guide --sync`). Plus a "Removing a tool" subsection. Each path has a verification probe baked in.
- **Two new Quick Reference rows in README-template.md** — `/os-guide` for understanding how X works in this OS, `/os-guide --sync` for refreshing the routing table after additions.
- **`/os-guide` Day 1 + Day 2+ mentions in `bootstrap` SKILL.md** — Day 1 onboarding now points fork users at `/os-guide` after `/bootstrap`, and Day 2+ rhythms list `/os-guide --sync` as the after-adding-a-tool follow-up.

### Changed

- **`SHIPPED_SKILLS` allowlist** — 44 → 45 skills. Added `os-guide` to the first-party group (15 → 16).
- **`os-guide` skill body genericized** — replaced literal `beru-workspace/` paths with `<workspace.root>/<workspace.resources>/` token forms in 7 locations (line references in canonical source listings, citation examples, the PARA disambiguation question). Removed the "Locked design decisions" subsection that referenced Sid's private design project (`2026-05-second-brain-design/system-design.md`). Decision-numbered references (`decision #N`) elsewhere in the skill body are left as-is for this release — they don't break the leakage scan but are broken cross-refs for fork users; cleanup deferred to a future release.
- **`external-action-guard.mjs` spec comment** — genericized to drop the path reference to Sid's private design project.

### Removed

- **`pii-leak-guard.mjs` not shipped in the public bundle.** The hook hardcodes Sid's PII patterns (`sid.dani`, `Siddharth`, `@samba.tv`) as the literal regexes it guards against. Useful for the maintainer's local workspace but useless and confusing to fork users (it would warn about leaking *someone else's* PII). Kept in the maintainer's local tree; not copied by `extract-template.sh`. The corresponding hook registration in `.claude/settings.json` is stripped via a new `jq` filter step in the extractor so the public bundle doesn't ship a dangling hook reference. Re-introduce as a config-driven generic (pattern file or env var) in a future release.

### Infrastructure

- **Extract-template.sh hook copy list updated** — `pii-leak-guard` removed from the for-loop at PHASE 2.5; `external-action-guard` retained. New `jq` post-copy filter on `.claude/settings.json` drops the `PreToolUse` hook block whose `command` references `pii-leak-guard.mjs`. Filter is no-op-safe (handles missing jq gracefully via `warn`).

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
