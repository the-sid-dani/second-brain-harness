---
name: desktop-organizer
description: This skill should be used when the user wants to organize their Desktop, Downloads, Screenshots, or Coding Projects using the PARA framework with a numbered folder structure (0-Inbox through 6-Archive). Triggers on phrases like "organize my desktop", "mac cleanup", "clean up downloads", "organize screenshots", "para organize", or "file organization".
---

# Desktop Organizer

## Overview

Organize files using an enhanced PARA system with numbered folders (0-6) and date-based archiving. Uses filesystem MCP for all operations with user confirmation before any file moves.

**Folder Structure:**
```
~/Desktop/
├── 0-Inbox/          # Daily processing zone (Screenshots, Downloads, Quick-Notes)
├── 1-Projects/       # Active projects with YYYY-MM- prefix
├── 2-Coding/         # Development (Active/Learning/Templates/Archive)
├── 3-Content/        # Video creation (Active/Ideas/Assets/Published)
├── 4-Areas/          # Ongoing responsibilities
├── 5-Resources/      # Reference materials (Templates/References/Media/Tools)
└── 6-Archive/        # Completed work by YYYY/YYYY-MM
```

**Reference:** Load `references/folder-structure.md` for the complete structure guide with all subfolder details.

## Workflow

Execute steps in order. Each step requires user confirmation before file operations.

### Step 1: Create Folder Structure (First Run Only)

Check if the numbered folder structure exists at `~/Desktop`.

If structure doesn't exist, ask user to confirm creation:
```
I'll create the optimized folder structure:
- 0-Inbox/ (daily processing)
- 1-Projects/ (active projects)
- 2-Coding/ (development with Active/Archive split)
- 3-Content/ (video creation)
- 4-Areas/ (ongoing responsibilities)
- 5-Resources/ (reference materials)
- 6-Archive/ (completed items by date)

Create this structure now? [y/n]
```

If approved, use filesystem MCP `create_directory` to create all folders and subfolders as defined in `references/folder-structure.md`.

### Step 2: Organize Desktop Loose Files

1. Use filesystem MCP `list_directory` to scan `~/Desktop`
2. Identify all loose files (not in folders)
3. Use `get_file_info` to get metadata (type, size, dates)
4. Categorize each file:

**File Type Destinations:**
| Type | Destination Logic |
|------|-------------------|
| PDFs | Work docs → `1-Projects/YYYY-MM-project/`, Travel/personal → `6-Archive/Projects/YYYY-MM/`, Reference → `5-Resources/References/` |
| Videos/Audio (.mp4, .mov, .m4a) | Content creation → `3-Content/Active/`, Screen recordings → `5-Resources/Media/`, Meeting recordings → Related project |
| Images (.png, .jpg, .gif) | Screenshots → `0-Inbox/Screenshots/`, Design assets → `3-Content/Assets/`, Reference → `5-Resources/Media/` |
| Code/Data (.ipynb, .json, .csv, .xlsx) | Active work → `2-Coding/Active/project-name/`, Archive → `6-Archive/Coding/YYYY-MM/` |
| Archives (.zip, .dmg) | Recent (<30 days) → `0-Inbox/`, Old → Suggest delete |

5. Show organization plan and ask: `Execute Desktop cleanup? [y/n/review]`
6. If approved, execute moves using filesystem MCP `move_file`

### Step 3: Clean Up Downloads

1. Scan `~/Downloads` with filesystem MCP
2. Apply age-based rules:
   - Files >90 days AND <10MB → Suggest delete
   - Files >180 days → Suggest archive or delete
3. Apply type-based rules:
   - Code files → `2-Coding/Learning/` or Archive
   - Documents → `1-Projects/` or `5-Resources/`
   - Installers (.dmg, .pkg) → Delete if old
4. Show summary with space to be freed
5. Ask: `Clean up Downloads folder? [y/n/review]`

### Step 4: Organize Screenshots

1. Scan `~/Desktop/5. Screenshot` (or existing screenshot location)
2. Group by YYYY-MM based on file creation date
3. Show plan: `Found X screenshots. Organize into monthly folders?`
4. If approved:
   - Create monthly folders in `5-Resources/Media/Screenshots/Archive/YYYY-MM/`
   - Move screenshots to appropriate folders
   - Keep only last 30 days in `0-Inbox/Screenshots/`

### Step 5: Reorganize Coding Projects

1. Scan existing coding projects folder
2. Analyze activity by last modified date:
   - Modified <7 days → ACTIVE
   - Modified 7-30 days → RECENT
   - Modified >30 days → INACTIVE
3. Show categorization and ask: `Organize coding projects? [y/n/review]`
4. Allow manual override: "Select active project numbers (comma-separated)"
5. If approved:
   - Add YYYY-MM prefix to folder names during move
   - Active → `2-Coding/Active/`
   - Learning/tutorial → `2-Coding/Learning/`
   - Inactive → `2-Coding/Archive/YYYY/`

### Step 6: Migrate Old PARA Folders (If Applicable)

Check for existing folders that need migration:
```
"1. Projects"        → 1-Projects/
"2. Areas"           → 4-Areas/
"3. Resources"       → 5-Resources/
"4.Archive"          → 6-Archive/
"5. Content Creation" → 3-Content/
```

If found, show migration plan and ask for confirmation before moving contents.

### Step 7: Present Complete Plan

Before executing any multi-step operation, compile and present:
- Files to move (count and destinations)
- Files to delete (with confirmation)
- Space to be freed
- Estimated time

Ask: `Review complete plan above. Ready to execute? [y/n/adjust]`

### Step 8: Execute and Report

After user approval:
1. Execute all file operations
2. Track results (moved, deleted, created, errors)
3. Generate organization report
4. Save report to `~/Desktop/docs/organization-reports/desktop-org-{date}.md`
5. Show completion summary

## Path Configuration

| Path | Location |
|------|----------|
| Desktop | `~/Desktop` |
| Downloads | `~/Downloads` |
| Screenshots | `~/Desktop/5. Screenshot` |
| Coding Projects | `~/Desktop/4. Coding Projects` |
| Output Reports | `~/Desktop/docs/organization-reports/` |

## MCP Dependencies

- **filesystem** - Required for all file operations (list_directory, get_file_info, move_file, create_directory)

## Error Handling

- If filesystem MCP unavailable: Report error, cannot proceed
- If folder creation fails: Report error, suggest manual creation
- If file move fails: Skip that file, log error, continue with others
- If user cancels mid-process: Stop immediately, report what was completed

## Maintenance Mode

For subsequent runs after initial setup:
- Skip Step 1 (structure exists)
- Focus on Steps 2-4 (organize new files)
- Quick mode: Just move new Inbox items to appropriate folders
