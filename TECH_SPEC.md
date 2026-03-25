# Flux Technical Specification

**Project:** Flux - Integrated Agentic Environment (IAE)  
**Repository:** `/Users/jcbbge/flux`  
**Last Updated:** 2026-03-24  
**Version:** 2.0 (Evolution from minimal notes app to IAE)

---

## Executive Summary

Flux began as a minimal distraction-free writing environment for macOS and has evolved into a personal **Integrated Agentic Environment (IAE)** — a workspace shell designed to serve as an exocortex for knowledge work, journaling, and AI-assisted development.

The application implements a composable 4-slot component architecture (Main, Header, Sidebar, Status) with 5 distinct modes (Dashboard, Notes, Tasks, DevHub, Agent), though currently only Notes mode is fully implemented.

---

## Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Language** | Swift | 5.0 |
| **UI Framework** | SwiftUI | macOS 14.0+ |
| **Platform** | macOS | Deployment Target 14.0 |
| **Bundle ID** | app.humansongs.flux | - |
| **Build System** | Xcode + Make | xcodebuild 15+ |
| **Storage** | File System (Markdown) | YAML frontmatter |
| **Fonts** | Lato (Custom TTF) | Regular, Light, Bold variants |

### External Dependencies

- **None** — Pure Swift/SwiftUI implementation
- Standard Apple frameworks only:
  - `SwiftUI` (UI layer)
  - `AppKit` (Window management, file dialogs)
  - `Foundation` (File I/O, Date formatting)
  - `PDFKit` (Export to PDF)
  - `UniformTypeIdentifiers` (File type handling)

---

## Repository Structure

```
flux/
├── 📁 Flux/                          # Main application source
│   ├── 📄 ContentView.swift          # Main UI (2700+ lines, monolithic)
│   ├── 📄 FluxApp.swift              # App entry point, window config
│   ├── 📄 Models.swift                 # FluxEntry, FluxMeta, DataStore
│   ├── 📄 VersionInfo.swift          # Git commit verification UI
│   ├── 📄 LLMService.swift           # (Stub) LLM integration
│   ├── 📄 FluxCategorizerService.swift # (Stub) Entry categorization
│   ├── 📄 FluxProvider.swift         # (Stub) Provider pattern
│   ├── 📄 FluxWorkspaceManager.swift # Workspace discovery
│   ├── 📄 default.md                 # Template for new entries
│   └── 📁 fonts/                     # Lato font files (9 TTF)
│
├── 📁 FluxTests/                     # Unit tests (minimal)
├── 📁 FluxUITests/                   # UI tests (minimal)
├── 📁 Config/
│   └── 📄 Flux-Info.plist            # Bundle configuration
│
├── 📁 Entries/                       # User data storage
│   ├── 📄 2026-03-24.md              # Today's entry (auto-created)
│   ├── 📄 2026-03-24-XXXX.md         # Regular entries
│   └── 📄 [UUID]-[timestamp].md      # Legacy format entries
│
├── 📁 workspace/                     # Development workspace
│   ├── 📄 handoff-latest.md          # Session handoff protocol
│   ├── 📄 WORKSPACE.md               # Workspace conventions
│   └── 📁 notes/, sessions/, templates/ # Org documents
│
├── 📁 Flux.xcodeproj/                # Xcode project
├── 📄 Makefile                       # Build automation
├── 📄 AGENTS.md                      # Agent build protocol (CRITICAL)
├── 📄 BUILD.md                       # Build documentation
├── 📄 README.md                      # Project overview
├── 📄 FLUX_IAE_PRD.md                # IAE architecture PRD
└── 📄 .gitignore
```

---

## Architecture

### Core Architecture Pattern

