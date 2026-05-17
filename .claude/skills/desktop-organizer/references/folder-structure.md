# Recommended Folder Structure

**Research Date:** 2025-11-16
**Based on:** PARA method + Developer best practices + AI/LLM-friendly organization

---

## RESEARCH-BACKED BEST PRACTICES

### Content Creator Structure (YouTube/Reels/Shorts)
**Per-Video Organization:**
- Each video = one folder with ALL related files
- Structure: `Video-Title/` contains footage, audio, script, thumbnails, B-roll, final export
- Archive by month: `2025-11/`, `2025-10/`
- Reuse assets across videos from shared library

### Date-Based Systems
**When dates work best:**
- Recurring work (weekly reports, monthly reviews)
- Chronological projects
- File naming: `YYYY-MM-DD-description` for auto-sorting
- Archive structure: Year → Month → Week (if high volume)

### Developer Best Practices
**Active vs Archive:**
- Active folder = Currently working on (max 5-10 items)
- Archive by year = Completed/inactive projects
- Templates = Reusable boilerplates separate from active work

---

## REVISED RECOMMENDED STRUCTURE (Based on Research + Your Needs)

**Key Principles:**
1. Per-project folders contain ALL related files (content creators best practice)
2. Date-based archiving (YYYY-MM format for scalability)
3. Active folders limited to current work (prevents overwhelm)
4. No clients - personal projects only
5. AI-friendly semantics and consistent depth

## RECOMMENDED STRUCTURE (Optimized for AI Agents + Content Creators)

```
~/Desktop/
│
├── 0-Inbox/                              # Daily processing zone
│   ├── Screenshots/                      # Last 7 days (auto-process)
│   ├── Downloads/                        # Symlink to ~/Downloads
│   └── Quick-Notes/                      # Brain dumps
│
├── 1-Projects/                           # Active personal projects
│   ├── 2025-11-BMAD-Agent-System/       # Date prefix for sorting
│   ├── 2025-10-Mac-Setup-YouTube/
│   ├── 2025-09-Personal-Website/
│   └── [Each project folder contains ALL related files]
│
├── 2-Coding/                             # Development work
│   ├── Active/                           # Current repos (5-10 max)
│   │   ├── 2025-11-second-brain-os/
│   │   ├── 2025-11-example-assistant/
│   │   ├── 2025-10-mcp-server-x/
│   │   └── [Date prefix shows when started]
│   ├── Learning/                         # Tutorials, experiments
│   │   ├── 2025-cursor-claude-course/
│   │   └── 2025-nextjs-tutorial/
│   ├── Templates/                        # Boilerplates (no dates)
│   │   ├── mcp-server-template/
│   │   ├── nextjs-starter/
│   │   └── python-cli-template/
│   └── Archive/                          # Inactive projects by date
│       ├── 2025/
│       │   ├── 2025-09-project-a/
│       │   └── 2025-08-project-b/
│       └── 2024/
│           └── 2024-XX-old-projects/
│
├── 3-Content/                            # Content creation
│   ├── Active/                           # Current videos (max 5-10)
│   │   ├── 2025-11-17-Mac-Setup-Agentic/
│   │   │   ├── Script.md
│   │   │   ├── Footage/
│   │   │   │   ├── A-Roll/
│   │   │   │   └── B-Roll/
│   │   │   ├── Audio/
│   │   │   │   ├── Voiceover.m4a
│   │   │   │   └── Music/
│   │   │   ├── Graphics/
│   │   │   │   ├── Thumbnail.png
│   │   │   │   └── Overlays/
│   │   │   ├── Exports/
│   │   │   │   ├── YouTube-Full.mp4
│   │   │   │   ├── Reels-Clip-1.mp4
│   │   │   │   └── Shorts-Clip-2.mp4
│   │   │   └── Project-Files/
│   │   │       └── Final-Cut-Pro-Project/
│   │   └── 2025-11-15-AI-Agents-Demo/
│   │       └── [Same structure per video]
│   ├── Ideas/                            # Future video concepts
│   │   └── idea-backlog.md
│   ├── Assets/                           # Reusable across videos
│   │   ├── Intro-Outro/
│   │   ├── Music-Library/
│   │   ├── Stock-Footage/
│   │   └── Branding/
│   └── Published/                        # Archive by month
│       ├── 2025-11/
│       │   └── 2025-11-10-First-Video/
│       ├── 2025-10/
│       └── 2025-09/
│
├── 4-Areas/                              # Ongoing responsibilities (dated)
│   ├── Health/
│   │   └── 2025-Workout-Plans/
│   ├── Learning/
│   │   ├── 2025-AI-Research/
│   │   └── 2024-React-Study/
│   └── Personal-Systems/
│       └── 2025-Productivity-Setup/
│
├── 5-Resources/                          # Reference (mostly undated)
│   ├── Templates/
│   │   ├── Doc-Templates/
│   │   ├── Code-Templates/
│   │   └── Video-Templates/
│   ├── References/
│   │   ├── Books-PDFs/
│   │   ├── Research-Papers/
│   │   └── Articles/
│   ├── Media/
│   │   ├── Screenshots/              # Organized by purpose
│   │   │   ├── Bug-Reports/
│   │   │   ├── Design-Inspo/
│   │   │   ├── Tutorials/
│   │   │   └── Archive/
│   │   │       ├── 2025-11/
│   │   │       └── 2025-10/
│   │   └── Stock-Assets/
│   └── Tools-Utilities/
│       ├── Scripts/
│       └── MCP-Servers/
│
└── 6-Archive/                            # Completed (all by date)
    ├── Projects/
    │   ├── 2025/
    │   │   ├── 2025-11-project-name/
    │   │   └── 2025-10-another-project/
    │   └── 2024/
    ├── Coding/
    │   ├── 2025/
    │   └── 2024/
    └── Content/
        ├── 2025/
        └── 2024/
```

