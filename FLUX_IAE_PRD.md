# Flux: Integrated Agentic Environment (IAE)

## Product Requirements Document
**Version:** 2.0 — Composable Workspace Architecture  
**Date:** 2026-03-11  
**Status:** Ready for Implementation

---

## Executive Summary

Flux evolves from a simple note-taking app into a **composable workspace shell** — an Integrated Agentic Environment (IAE). The UI consists of four hot-swappable component slots (Main, Header, Sidebar, Status) that can display content from five distinct modes: Dashboard, Notes, Tasks, DevHub, and Agent.

**Core Philosophy:** Minimal, clean, functional. No animations, no flashy graphics. Simple state machine for modes and components.

---

## Architecture Overview

### 4-Slot Component System

```
┌─────────────────────────────────────────┐ ← HEADER (top/bottom)
│  [Configurable Component View]          │
├──────────────────┬──────────────────────┤
│                  │                      │
│   MAIN VIEW      │     SIDEBAR          │
│   (always        │     (left/right)     │
│   follows mode)  │                      │
│                  │                      │
│                  │                      │
├──────────────────┴──────────────────────┤
│  [Configurable Component View]          │ ← STATUS (top/bottom)
└─────────────────────────────────────────┘
```

**Layout Rules:**
- Header always renders **above** Status bar
- Sidebar can be left or right
- Status bar can be top or bottom
- All positions configurable via settings

### 5 Modes

| Mode | Key | Description | Main View | Sidebar | Status | Header |
|------|-----|-------------|-----------|---------|--------|--------|
| **Dashboard** | Cmd+1 | Widget view of all modes | Dashboard grid | Widget list | System stats | Today indicator |
| **Notes** | Cmd+2 | Default note-taking | Note editor | Entry list | Word count | Breadcrumbs |
| **Tasks** | Cmd+3 | Todo management | Task board | Task list | Task stats | Filter bar |
| **DevHub** | Cmd+4 | Dev tools status | Server status | Tool list | Health metrics | Connection status |
| **Agent** | Cmd+5 | Agent orchestration | Project overview | Agent list | Metrics | Command input |

---

## Component Behavior & Pinning System

### Global Mode Switching (Cmd+1-5)

**Rule:** The Main View **always** follows the global mode. Header, Sidebar, and Status follow global mode **unless pinned**.

### Pinning/Bookmarking

Components can be "pinned" to a specific mode, making them ignore global mode changes.

**Pinning Behavior:**
- Unpinned component: Follows global mode automatically
- Pinned component: Stays locked to its pinned mode regardless of global mode

**Example State:**
```
Global Mode: Notes (Cmd+2)

Component States:
- Main: Notes (always follows global)
- Header: Notes (unpinned, follows)
- Sidebar: Pinned to Tasks (stays on Tasks sidebar)
- Status: Pinned to Agent (stays on Agent status)

Result View:
┌─────────────────────────────────────────┐
│  [Notes Breadcrumbs]                    │ ← Header: Notes
├──────────────────┬──────────────────────┤
│                  │                      │
│   Note Editor    │     Task List        │
│   (Today's file) │     (from Tasks)     │
│                  │                      │
├──────────────────┴──────────────────────┤
│  [Agent Metrics: 5 active, 3 idle]      │ ← Status: Agent
└─────────────────────────────────────────┘
```

### Reset (Cmd+Shift+R)

**Function:** Unpins all components and sets them to follow current global mode.

**Result:** All 4 slots display the same mode (unified view).

---

## Today's Entry System

### Daily File Auto-Creation

**Behavior:**
- On app launch: Check for `Entries/YYYY-MM-DD.md`
- If missing: Auto-create with frontmatter
- If exists: Load it immediately
- Same file loaded regardless of time (1am or 9pm)

**File Format:**
```markdown
---
date: 2026-03-11
type: daily
created: 2026-03-11T08:30:00Z
---

# 2026-03-11

[cursor positioned here]
```

**Today Button:**
- Always visible in Header or Status
- Click returns to today's file
- Keyboard shortcut: Cmd+T (proposed)

### New Entry

**Behavior Unchanged:**
- Creates separate markdown file with hash: `YYYY-MM-DD-XXXXXXXX.md`
- Does not affect today's file
- Appears in sidebar entry list
- Can be accessed normally

