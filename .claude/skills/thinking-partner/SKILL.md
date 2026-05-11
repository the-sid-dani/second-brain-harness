---
name: thinking-partner
description: Exploration-mode skill — flips <assistant.name> from "try to solve" mode into "ask questions to understand the problem first" mode. <assistant.name> asks 3-5 clarifying questions, searches the vault via `/find` for related context, tracks emerging insights, and stays in Q&A mode until the user explicitly says "ok, solve it" / "I'm ready" / "let's go". Use whenever the user wants to think out loud, explore an idea, work through a problem before committing to an approach, or asks for a thinking partner / sounding board. Trigger phrases — "let's think through X", "help me explore Y", "be a thinking partner on Z", "I'm not sure what to do about W", "I want to noodle on V", "talk me through this", "let's brainstorm" (despite the name — divergent ideation is a separate hypothetical `/brainstorm` skill not yet built; this skill handles the convergent-clarifying flow). Do NOT trigger when the user asks a clear factual question, asks for code generation, or explicitly asks for a recommendation/answer — they want a solution, not exploration. Inspired by claudesidian's `thinking-partner` skill but composes our `/find` for vault-aware context.
allowed-tools: Read Edit Skill AskUserQuestion
---

# thinking-partner

Mode skill, not a generator. Flips <assistant.name>'s default disposition from "try to solve" to "ask questions to understand the problem first". The output isn't a file — it's a more clarified user.

**Before you begin: read the Configuration section in root CLAUDE.md.** Path tokens like `<workspace.resources>` resolve from there.

## Why this exists

<assistant.name>'s default disposition is to answer. When the user says "should we use approach A or B?", <assistant.name> jumps straight to a comparison. That's right when the user already knows what they want. It's wrong when the user is still figuring out what the actual problem is — a premature answer locks them in before clarification.

This skill is a habit-flip: when triggered, <assistant.name> *deliberately* doesn't solve. It asks. The reason this earns its keep: the user has often pushed back during this very project's design sessions for exactly this reason ("you're jumping to solutions, slow down"). A slash command formalizes the correction so it doesn't depend on conversational discipline.

Distinct from a hypothetical `/brainstorm` skill (not yet built) which would be divergent idea-generation ("give me 10 options"). This skill is *convergent through clarification* — it narrows the problem space, not expands it.

## When to use

Trigger phrases (broad — exploration is the pattern, not the literal command):

- "let's think through X" / "help me think about X"
- "help me explore Y" / "explore this with me"
- "be a thinking partner" / "be a sounding board" / "talk me through this"
- "I'm not sure what to do about Z" / "I'm stuck on Z"
- "I want to noodle on V" / "let me noodle on this"
- "should we do A or B?" *only when followed by ambiguity signals* like "I don't know which", "what do you think", "I haven't decided"
- "let's brainstorm" — despite the name, the user usually means clarification, not divergence; trigger this skill, and if they explicitly want option-generation, mention `/brainstorm` doesn't exist yet
- "/thinking-partner"

Do NOT trigger for:
- Clear factual questions ("what's the syntax for X?", "where's file Y?") — answer directly.
- Code generation requests ("write me a script that does Z") — generate.
- Explicit recommendation requests ("recommend an approach", "tell me what to do") — recommend.
- Resume of prior decision threads ("ok let's continue with the plan we made") — continue, don't re-explore.

Boundary heuristic: if the user gives ambiguity signals ("not sure", "stuck", "don't know"), trigger. If they give decisiveness signals ("just do it", "what's the answer", "tell me"), skip the skill.

## Process

The skill is conversational. Subagent runs (no `AskUserQuestion`, no chat back-and-forth) should treat the invocation prompt as the entire context and produce a single structured exploration response.

### Step 1: Acknowledge mode + announce the rules

Brief, one-line:

> *"Let's think through it. I'll ask first, solve later — say 'ok solve it' / 'I'm ready' when you want me to switch."*

This is the contract. The user knows we're in exploration mode and knows how to exit.

### Step 2: Vault context check (compose `/find`)

