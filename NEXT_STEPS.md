# Next Steps: Flux UX Redesign

**Updated:** 2026-02-13 11:30
**Branch:** main
**Commit:** f087e5d

## Current State

Filename convention `YYYY-MM-DD-XXXXXXXX.md` implemented and working. Frontmatter auto-generates. Basic features exist (search, todos, projects) but UX is broken and unusable per user feedback. Need complete redesign of interaction patterns.

## Critical UX Issues (Priority Order)

### 1. Cmd+K Search Toggle (P0 - Broken)
**Problem:** Search opens with Cmd+K but doesn't toggle. Escape doesn't close it.
**Required Behavior:**
- Cmd+K = Toggle search (open if closed, close if open)
- Escape = Close search
- Standard modern UX pattern

**Files to modify:**
- `Flux/ContentView.swift` - `NSEvent.addLocalMonitorForEvents` block around line 818
- Look for `keyCode == 40` (K key) and `keyCode == 53` (Escape)

### 2. Todo Sidebar Interaction (P0 - Unusable)
**Problem:** Clicking todo checkbox opens the note instead of completing todo.
**Required Behavior:**
- Checkbox click = Complete/uncomplete todo (toggle `@done` tag)
- Text click = Open note
- Only show outstanding (not done) todos in sidebar
- Completed todos: either strikethrough/gray, sort to bottom, or remove

**Implementation notes:**
- `extractTodos()` at line 1800 parses `@todo` and `@done`
- Sidebar todo rendering around line 1380-1440
- Need to add tap handler for checkbox vs text

### 3. Lens/View System (P1 - Architecture)
**Problem:** Sidebar cluttered with projects + todos + notes all mixed.
**Required Behavior - Three distinct lenses:**

**Notes Lens (Current):**
- Sidebar shows all entries
- Main area shows selected entry
- No changes needed to current behavior

**Projects Lens:**
- Sidebar shows project list
- Click project = show its files in sidebar
- Click file = load in main area
- +/- buttons to add/remove projects from view

**Todos Lens:**
- Sidebar shows aggregated outstanding todos
- Each todo shows source entry
- Click todo = open entry at todo line
- Checkbox completes todo

**Implementation approach:**
- Add view mode state: `@State private var currentLens: LensMode = .notes`
- Enum: `enum LensMode { case notes, projects, todos }`
- Sidebar content switches based on `currentLens`
- Top bar or sidebar header has lens selector

### 4. Project Management (P1)
**Required:**
- Add project button (discover new project)
- Remove project from view (not delete, just unlist)
- Dedicated NEXT_STEPS.md per project or aggregate view

**Files:**
- `discoverProjects()` at line 457
- Project sidebar section around line 1312

## What Was Verified Working Today

| Feature | Status |
|---------|--------|
| Filename format `YYYY-MM-DD-XXXXXXXX.md` | ✅ Working |
| Frontmatter auto-generation | ✅ Working |
| Old format backward compatibility | ✅ Working |
| `.trash/` soft-delete mechanism | ✅ Code exists |
| Todo parsing (`@todo`, `@done`) | ✅ Code exists |
| Full-text search implementation | ✅ Code exists |
| Project discovery | ✅ Code exists |

## Key Files

- `Flux/ContentView.swift` - Main implementation (2400 lines)
- `HumanEntry.createNew()` - Line 41-63 (filename generation)
- `loadExistingEntries()` - Line 299+ (dual format support)
- `extractTodos()` - Line 1800+ (todo parsing)
- `performSearch()` - Line 1728+ (search)
- `deleteEntry()` - Line 1999+ (trash)

## Blockers/Decisions Needed

1. **Lens UI design:** Where does lens selector go? Top bar? Sidebar header? Tabs?
2. **Todo aggregation:** Real-time extract on every save, or cached? Performance vs freshness.
3. **Project persistence:** Which projects show in Projects Lens? All discovered, or user-selected subset?
4. **Checkbox implementation:** SwiftUI checkbox in sidebar list item - custom component needed.

## Next Session Should Start With

Decide on lens UI approach, then implement Cmd+K toggle fix (simplest win).