---

---

## KEY IMPROVEMENTS FROM RESEARCH

### 1. Date Prefixes (YYYY-MM-DD or YYYY-MM)
**Best Practice from Research:**
- Files auto-sort chronologically
- AI can determine age instantly
- Easy to find recent work
- Format: `2025-11-17-Project-Name/`

**Applied to:**
- ✅ Active projects: `1-Projects/2025-11-BMAD/`
- ✅ Active coding: `2-Coding/Active/2025-11-second-brain-os/`
- ✅ Content videos: `3-Content/Active/2025-11-17-Mac-Setup/`
- ✅ Archive: Auto-organized by YYYY-MM

**NOT applied to:**
- ❌ Templates (timeless, reusable)
- ❌ Resources (reference materials)
- ❌ Permanent utilities

### 2. Per-Project ALL-FILES Principle (Content Creator Best Practice)
**Each video project folder contains EVERYTHING:**
```
2025-11-17-Mac-Setup-Video/
├── Script.md                    # The script
├── Footage/
│   ├── A-Roll/                  # Main footage
│   └── B-Roll/                  # Supporting clips
├── Audio/
│   ├── Voiceover.m4a
│   └── Music/
├── Graphics/
│   ├── Thumbnail.png
│   └── Overlays/
├── Exports/
│   ├── YouTube-Full.mp4         # Main export
│   ├── Reels-Clip-1.mp4         # Repurposed for Instagram
│   ├── Shorts-Clip-2.mp4        # Repurposed for YouTube Shorts
│   └── Twitter-Clip.mp4
└── Project-Files/
    └── [Editor project files]
```

**Benefits:**
- Everything for one video in one place
- Easy to archive when published
- Reels/Shorts exports live WITH the source video
- AI can gather complete context for any video

### 3. Active Folder Limits (Prevent Overwhelm)
**Research shows:**
- Active folders should have 5-10 items MAX
- Anything inactive → Archive immediately
- Keeps cognitive load low
- AI agents can scan Active folders quickly

**Applied:**
- `2-Coding/Active/` = Only current repos (not all 51!)
- `3-Content/Active/` = Only videos in production
- Everything else → Archive by date

### 4. Shared Assets Library (Content Creator Standard)
**Reusable elements separate from projects:**
- Intro/Outro animations
- Music library
- Stock footage
- Branding assets

**Location:** `3-Content/Assets/`

### 5. Archive by YYYY-MM (Scalability)
**Scales infinitely:**
- `6-Archive/Content/2025-11/`
- `6-Archive/Content/2025-10/`
- Can drill down to weeks if needed

---

## WHY THIS STRUCTURE WORKS

### 1. AI/LLM-Friendly Design

**Clear Semantic Hierarchy:**
- Number prefixes = explicit priority/order
- Descriptive names = LLM can infer purpose without context
- Consistent nesting depth = predictable navigation