---

## State Management

### Configuration File

**Location:** `Entries/.flux/config.json`

**Structure:**
```json
{
  "version": "2.0",
  "startup": {
    "defaultMode": "notes"
  },
  "layout": {
    "sidebarPosition": "right",
    "headerPosition": "top",
    "statusPosition": "bottom"
  },
  "pins": {
    "header": null,
    "sidebar": "tasks",
    "status": "agent"
  },
  "lastSession": {
    "globalMode": "notes",
    "selectedEntry": "2026-03-11.md"
  }
}
```

### State Machine

```
GlobalMode enum:
  - dashboard (1)
  - notes (2) [default]
  - tasks (3)
  - devhub (4)
  - agent (5)

ComponentState per slot:
  - mode: GlobalMode
  - pinned: boolean
  - pinnedTo: GlobalMode | null

On Global Mode Change:
  For each component slot:
    If pinned:
      Keep current mode
    Else:
      Switch to new global mode

On Reset (Cmd+Shift+R):
  For each component slot:
    pinned = false
    pinnedTo = null
    mode = current global mode
```

---

## Keyboard Shortcuts

### Mode Switching
| Shortcut | Action |
|----------|--------|
| Cmd+1 | Switch to Dashboard mode |
| Cmd+2 | Switch to Notes mode (default) |
| Cmd+3 | Switch to Tasks mode |
| Cmd+4 | Switch to DevHub mode |
| Cmd+5 | Switch to Agent mode |
| Cmd+Shift+R | Reset all views to unified mode |

### Navigation
| Shortcut | Action |
|----------|--------|
| Cmd+[ or Cmd+Shift+Tab | Focus previous component slot |
| Cmd+] or Cmd+Tab | Focus next component slot |
| Cmd+Shift+1-5 | Pin focused component to mode 1-5 |
| Cmd+T | Jump to Today's entry |
| Cmd+N | Create new entry |

### Layout (Future)
| Shortcut | Action |
|----------|--------|
| Cmd+Opt+S | Toggle sidebar left/right |
| Cmd+Opt+H | Toggle header top/bottom |
| Cmd+Opt+B | Toggle status bar top/bottom |

---

## Visual Design

### Aesthetic Principles
- **Minimal:** No gradients, no shadows (except subtle depth)
- **Clean:** Generous whitespace, clear hierarchy
- **Modern:** System fonts, native macOS styling
- **Functional:** Every element serves a purpose

### Pinned Indicator
- Subtle badge/icon in corner of pinned component
- Or: Slightly different border/background shade
- Must match current Flux aesthetic (monochrome/gray tones)

### Color Palette
- Primary: System default (follows macOS light/dark)
- Accent: Gray-500 equivalent
- Background: White/light gray (light mode), Dark gray (dark mode)
- Text: System standard

---

## Implementation Phases

### Phase 1: Foundation (Immediate)

**Goals:**
1. Implement Today's entry auto-creation
2. Fix frontmatter display bug in sidebar
3. Add basic state machine structure
4. Add `.flux/config.json` persistence

**Files to Modify:**
- `Flux/ContentView.swift` — Add state machine, mode switching
- `Flux/Models/HumanEntry.swift` — Add today's file creation
- `Flux/SidebarView.swift` — Fix frontmatter display
- `Flux/ConfigManager.swift` — New file for persistence

**Deliverables:**
- [ ] App loads today's file on startup
- [ ] New entry creates separate file
- [ ] Today button returns to today
- [ ] Config file saves/loads correctly

### Phase 2: Layout System

**Goals:**
1. Add 4-slot component architecture
2. Implement layout positioning (sidebar left/right, header/status top/bottom)
3. Add keyboard shortcuts for layout
4. Settings UI for layout preferences

**Deliverables:**
- [ ] Header component slot
- [ ] Main view component slot
- [ ] Sidebar component slot (movable)
- [ ] Status bar component slot (movable)
- [ ] Layout settings UI

### Phase 3: Mode System

**Goals:**
1. Implement 5 modes with basic components
2. Add mode switching (Cmd+1-5)
3. Add pinning system (Cmd+Shift+1-5)
4. Add reset functionality (Cmd+Shift+R)

