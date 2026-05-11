# USER.md - About Your Human

- **Name:** <user.full_name>
- **What to call them:** <user.name>
- **Timezone:** <user.timezone>
- **Language:** <user.language>
- **Email:** <user.email>
- **Company:** <user.company>

## Role

<user.role_description> — e.g., "Product Manager + AI Engineer at Acme, on the **Platform** team. Leads platform initiatives, builds internal tools, runs office hours."

## What They Need

<TBD — fill in after fork. Common patterns:>
- Morning briefings (email triage, calendar review, meeting prep, action items)
- Meeting prep with context from past conversations and transcripts
- Task prioritization using Eisenhower matrix
- Cross-referencing across systems (email + calendar + meeting notes + Slack)
- Desktop and file organization
- Writing assistance matching <user.name>'s style
- Project tracking and strategic document support

## Communication Preferences

<TBD — adjust to match <user.name>. Defaults:>
- **Direct and efficient** — no corporate fluff, get to the point
- **Detail-heavy** — wants specifics, not summaries. More detail > less detail.
- **Conversational tone** — like talking over coffee, not reading a memo
- **Actionable** — every item should have a clear next step, owner, and timeline
- **Cross-referenced** — connect the dots between emails, meetings, and calendar
- **Quantified** — always include metrics where they apply (hours saved, ROI, acceptance rates)
- **No emojis in formal docs** — OK in briefings and Slack, NEVER in formal externals (PRDs, strategic docs)

## Formatting Preferences

<TBD — adjust to match <user.name>. Defaults:>
- Visual status indicators (🟢🟡🔴) for project tracking in briefings
- Markdown tables for data comparison
- Bullets for action items, numbered lists for sequences
- Hierarchical headings for structure
- Email signature: `<user.email_signature>`

## Team & Active Collaborators

For full per-person context (role, cadence, open commitments, interaction history), see `<workspace.root>/<workspace.resources>/contacts/<slug>.md`. This section is the high-level summary; contacts/ is the source of truth.

**Same team:**
- <TBD — fill in your immediate teammates with email + role>

**Manager chain:**
- <TBD — fill in your manager + their manager>

**Execs in orbit:**
- <TBD — fill in execs you regularly interact with>

**Cross-functional collaborators:**
- <TBD — fill in cross-team partners>

**Personal contacts (filtered out of work briefings):**
- <TBD — friends, family, side-project collaborators NOT at <user.company>. Use `status: personal` in their contact files so work-context skills filter them.>

## Priority Signals

<TBD — adjust to match <user.name>. Defaults:>
- Direct collaborators and manager = HIGH
- Calendar conflicts = URGENT
- Strategic / technical topics = HIGH (current focus areas)
- Team blockers = URGENT (anyone waiting on <user.name>)
- Cost / risk anomalies = MEDIUM (monitor, escalate if significant)
- Generic updates / newsletters = LOW

## Priority Slack Channels

Channels <assistant.name> should always check in the morning briefing's Slack digest (top of digest, surface even thin signal). Non-priority channels still get caught if they have @-mentions or DMs.

<TBD — fill in your priority channels:>

**Team / domain channels:**
- `#<channel-1>`
- `#<channel-2>`

**Company-wide:**
- `#general`
- `#<location-channel>` (e.g., `#sanfrancisco`)
- `#<company-channel>` (e.g., `#acme-news`)

## Priority Jira Project Keys

<TBD — fill in if you use Jira. Examples: `ENG`, `PROD`, `<TEAM>`. Used by `/briefing`'s Jira queue section to filter `assignee = currentUser()` to your priority projects rather than dumping everything.>

## Behavioral Rules

- Never over-summarize — <user.name> wants details, not bullet-point abstractions
- Always explain WHY something matters, not just WHAT it is
- Track commitments obsessively — extract what <user.name> promised to deliver and to whom
- Flag calendar conflicts immediately
- Cross-reference everything — connect email threads to meeting notes to calendar invites
- Provide specific next actions with owners and timelines, not vague "follow up" items

## Mac Desktop Layout (PARA)

<TBD — fill in if you use a PARA layout on your Mac Desktop. This describes <user.name>'s file organization on `~/Desktop/`. It is **distinct from** the `<workspace.root>/` PARA layout — see `README.md` for that.>

```
0-Inbox/     Daily processing (screenshots, downloads, quick notes)
1-Projects/  Active projects with date prefixes (Work/Personal)
2-Coding/    Active repos
3-Content/   Content creation
4-Areas/     Ongoing responsibilities
5-Resources/ Templates, references, media
6-Archive/   Completed work by YYYY-MM
```

## Google Drive

<TBD — fill in if you use Google Drive folders for source-of-truth content:>

- **Meeting Transcripts:** Folder ID `<TBD>` (e.g., Tactiq full transcripts folder)
- **Meeting Recordings:** Folder ID `<TBD>` (e.g., Gemini AI summaries folder — prefer when available)

## Notes

<TBD — fill in with <user.name>-specific context:>

- Where they work (home / office / hybrid)
- Their org structure
- Any cross-functional partners
- Side-projects, content creation, hobbies that <assistant.name> should know about
- Anything else worth surfacing in briefings or meeting prep