**Machine-Readable Patterns:**
```
Active work: 1-Projects/, 2-Coding/Active/
Reference: 5-Resources/
Completed: 6-Archive/
Temporary: 0-Inbox/
```

**Agent Can Easily:**
- Determine file destination by analyzing content
- Search across categories ("Find all work related to Client-A")
- Auto-archive by date/completion status
- Categorize by project vs area vs resource

---

### 2. Scalability Features

**Prevents Clutter:**
- `0-Inbox` = Everything lands here first, gets processed daily
- `Active` folders = Limited to current work (max 10-15 items)
- `Archive` by year = Old stuff doesn't pollute active folders
- Screenshots organized by project/date (not flat 1,372 files!)

**Grows With You:**
- Add new projects without restructuring
- Archive old projects by year (clean history)
- Coding/Active holds only current work (rest archived)
- Easy to add new Areas/Resources without chaos

**Number Limits by Folder:**
- 1-Projects/Work: Max 5-10 active projects
- 2-Coding/Active: Max 5-10 active repos
- 0-Inbox: Process to zero daily
- Everything else → Archive or Resources

---

### 3. PARA Compliance (Modified for Developers)

**Standard PARA:**
- P = Projects
- A = Areas
- R = Resources
- A = Archive

**Enhanced PARA (this skill's variant):**
- 0 = Inbox (added - GTD best practice)
- 1 = Projects
- 2 = Coding (Projects split by type)
- 3 = Content (Projects split by type)
- 4 = Areas
- 5 = Resources
- 6 = Archive

**Why the split:**
- You're a developer AND content creator
- Coding projects have different workflows than business projects
- Content creation has unique asset management needs
- Keeps related work together (all code in one place, all content in another)

---

### 4. Research-Backed Best Practices

**From PARA Creator (Tiago Forte):**
- ✅ Number prefixes for consistent sorting
- ✅ Start with Inbox, process to appropriate folders
- ✅ Weekly reviews to maintain system
- ✅ Archive aggressively (if not active, it goes to Archive)
- ✅ Never create empty folders (only create when you have content)

**From Developer Community:**
- ✅ ~/Developer or ~/Code for all development work
- ✅ Active vs Archive separation (prevents 51-project chaos)
- ✅ Templates folder for boilerplates
- ✅ Date-based archiving (2025/, 2024/)

**From AI File Organizers (LlamaFS, etc):**
- ✅ Semantic naming (AI can infer purpose)
- ✅ Consistent depth (2-3 levels max for most items)
- ✅ Date-based organization for time-sensitive items
- ✅ Content-based categorization (AI analyzes file content)

---

## MIGRATION PLAN (From Current → Recommended)

### Phase 1: Create Structure
```bash
# Create new numbered structure
mkdir -p ~/Desktop/0-Inbox/{Screenshots,Downloads,Quick-Capture}
mkdir -p ~/Desktop/1-Projects/{Work,Personal,Side-Projects}
mkdir -p ~/Desktop/2-Coding/{Active,Experimental,Templates,Archive/2025}
mkdir -p ~/Desktop/3-Content/{Videos/{In-Progress,Published,B-Roll},Scripts,Thumbnails,Assets}
mkdir -p ~/Desktop/4-Areas
mkdir -p ~/Desktop/5-Resources/{Templates/{Docs,Code,Design},References,Media,Utilities}
mkdir -p ~/Desktop/6-Archive/{Projects,Content,Coding}
```

### Phase 2: Migrate Existing Folders
```bash
# Map current → new structure:

Current: "1. Projects"          → New: "1-Projects/"
Current: "2. Areas"             → New: "4-Areas/"
Current: "3. Resources"         → New: "5-Resources/"
Current: "4. Coding Projects"   → New: "2-Coding/" (split Active vs Archive)
Current: "4.Archive"            → New: "6-Archive/"
Current: "5. Content Creation"  → New: "3-Content/"
Current: "5. Screenshot"        → New: "5-Resources/Media/Screenshots/" (organized!)
```

### Phase 3: Organize Files
- Loose Desktop files → 0-Inbox (then process)
- Downloads → 0-Inbox/Downloads (symlink for auto-processing)
- Active coding (5-10 projects) → 2-Coding/Active/
- Old coding (40+ projects) → 2-Coding/Archive/2024/ or 2-Coding/Archive/2025/
- Screenshots → Organize by date/project

---

## AI AGENT ORGANIZATION RULES

When <assistant.name> organizes files, it will use these rules:

### File Type → Destination Logic

**Code Files (.js, .py, .ts, .ipynb, etc):**
- Active project? → 2-Coding/Active/[project-name]/
- Old/completed? → 2-Coding/Archive/[year]/
- Template/snippet? → 2-Coding/Templates/

**Documents (.pdf, .docx, .md):**
- Work-related with deadline? → 1-Projects/Work/[project]/
- Reference/research? → 5-Resources/References/
- Completed? → 6-Archive/Projects/[year]/

**Media (.mp4, .m4a, .mov):**
- Video content? → 3-Content/Videos/
- Meeting recording? → 1-Projects/[project]/meetings/ or 6-Archive/
- Audio note? → 0-Inbox/ (process later)

**Images (.png, .jpg, .gif):**
- Screenshot? → 5-Resources/Media/Screenshots/[date]/
- Design asset? → 3-Content/Assets/
- Reference image? → 5-Resources/Media/Images/

**Data Files (.csv, .xlsx, .json):**
- Active analysis? → 1-Projects/[project]/data/
- Reference data? → 5-Resources/References/
- Archive? → 6-Archive/

**Temp/Junk (.zip, .dmg, old installers):**
- Delete if older than 30 days (with confirmation)
- Keep if recent → 0-Inbox/

### Date-Based Auto-Archive

**Files older than:**
- 90 days in 0-Inbox → Move to appropriate Archive/[year]/
- 180 days in 2-Coding/Active → Prompt to archive
- 365 days in Screenshots → Auto-archive by year

### Project Detection Logic

**AI analyzes filename/content for project context:**
- "client-proposal.pdf" → Extract "client" → Move to 1-Projects/Work/Client/
- "react-tutorial.md" → Detect learning content → Move to 1-Projects/Personal/Learning/
- "meeting-notes-2025-11-16.md" → Detect meeting → Move to appropriate project
- "screenshot-slack-bug.png" → Detect project context → Move to relevant project folder

---

## BENEFITS FOR AI AGENTS

### Why This Structure is LLM-Optimized:

1. **Explicit Hierarchy** - Numbers show priority (0=temporary, 1=highest priority, 6=lowest)
2. **Semantic Names** - LLM understands "Projects" vs "Archive" without training
3. **Consistent Depth** - Most files 2-3 levels deep (easy to reference)
4. **Clear Boundaries** - Active vs Archive split prevents confusion
5. **Date-Based Logic** - Temporal organization aids decision-making
6. **Content-Type Separation** - Code/Content/Docs each have dedicated space

### Agent Can Answer:

- "Where should this file go?" → Analyzes content, determines category
- "What's actively being worked on?" → Scans 1-Projects, 2-Coding/Active, 3-Content/In-Progress
- "What can I archive?" → Checks file dates, project completion status
- "Find all work for Client-A" → Searches 1-Projects/Work/Client-A + related Archives

---

## MAINTENANCE AUTOMATION

<assistant.name> can maintain this structure via:

**Daily (via desktop-organizer workflow):**
- Process 0-Inbox to appropriate folders
- Move Downloads to Inbox
- Organize new screenshots

**Weekly:**
- Review Active folders (suggest archiving completed items)
- Clean up duplicates
- Archive old screenshots (>30 days)

**Monthly:**
- Archive inactive coding projects
- Review Areas for completed items
- Clean up Resources (remove unused)

---

## RECOMMENDATION FOR SID:

**Best Structure:** Use the recommended structure above because:

✅ **Scalable** - Inbox prevents Desktop chaos, Archive by year scales indefinitely
✅ **AI-Friendly** - Clear semantics, consistent patterns, explicit hierarchy
✅ **Developer-Optimized** - Coding gets its own top-level category with Active/Archive split
✅ **Content Creator-Friendly** - Content work separated with proper asset management
✅ **PARA-Compliant** - Respects PARA principles but enhanced for your specific needs
✅ **Maintainable** - <assistant.name> can automate daily/weekly maintenance

**Key Improvements Over Current:**
- ❌ No duplicate numbering (4 and 5 appear twice in current structure)
- ✅ Inbox system (everything lands somewhere, gets processed)
- ✅ Active/Archive split (51 coding projects → 5-10 active, rest archived)
- ✅ Screenshot organization (1,372 files → organized by date/project)
- ✅ Clear hierarchy (AI agents can navigate confidently)

---

**Next Step:** Should we create the desktop-organizer workflow to IMPLEMENT and MAINTAIN this structure?