**Deliverables:**
- [ ] Dashboard mode with widgets
- [ ] Notes mode (current functionality)
- [ ] Tasks mode with todo list
- [ ] DevHub mode with server status
- [ ] Agent mode with project overview
- [ ] Pinning/bookmarking system
- [ ] Reset functionality

### Phase 4: Advanced Features (Future)

- SurrealDB integration for Tasks mode
- Agent orchestration interface
- Custom widgets for Dashboard
- Plugin system for custom modes

---

## Bug Fixes Required

### Frontmatter Display Bug
**Issue:** YAML frontmatter appears in sidebar entry list  
**Fix:** Parse and hide frontmatter, only display content after `---` block

**Location:** `Flux/SidebarView.swift`, entry title extraction logic

---

## Data Models

### Config Models

```swift
enum GlobalMode: String, Codable, CaseIterable {
    case dashboard = "dashboard"
    case notes = "notes"
    case tasks = "tasks"
    case devhub = "devhub"
    case agent = "agent"
    
    var displayName: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .notes: return "Notes"
        case .tasks: return "Tasks"
        case .devhub: return "DevHub"
        case .agent: return "Agent"
        }
    }
    
    var shortcutKey: Int {
        switch self {
        case .dashboard: return 1
        case .notes: return 2
        case .tasks: return 3
        case .devhub: return 4
        case .agent: return 5
        }
    }
}

struct ComponentState: Codable {
    var mode: GlobalMode
    var isPinned: Bool
    var pinnedTo: GlobalMode?
}

struct LayoutConfig: Codable {
    var sidebarPosition: SidebarPosition
    var headerPosition: BarPosition
    var statusPosition: BarPosition
    
    enum SidebarPosition: String, Codable {
        case left, right
    }
    
    enum BarPosition: String, Codable {
        case top, bottom
    }
}

struct FluxConfig: Codable {
    var version: String
    var startup: StartupConfig
    var layout: LayoutConfig
    var pins: [String: GlobalMode?] // slot name -> pinned mode
    var lastSession: LastSession?
}
```

### Today's Entry

```swift
struct TodayEntry {
    static func fileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date)).md"
    }
    
    static func createIfNeeded(in directory: URL) -> URL {
        let fileURL = directory.appendingPathComponent(fileName())
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let content = """
            ---
            date: \(dateString)
            type: daily
            created: \(ISO8601DateFormatter().string(from: Date()))
            ---
            
            # \(dateString)
            
            
            """
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        return fileURL
    }
}
```

---

## Acceptance Criteria

### Phase 1 Complete When:
- [ ] Opening app loads today's file automatically
- [ ] Today's file created with correct frontmatter if missing
- [ ] "New Entry" creates separate file (not today's)
- [ ] "Today" button returns to today's file
- [ ] Sidebar does not show frontmatter in entry list
- [ ] Config saves to `.flux/config.json`

### Phase 2 Complete When:
- [ ] 4 component slots render correctly
- [ ] Sidebar can be toggled left/right
- [ ] Header can be toggled top/bottom
- [ ] Status bar can be toggled top/bottom
- [ ] Layout preferences persist

### Phase 3 Complete When:
- [ ] Cmd+1-5 switches global mode
- [ ] Main view always follows global mode
- [ ] Header/Sidebar/Status can be pinned
- [ ] Pinned components stay on their mode
- [ ] Cmd+Shift+R resets all components
- [ ] Visual indicator shows pinned state

---

## Open Questions for Future

1. **SurrealDB Integration:** Should Tasks mode read from database or markdown files?
2. **Agent Mode:** What specific metrics and controls needed?
3. **DevHub:** Which servers/tools to monitor initially?
4. **Dashboard:** What widgets are essential for MVP?

---

## Appendix: Current Flux Architecture

**Key Files:**
- `Flux/ContentView.swift` (~2400 lines) — Main UI
- `Flux/Models/HumanEntry.swift` — Entry model
- `Flux/SidebarView.swift` — Sidebar implementation
- `Flux/VersionInfo.swift` — Status bar component

**Current Entry Format:**
- Files: `YYYY-MM-DD-XXXXXXXX.md` (8-char hash)
- Frontmatter: `title`, `date`, `tags`

---

**Document Status:** Ready for implementation  
**Next Action:** Begin Phase 1 — Today's entry system