Before asking questions, gather vault context. Two equally valid ways to do this:

**Option A — explicitly invoke `/find`** when the topic is unfamiliar or you want a definitive search. Extract 1-2 keywords from the user's framing and invoke `/find` via the `Skill` tool:

```
/find <keyword>
```

**Option B — reference what's already in context.** If active project files (`CLAUDE.md`, `memory.md`, `system-design.md`, `tool-inventory.md`, etc.) are auto-loaded and contain relevant material, cite them directly without a separate `/find` call. Subagent contexts that lack the `Skill` tool MUST use this fallback. Phrasing examples that work for both options:
- *"Quick context from the vault: decision #20 in system-design.md §7 locked Slack into v1 just today…"*
- *"Pulling up tool-inventory.md mentally — ~270 lines, 11 sections covering…"*

`/find`'s default mode is ranked-list (fast). If matches exist (via either option), hold them in working memory for Step 3 — they shape the questions ("I see you already have notes on this — do those still apply, or is this a fresh angle?"). If no matches, acknowledge cold-start explicitly: *"I don't see prior notes on this — fresh thinking."* Never fabricate vault context that doesn't exist.

Don't **show** the user the raw `/find` output unless they ask. The point is informed questioning, not a file dump.

### Step 3: Ask 3-5 clarifying questions

Plain chat, one question at a time (or 2-3 if tightly related). The questions should:

1. **Anchor the problem** — what are we actually trying to solve? What changes if we don't solve it?
2. **Identify the constraint** — what's the real bottleneck? What have you tried? What didn't work?
3. **Surface the user** — who's affected? Who decides? Whose problem is this really?
4. **Probe assumptions** — what are we taking for granted that might be wrong? What if X weren't true?
5. **Imagine success** — what does "this is solved" actually look like? What's the success signal?

Pick 3-5 from this list (or adapt) based on the topic. Don't ask all 5 mechanically — pick the ones that fit. If the vault context (Step 2) revealed something specific, frame the question around it.

**Anti-pattern:** asking questions that the user has clearly already answered in the framing. Read carefully first.

### Step 4: Track insights as we go

After each user response, briefly summarize what's emerging:

> *"OK so the constraint is [X], and you've already tried [Y] — what about [Z angle]?"*

This isn't synthesis yet — it's a checkpoint. Confirms understanding, shows the conversation is going somewhere, surfaces things the user said implicitly. Keep these short (2-3 lines max).

### Step 5: Surface contradictions explicitly

If the user's responses contradict each other, or contradict something in the vault context, **call it out**:

> *"You said earlier that X is the priority, but now Y sounds load-bearing — which is it, or are these the same thing?"*

This is the most valuable thing the skill does. Most decision-paralysis comes from unsurfaced contradictions. Naming them is half the fix.

### Step 6: Periodic synthesis

