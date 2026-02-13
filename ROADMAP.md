# Flux Roadmap

**Living document** — Updated 2026-02-12  
**Purpose:** Command center for metacognitive planning and orchestration of all projects

---

## Core Identity

Flux is **not** a journaling app. Flux is:
- **Your exocortex** — External cognitive model for thinking
- **Command center** — Single interface to all projects and workspaces
- **Capture system** — Inbox for ideas, snippets, inspiration from anywhere
- **Daily driver** — The first thing you open, the thing that keeps you grounded

### Design Principles (from AGENTS.md)
1. **Minimal text-only UI** — No emojis, no decorative elements
2. **No file extensions shown** — Clean entry list
3. **Defer expensive operations** — Use `onAppear`, not view body
4. **AI operates invisibly** — Enrichment happens, doesn't interrupt
5. **Time-based, not hierarchical** — Chronological organization is natural

---

## Current State

- Native macOS app, production-ready
- Clean writing interface with debounced auto-save (2s)
- 17+ entries created (actively being used)
- Build verification in sidebar (`[-]` / `[✓]`)
- Zero compiler warnings
- Single-command build system (`make install`)

---

## P0: AI Enrichment Layer (ACTIVE DEVELOPMENT)

**Job-to-be-Done:** "I want to capture thoughts without mental overhead of organization, so I can focus on thinking, not filing."

### 0.1 Automatic Metadata Generation
- **YAML frontmatter injection** on save
- Fields: `created`, `modified`, `tags`, `summary`, `related`, `project`
- Uses local Ollama (privacy-first, no cloud)
- Happens in background, doesn't block save

### 0.2 Smart Tagging
- Extract `@todo`, `@decision`, `@idea`, `@question` inline
- Auto-generate semantic tags based on content
- Tag confidence scoring (user confirms/denies)
- Tag display in sidebar filter

### 0.3 Backlink Detection
- Parse `[[note-name]]` wikilinks
- Auto-create bidirectional links
- Show "Linked References" in sidebar
- Suggest links for unlinked mentions

### 0.4 Related Entry Discovery
- Semantic similarity via local embeddings
- Temporal clustering (same day/week entries)
- Shared tag overlap
- Display "Related" section in sidebar

### 0.5 Entry Summarization
- One-line summary for each entry
- Auto-generated on save
- Display in entry list (replace 30-char preview)
- User can edit/override

---

## P1: Daily Note & Capture System

**Job-to-be-Done:** "I want a single daily entry point for all my thoughts, so I don't lose track of what I'm working on."

### 1.1 Daily Note as Entry Point
- [x] **COMPLETE** — On app launch: open today's note (create if doesn't exist)
- Filename: `YYYY-MM-DD.md`
- Template with sections: ## Morning, ## Work, ## Notes, ## Evening
- All quick captures go here by default

### 1.2 Global Quick Capture Hotkey
- `Cmd+Shift+J` from anywhere → append to today's note
- Even if app closed: opens, appends, saves, can close
- Cursor positioned at end of note
- **STATUS:** Removed — needs proper PRD and spec. See Archive.

### 1.3 Inbox Pipeline
- Dedicated `Inbox/` directory
- Sources: Twitter, blogs, clipboard captures, quick thoughts
- Slash command `/process` to review and route inbox items
- Route to: projects, daily note, archive, or delete

### 1.4 Clipboard Capture Service
- Optional background service
- `Cmd+Shift+Option+V` → capture clipboard to inbox
- Timestamp + source URL (if available)
- Process later via `/process` command

---

## P2: Command Center — Project Integration

**Job-to-be-Done:** "I want to see all my projects at a glance, so I can re-orient quickly after time away."

### 2.1 Project Directory Discovery
- Configurable root: `~/` (default)
- Auto-discover directories with `.git` or `workspace/` folder
- Manual add/remove projects in preferences

### 2.2 Project Cards in Sidebar
- Each project = card in dedicated "Projects" section
- Shows: project name, last modified, unread status
- Click → expand to show project details

### 2.3 NEXT_STEPS.md Integration
- Symlink or direct read of `workspace/NEXT_STEPS.md`
- Click project card → load NEXT_STEPS.md in main view
- Edit directly, saves to original location
- Real-time sync between Flux and project

### 2.4 Project Status Overview
- Aggregate view of all projects
- Indicators: active, stale (no updates in 7 days), blocked
- Quick filter: "Show active only", "Show stale"
- Count of open todos per project (extracted from NEXT_STEPS)

### 2.5 Sply Integration
- Recognize `workspace/` directories created by Sply script
- Sply projects get special treatment in UI
- Direct link to Sply documentation/process

---

## P3: Discovery & Navigation