Flux uses a **monolithic SwiftUI View + Observable Data Store** pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI View Layer                        │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              ContentView (2700+ lines)             │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌───────────┐ │  │
│  │  │   Header    │  │     Main     │  │  Sidebar  │ │  │
│  │  │  (empty)    │  │   (Editor)   │  │ (Entries) │ │  │
│  │  └─────────────┘  └──────────────┘  └───────────┘ │  │
│  │  ┌───────────────────────────────────────────────┐ │  │
│  │  │              Status Bar (Timer/Controls)       │ │  │
│  │  └───────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ @Published
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  FluxDataStore (@MainActor)                │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │   entries    │  │ entryDictionary│  │     projects    │ │
│  │ [HumanEntry] │  │  [UUID:Entry]  │  │    [Project]    │ │
│  └──────────────┘  └──────────────┘  └─────────────────┘ │
│  ┌──────────────┐                                           │
│  │    todos     │  File I/O via FileManager                │
│  │ [TodoItem]   │  ──────────────────────────────► ~/flux   │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

### Lens/Mode System (Partially Implemented)

```
┌────────────────────────────────────────────────────────────┐
│                    5-Mode Architecture                      │
│                    (Only Notes Implemented)                 │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Dashboard  │  │    Notes    │  │    Tasks    │         │
│  │   (Cmd+1)   │  │   (Cmd+2)   │  │   (Cmd+3)   │         │
│  │  ────────   │  │  ────────   │  │  ────────   │         │
│  │  NOT IMPL   │  │  ✓ ACTIVE   │  │  Sidebar✓   │         │
│  │             │  │  Editor✓   │  │  Main View✗ │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐                          │
│  │   DevHub    │  │    Agent    │                          │
│  │   (Cmd+4)   │  │   (Cmd+5)   │                          │
│  │  ────────   │  │  ────────   │                          │
│  │  NOT IMPL   │  │  NOT IMPL   │                          │
│  └─────────────┘  └─────────────┘                          │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### Data Flow

```mermaid
flowchart TD
    A[User Input] --> B[TextEditor Binding]
    B --> C{Validate Prefix}
    C -->|Has \n\n| D[Store in @State text]
    C -->|Missing| E[Add Prefix]
    E --> D
    D --> F[Auto-save Timer]
    F --> G[Save to File]
    G --> H[~/flux/Entries/YYYY-MM-DD.md]
    
    I[File System] --> J[FluxDataStore]
    J --> K[@Published entries]
    K --> L[Sidebar List]
    
    M[Git Commit] --> N[Makefile embed]
    N --> O[Info.plist GitCommit]
    O --> P[VersionInfo Bar]
```

---

## Key Components

### 1. ContentView (The Monolith)

**Location:** `Flux/ContentView.swift`  
**Lines:** ~2700  
**Responsibilities:**
- Main UI layout (Header, Main, Sidebar, Status)
- TextEditor with custom font/size binding
- Entry list sidebar (Notes, Projects, Todos lenses)
- Search functionality (Cmd+K)
- File I/O (Save/Load/Delete)
- Keyboard shortcuts (Cmd+1-5 for modes)
- Timer functionality
- PDF Export
- Font selection UI

**State Variables (Key):**
```swift
@State private var text: String                    // Editor content
@State private var entries: [HumanEntry]          // Sidebar entries
@State private var selectedFont: String = "Lato-Regular"
@State private var fontSize: CGFloat = 18
@State private var currentLens: LensMode = .notes
@State private var isSearchMode: Bool = false
```

### 2. FluxDataStore

**Location:** `Flux/Models.swift`  
**Pattern:** Singleton ObservableObject
**Responsibilities:**
- Central data management
- File monitoring (2-second polling)
- Entry loading/parsing
- Frontmatter extraction

### 3. File Format

**Entry Files:** `~/flux/Entries/YYYY-MM-DD-XXXXXXXX.md`

```markdown
---
fluxTitle: ""
fluxType: "journal"
category: ""
summary: ""
tags: []
links: []
insights: []
---