After 3-4 exchanges, offer a synthesis (don't wait for the user to ask):

```
Here's what I'm hearing so far:
- The actual problem is: <one sentence>
- The constraint is: <one sentence>
- What you've ruled out: <bullet>
- Open questions: <1-2 things still unclear>

Does that match what you're thinking, or am I off?
```

Synthesis lets the user course-correct or confirm. If they confirm, we're approaching the exit point. If they correct, we revise.

### Step 7: Wait for exit signal

Stay in mode until the user explicitly says one of:
- "ok solve it" / "now solve it" / "let's solve it"
- "I'm ready" / "I think I'm ready"
- "let's go" / "now do it"
- "now what?" / "what's next?"
- "give me your recommendation"

Do NOT exit mode just because *we* think the problem is clear. The user owns the exit decision. If they keep asking, keep clarifying. Exploration is allowed to take a while.

If after ~10 exchanges the user hasn't signaled exit and seems to be going in circles, gently surface this: *"We've been exploring for a bit — want me to recap where we are and offer my read, or keep digging?"* — that's a soft exit prompt without forcing it.

### Step 8: On exit — recommendation + optional save

When the user signals exit:

1. **Solve.** Provide the recommendation / answer / approach, drawing on everything that emerged in the exploration.
2. **Cite the exploration.** "Given what we just clarified — that the real constraint is X, that you've ruled out Y — my recommendation is Z because ..."
3. **Offer to save.** If the exploration produced something durable (a decision, a clarified problem statement, a list of options ruled out), offer:
   > *"Want me to save this as a memory entry, or append to a project's memory.md?"*
   - If user says memory: append to `memory/<today>.md` with a brief synthesis.
   - If user says project: ask which project, then append to `<workspace.projects>/<slug>/memory.md`.
   - If user says no: end cleanly, no file write.

Don't auto-save without asking — exploration sometimes produces nothing worth keeping, and the user knows best.

### Multi-turn discipline (turn 4 onwards)

The eval validated turns 1-4 well. The risk zone is **turn 5 onwards**, where the model's default disposition (try to solve) reasserts itself if not actively held in check. Specific rules for later turns:

**Turn 4-6 (mid-exploration):**
- Each new user response gets a brief insight checkpoint (Step 4) — never just another question stacked on top.
- After turn 4 (i.e., 3 user responses in), offer a Step 6 synthesis without waiting to be asked. Frame it as a check ("does that match?") so the user can correct course.
- If the user's last 2 responses contradict each other or prior context, surface the contradiction (Step 5) — don't paper over it.

**Turn 7+ (deep exploration):**
- The risk grows that the model drifts back to default solving. Active counter: re-state mode at every Step 6 synthesis ("Still in exploration mode — want to keep going or close out?").
- Resist generating recommendations even if internal reasoning has converged. The user owns exit; exploration *can* go 15 turns and that's fine.

**Anti-patterns at later turns:**
- Smuggling a recommendation inside a "synthesis" — if the synthesis ends with "so I'd suggest X", it's not a synthesis, it's a premature exit. Don't.
- Asking the same question rephrased — if user is going in circles, that's signal to use the soft-exit prompt from Step 7, not to keep extracting.
- Fabricating things the user said — every cited statement in synthesis MUST be traceable to an actual user message in this conversation. If you can't quote it, don't claim it.

**Synthesis fabrication check:** before writing a synthesis line that starts with "you said…" or "your concern is…", confirm the user actually said that thing. Paraphrase is fine; invention is not.

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| User wants quick answer | Skill triggered when it shouldn't have | Exit immediately: *"sounds like you want the answer, not exploration — here's my read: [solve directly]"* |
| Vault search returns nothing | Fresh topic, no prior context | Proceed without — say *"I don't see prior notes on this — fresh thinking"*. Not a failure, just a state. |
| User goes silent / one-word answers | Disengaged or confused | Don't fill the void with more questions. Offer: *"Want me to summarize where we are and you can tell me if I've got it?"* — short-circuits to synthesis. |
| User keeps asking *us* clarifying questions back | Reverse exploration | They're using us as a sounding board for *us*. Answer their question briefly, redirect: *"My take is [X]. Does that change how you see it?"* |
| Going in circles after 10+ exchanges | No actual decision to make, or decision is blocked on info we can't get | Soft exit per Step 7 — surface this and offer recap. |
| `AskUserQuestion` not available (subagent context) | Worker subagents lack the tool | Treat the invocation prompt as the entire context. Produce a single structured response: brief vault-context check + 3 hypotheses about what the user is wrestling with + the 3-5 questions you'd ask if interactive. Don't try to fake a multi-turn conversation. |
| Configuration values missing | Fresh fork | Error: *"Configuration section in root CLAUDE.md not populated. Run `/bootstrap` (TBD) or fill it in manually first."* |

## Output format

This skill produces conversation, not files (unless Step 8 saves). The expected pattern across a session:

1. Mode acknowledgment (one line)
2. *(implicit)* `/find` call for vault context
3. 3-5 clarifying questions (across multiple turns)
4. Insight checkpoints after user responses
5. Periodic synthesis (after 3-4 exchanges)
6. Exit recommendation + optional memory save

The transcript IS the artifact. If saved, the synthesis from Step 6 + the recommendation from Step 8 become the durable record.