### 3.1 Full-Text Search
- `Cmd+Shift+F` or `/` in sidebar
- Search content, not just filenames
- Results show: title, summary, matching snippet
- Real-time as you type

### 3.2 Tag-Based Filtering
- Sidebar filter: click tag → show entries with that tag
- Multi-select: `@todo AND @work`
- Recent tags shown at top

### 3.3 Temporal Navigation
- Calendar view (minimal) for browsing by date
- "This week", "Last week", "This month" quick filters
- Jump to specific date

### 3.4 Graph View (Lightweight)
- Optional view mode: entries as nodes, links as edges
- Filter by: all links, backlinks only, unlinked
- Click node → jump to entry
- Keep writing interface primary

---

## P4: Action & Follow-Through

### 4.1 Todo Extraction
- Auto-detect lines starting with `- [ ]` or `@todo`
- Aggregate todos across all entries
- Sidebar section: "Todos" showing count + list
- Click todo → jump to entry

### 4.2 Decision Log
- Auto-detect `@decision` tagged content
- Decision log view: chronological decisions
- Link decisions to projects

### 4.3 Pin/Favorite Entries
- Star important entries
- "Pinned" section at top of sidebar
- Syncs via metadata

### 4.4 Entry Deletion
- `Cmd+Delete` or right-click → move to trash
- Trash folder with 30-day retention
- Permanent delete from trash only

---

## P5: QOL Polish

### 5.1 Sorting Options
- Newest first, oldest first, recently edited
- Remember preference per view

### 5.2 Word Count & Stats
- Current entry word count (status bar)
- Optional: daily word count
- Minimal text-only style

### 5.3 Export
- Single entry → PDF, Markdown

### 5.4 Preferences
- AI enrichment on/off
- Daily note template customization
- Hotkey customization
- Project root directory
- Ollama endpoint config

---

## Archive: Explicitly NOT Flux

### Removed: Global Quick Capture Hotkey
- `Cmd+Shift+J` system-wide hotkey
- **Why Removed:** Failed 3 implementation attempts. Requires macOS accessibility permissions, global event monitoring, proper window management. Needs full PRD covering: accessibility permission flow, conflict detection with other apps, secure input handling, app-not-running behavior.
- **When:** Revisit after core features stable. Needs dedicated research spike.

### Rejected: ZigZag Multi-Dimensional Structures
- Multi-parent hierarchies
- Complex dimensional navigation
- **Why:** Time-based organization is natural for capture. Adding dimensions creates cognitive overhead.

### Rejected: Reasoning Traces as First-Class Objects
- Editable AI reasoning
- Reasoning versioning
- **Why:** Heavy overhead. Flux is about *your* thoughts, not managing AI cognition.

### Rejected: Web-Based Architecture
- Browser-based interface
- Backend services
- PostgreSQL + Vector DB
- **Why:** Native macOS app with local AI (Ollama) is right scope. No backend complexity.

### Rejected: Collaboration Features
- Shared notes
- Comments
- Real-time collaboration
- **Why:** Single-player tool. Collaboration adds massive complexity for marginal value.

### Rejected: Progressive Disclosure UI
- Features that reveal based on usage
- Adaptive interface
- **Why:** Unpredictable. User should know what the app does.

---

## Technical Decisions

### AI: Local Ollama Only
- No cloud services
- Privacy-preserving
- Configurable model (default: llama3.2)
- Async background processing

### Storage: Filesystem-First
- Markdown files in `~/Documents/Flux/`
- Git-friendly
- No proprietary format
- Easy to migrate/backup

### Project Integration: Symlinks/Reads
- Don't copy project files
- Read directly from `workspace/NEXT_STEPS.md`
- Edits write back to original
- No sync logic needed

---

## Success Metrics

- **Daily usage:** Open Flux at least once per day
- **Capture velocity:** <5 seconds from thought to captured
- **Context resumption:** <30 seconds to re-orient to any project
- **Zero manual tagging:** AI handles 90%+ of metadata
- **No orphaned notes:** Every entry has at least one connection

---

## Next Steps

1. **P0.1** — Basic YAML frontmatter generation (created, modified, tags)
2. **P1.1** — Daily note entry point (✅ COMPLETE)
3. **P0.5** — Entry summarization (visible improvement to entry list)
4. **P2.1 + P2.3** — Project discovery + NEXT_STEPS integration (command center)

**Current Status:** Daily note + frontmatter working. Next: Ollama integration for summarization OR project workspace integration.

---

## How to Use This Document

- **Living list** — add, remove, reorder as priorities shift
- **Check off** items when complete
- **Move to Archive** anything rejected (with reasoning)
- **Reference before sessions** to orient
- **Link to entries** using `[[ROADMAP]]` for project context

