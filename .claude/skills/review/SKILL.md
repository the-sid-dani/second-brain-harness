---
name: review
description: Structural + semantic code review — bugbot L1/L2 facts + tldr analysis + Claude Code reasoning
user-invocable: true
allowed-tools: [AskUserQuestion, Agent, Bash]
---

Hybrid review anchoring LLM reasoning on deterministic structural analysis. Runs locally, no cloud, no cost per seat. You dispatch structural analysis to agents, keep main context for semantic reasoning over their findings.

Use for "review this code", "review my changes", "review my PR", "check before I merge", pre-push quality gates, "what did I break?"

Architecture: Phase 1 runs bugbot L1/L2 + tldr impact/smells/complexity/security via parallel agents for structural facts. Phase 2 applies Claude Code semantic reasoning over facts + git diff for unified review.

Arguments: `/review` (full review uncommitted), `/review --staged` (staged only), `/review --base-ref main` (since main), `/review --quick` (bugbot + smells only), `/review --security` (add security focus), `/review <path>` (specific directory).

Parse arguments setting SCOPE (default `.`), BASE_REF (default `HEAD`), STAGED_FLAG (`--staged` if applicable), MODE (`full`/`quick`/`security`). Run `git diff --stat ${BASE_REF}` or `git diff --staged --stat` to understand changes. If no changes, stop. Extract changed files and function names from diff.

Launch 3 parallel agents for structural analysis:

Agent 1 (bugbot): `subagent_type: "general-purpose"` with prompt "Run bugbot differential analysis and return ALL output verbatim. Commands: `tldr bugbot check --format json --no-fail --quiet ${STAGED_FLAG} --base-ref ${BASE_REF} ${SCOPE}`. Return complete JSON output, do not summarize or filter."

Agent 2 (impact-analysis): `subagent_type: "general-purpose"` with prompt "For each changed function [LIST FROM DIFF], run impact and whatbreaks analysis. Return ALL output verbatim as JSON. For each function run: `tldr impact <function_name> ${SCOPE} --format json --quiet` and `tldr whatbreaks <function_name> ${SCOPE} --format json --quiet`. Also run `tldr dead ${SCOPE} --format json --quiet` on each changed file. Return all results combined."

Agent 3 (quality-analysis): `subagent_type: "general-purpose"` with prompt "Run quality and security analysis on changed files [LIST FROM DIFF]. Commands: `tldr smells ${SCOPE} --format json --quiet`, `tldr hotspots ${SCOPE} --format json --quiet`. For each changed file with functions: `tldr complexity <file> <function> --format json --quiet`, `tldr cognitive <file> --format json --quiet`. If MODE security or full add: `tldr secure ${SCOPE} --format json --quiet`, `tldr taint <file> <function> --format json --quiet` for endpoint/handler functions. Return all results combined."

Wait for all agents. Gather context by reading agent outputs plus running `git diff ${BASE_REF} --unified=5 ${SCOPE}` (or `git diff --staged --unified=5 ${SCOPE}`). If diff >500 lines, focus on files with most bugbot/tldr findings.

Apply semantic reasoning over structural findings + actual code. You reason over computed facts, not guesses.

For bugbot L1 findings: read actual code around each finding, assess if real issue or acceptable in context, suggest concrete code changes, evaluate if linter severity matches actual risk.

For bugbot L2 findings: signature regressions check if all callers updated and which missing, born-dead code assess if intentionally staged or forgotten, complexity increases check if justified or suggest extraction, new code smells evaluate if real design problem or acceptable.

For impact analysis: identify touched high-centrality hub functions, map downstream affected code, check test coverage of affected paths using `tldr change-impact` if needed.

For quality metrics: find complexity hotspots (high-churn AND high-complexity functions), identify cognitive complexity spikes making functions harder to understand, spot newly introduced dead code (unreachable functions, unused imports).

For security (if mode includes): analyze taint flows for unsanitized user inputs reaching sensitive sinks, check resource leaks (opened files/connections not closed on error paths), detect vulnerability patterns (SQL injection, XSS, command injection).

Output format:

## Review: [scope description]

**Verdict: APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION**

### Structural Facts (bugbot + tldr)

| Category | Count | Severity |
|----------|-------|----------|
| L1 lint violations | N | N critical, N warning |
| L2 regressions | N | N signature, N born-dead, N complexity |
| Impact radius | N functions affected downstream |
| Security findings | N | (if applicable) |

### Blocking Issues

[Issues MUST be fixed before merging:]
1. **[severity] [category]**: description
   - File: `path:line`
   - Structural fact: what bugbot/tldr found
   - Semantic analysis: why it matters
   - Suggested fix: concrete code change

### Warnings

[Worth fixing but not blocking:]
1. **[warning] [category]**: description
   - Structural fact + semantic context

### Observations

[Non-actionable notes: complexity trends, architecture observations, positive changes worth noting]

### Test Coverage

- Changed functions with tests: N/M
- Suggested test additions: [list]
- Run: `tldr change-impact [changed files]` for affected test list

### Summary

[2-3 sentence human-readable summary]

Quick mode (`/review --quick`): skip agents 2 and 3, only run `tldr bugbot check --format json --no-fail --quiet ${SCOPE}` and `tldr smells ${SCOPE} --format json --quiet`, reason over findings directly in main context for faster but less thorough review.

Security mode (`/review --security`): add to Agent 3: `tldr secure ${SCOPE} --format json --quiet`, `tldr vuln ${SCOPE} --format json --quiet`, `tldr taint <file> <handler_func> --format json --quiet`, `tldr resources <file> <func> --format json --quiet`. Security findings get elevated severity in review output.

PR mode (`/review PR #N`): run `gh pr diff N > /tmp/pr-diff.patch`, `gh pr view N --json files,additions,deletions`, `git fetch origin pull/N/head:pr-N`, `git diff main...pr-N`, then run same pipeline with `--base-ref main`.

Constraints: never use Read, Edit, Write, Grep, or Glob yourself except git diff in context gathering — delegate structural analysis to agents. Phase 1 agents run deterministic tools producing facts not opinions. Phase 2 is where you add value reasoning over facts without hallucinating findings. Always present structural evidence alongside semantic judgment. Keep main context clean — agents gather facts, you synthesize.

| Finding | Suggest |
|---------|---------|
| Blocking issues found | `/autonomous` to fix each issue |
| Unknown root cause for regression | `/autonomous` to investigate |
| Major architectural concern | `/research` to spike alternatives |
| All clear | `/commit` to commit changes |
| Multiple issues across codebase | `/autonomous` to plan and fix systematically |