First line of content (Title)
Second line of content (Subtitle)
...
```

### 4. Models

**HumanEntry:**
```swift
struct HumanEntry: Identifiable {
    let id: UUID
    let date: String        // Display date ("Mar 24")
    let filename: String    // "2026-03-24-XXXX.md"
    var previewText: String // First ~30 chars of content
}
```

**FluxMeta:**
```swift
struct FluxMeta: Codable {
    let fluxTitle: String?
    let fluxType: String
    let category: String?
    let summary: String?
    let tags: [String]
    let links: [UUID]
    let insights: [String]
    let embedding: [Float]?
}
```

---

## Build System

### Makefile Targets

| Target | Purpose |
|--------|---------|
| `make build` | Build Release, embed commit, sign |
| `make install` | Build + install to /Applications |
| `make run` | Launch installed app |
| `make dev` | Build + run from build dir (no install) |
| `make clean` | Delete build output |
| `make verify` | Check commit match [✓] [X] [?] |

### Build Pipeline

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Clean     │───▶│   Build     │───▶│Embed Commit │
│  (Optional) │    │  xcodebuild │    │  git→plist  │
└─────────────┘    └─────────────┘    └─────────────┘
                                            │
                                            ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Launch    │◀───│   Install   │◀───│    Sign     │
│  /Apps/Flux │    │   cp -R     │    │ codesign -s-│
└─────────────┘    └─────────────┘    └─────────────┘
```

### Git Commit Verification

The app displays build status in sidebar:
- `[✓]` — Build matches repo HEAD
- `[X]` — Stale build (uncommitted changes)
- `[?]` — No commit embedded

**Critical Rule:** Always commit before building. See `AGENTS.md`.

---

## Patterns & Conventions

### 1. Monolithic View Pattern

The entire UI lives in `ContentView.swift`. This is intentional for a personal tool where:
- Refactoring overhead exceeds value
- Single file = single mental model
- Direct manipulation over abstraction

**Tradeoffs:**
- ✓ Fast iteration, no navigation between files
- ✗ 2700+ lines, cognitive load for changes
- ✗ Brace-matching errors cascade

### 2. File-First Data Persistence

No Core Data, no SQLite. Plain markdown files:
- Human-readable, future-proof
- Git-versioned if desired
- Frontmatter for metadata
- Directory polling for "real-time" sync

### 3. @State over ViewModel

For a personal tool, `@State` in the View is sufficient:
- No business logic complexity requiring separation
- Direct binding reduces boilerplate
- SwiftUI's reactive model handles updates

### 4. Prefix Enforcement Pattern

All entries prefixed with `\n\n` to position cursor below invisible header:
```swift
set: { newValue in
    if !newValue.hasPrefix("\n\n") && newValue.count > text.count - 3 {
        text = newValue  // Allow deletion at start
    } else if !newValue.hasPrefix("\n\n") {
        text = "\n\n" + newValue.trimmingCharacters(in: .newlines)
    } else {
        text = newValue
    }
}
```

---

## Statistics

