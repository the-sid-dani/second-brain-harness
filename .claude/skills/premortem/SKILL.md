---
name: premortem
description: Pre-implementation failure analysis — first-principles retrospective with tiger/elephant risk classification
user-invocable: true
allowed-tools: [Read, Grep, Glob, Agent, AskUserQuestion]
---

Failure-state projection before implementation. Combines Shreyas risk taxonomy with first-principles retrospective reasoning. Runs after plan/spec, before work begins.

Risk categories: Tiger (clear threat requiring mitigation), Paper Tiger (appears threatening but manageable), Elephant (avoided topic with systemic impact).

Read target plan/spec files. Project forward to completion, then reason backward from imagined failure states. For each failure vector, trace backwards through these lenses:

**Base assumptions that led astray.** What foundational beliefs about users, tech, or timeline proved wrong? Cross-reference with project goals for contradiction points.

**Shortcuts taken.** Where did expediency override quality? Which "temporary" solutions became permanent? Map to technical debt accumulation.

**Weak implementations.** What components got minimal attention or testing? Single points of failure, untested edge cases.

**Missing evaluations.** What tests, metrics, or validations were skipped? How would we have caught deviation earlier?

**Necessity conditions.** What must remain true for task success? Environmental dependencies, resource availability, stakeholder alignment.

**Nth-order effects.** Secondary and tertiary consequences of primary decisions. Cascading failures, emergent behaviors, unintended interactions.

For each identified failure mode: falsifiable check (how to verify this risk is real vs imagined), root cause (distinguish proximate trigger from underlying system issue), cognitive bias scan (overconfidence, planning fallacy, confirmation bias, availability heuristic), then classify as tiger/paper tiger/elephant.

Risk output format:

```yaml
premortem:
  status: BLOCK|WARN|PASS
  tigers:
    - risk: "assumption X fails when Y"
      evidence: "file:line or observable condition"
      root_cause: "fundamental issue behind symptom"
      bias: "cognitive bias driving the assumption"
      falsifiable_test: "specific way to verify or disprove"
      mitigation: "required action before proceeding"
  paper_tigers:
    - risk: "appears threatening but bounded"
      why_manageable: "specific constraints limiting damage"
  elephants:
    - risk: "avoided systemic issue"
      why_avoided: "reasons for non-discussion"
      true_impact: "actual consequences if unaddressed"
```

Decision gate: Tigers present with no mitigation path — BLOCK, require mitigation before implementation. Only paper tigers and elephants — WARN, proceed with documented awareness. No significant risks — PASS.

Use AskUserQuestion only for tiger-level risks requiring implementation hold: "BLOCKED: {risk summary}. Options: add mitigation, accept with justification, need research."

Every risk must specify concrete evidence and a falsifiable test. If you cannot state what would disprove the risk, it is not a verified finding — demote to paper tiger or discard.