| Metric | Value |
|--------|-------|
| **Total Commits** | 89 |
| **Swift LOC** | ~3,659 |
| **Files in Flux/** | 37 |
| **Main View LOC** | ~2,700 |
| **Models LOC** | ~318 |
| **AppDelegate LOC** | ~49 |
| **Build Time** | ~30 seconds |

---

## Known Issues & Technical Debt

### High Priority

1. **ContentView.swift is too large**
   - Every edit risks brace-mismatch cascade errors
   - No component separation
   - No preview provider for sub-views

2. **Cursor Jump on Delete at Start**
   - Fixed in commit `27149d2` with intelligent prefix handling
   - Still fragile — depends on character count heuristic

3. **Unused Variables in lensHeaderView**
   - `textColor` and `todayString` computed but not displayed
   - Warnings persist (benign)

### Medium Priority

4. **Lens System Partially Implemented**
   - Only Notes mode functional
   - Dashboard, Tasks, DevHub, Agent modes are stubs
   - Sidebar switches but main view doesn't

5. **No Error Handling for File I/O**
   - Silent failures on read/write
   - No user feedback for permission issues

### Low Priority

6. **Test Coverage Minimal**
   - FluxTests and FluxUITests are stubs
   - No automated testing of core flows

---

## Development Guidelines

### Critical: AGENTS.md Protocol

Before ANY build:

```bash
make clean        # ALWAYS clean old builds first!
git add -A
git commit -m "type: description"
make install      # Builds + verifies + installs
make verify       # Check [✓] in sidebar
```

**Violations cause:**
- Stale builds showing `[X]`
- App crashes from unsigned binaries
- Confusion about what code is running

### Swift Editing Safety

After ANY edit to `ContentView.swift`:

```bash
# Check for brace errors immediately
xcrun swiftc -typecheck Flux/ContentView.swift 2>&1 | head -5

# If errors, run depth checker
python3 -c "
with open('Flux/ContentView.swift') as f:
    lines = f.readlines()
depth = 0
for i, line in enumerate(lines, 1):
    prev = depth
    for ch in line:
        if ch == '{': depth += 1
        elif ch == '}': depth -= 1
    if depth < 0:
        print(f'NEGATIVE at line {i}')
        break
print(f'Final depth: {depth}')
"
```

---

## Roadmap (From FLUX_IAE_PRD.md)

### Phase 1: Foundation (Current - Partially Complete)
- [x] Today's entry auto-creation
- [x] Fix frontmatter display
- [x] State machine structure
- [x] Config persistence
- [ ] Metadata panel (attempted, reverted)

### Phase 2: Layout System
- [ ] 4-slot component architecture
- [ ] Movable sidebar (left/right)
- [ ] Movable header/status (top/bottom)
- [ ] Layout settings UI

### Phase 3: Mode System
- [ ] Dashboard mode
- [ ] Tasks mode
- [ ] DevHub mode
- [ ] Agent mode
- [ ] Pinning system (Cmd+Shift+1-5)

### Phase 4: Intelligence
- [ ] LLM integration (LLMService.swift exists, stub)
- [ ] Auto-categorization (FluxCategorizerService.swift, stub)
- [ ] Semantic search
- [ ] Entry linking

---

## External Integrations

### MCP (Model Context Protocol)
The workspace/ directory contains MCP integration notes:
- Subagent delegation patterns
- Skill/primitive system design
- Anima/Dev-Brain/KotaDB integration (external infrastructure)

**Note:** Flux itself has NO direct MCP dependencies. It's a standalone macOS app.

---

## Skills Needed for Further Development

Based on this codebase, to effectively work on Flux you need:

1. **SwiftUI macOS Development**
   - Window management (`windowStyle`, `defaultSize`)
   - Keyboard event handling (`NSEvent.addLocalMonitor`)
   - Custom font loading (`CTFontManagerRegisterFontsForURL`)

2. **Swift Language (5.0)**
   - Property wrappers (`@State`, `@Binding`, `@AppStorage`)
   - Result builders (ViewBuilder)
   - Actors (`@MainActor`)

3. **File System & I/O**
   - `FileManager` APIs
   - `URL` manipulation
   - File monitoring strategies

4. **Xcode Build System**
   - `xcodebuild` CLI
   - Code signing (`codesign`)
   - Info.plist manipulation

5. **Markdown/YAML Parsing**
   - Frontmatter extraction
   - Lightweight parsing (no external libs)

---

## Resources

- **Build Protocol:** `AGENTS.md` (CRITICAL READ)
- **Architecture PRD:** `FLUX_IAE_PRD.md`
- **Build Docs:** `BUILD.md`
- **Workspace Conventions:** `workspace/WORKSPACE.md`

---

**End of Specification**

*Generated: 2026-03-24*  
*Commits Analyzed: 89*  
*Lines of Code: ~3,659*
