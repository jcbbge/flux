# Flux: Context & Capture Layer
## Product Requirements Document
**Version:** 1.0
**Date:** 2026-04-03
**Status:** Draft — ready for implementation planning
**Builds on:** FLUX_IAE_PRD.md (v2.0 composable workspace architecture)

---

## Problem Statement

Flux currently sources all entries from a single directory (`~/flux/Entries/`). This works for a personal journaling workflow, but Josh's actual workflow is multi-project — Infinity, Flux itself, personal, and future projects. All of these need a capture surface, but they live in different places and have different audiences.

The result: notes end up orphaned in `~/flux/Entries/` with no project context, or they don't get captured at all because friction is too high.

There's a second problem layered on top: some thoughts aren't ready to be tasks or artifacts. They're floating — half-formed, loosely related to a project, maybe becoming something real, maybe dissolving. Mesh (the work tracking system) is too rigid for this. There needs to be a pre-mesh holding space that's frictionless to write into and loosely organized by project.

---

## Goals

1. **Multi-context capture** — Flux should work across all projects without changing where you store things
2. **Per-project sink** — Each project gets a single rolling note file that everything dumps into, symlinked or watched, always current
3. **Pre-mesh holding space** — Floating ideas, open questions, and loosely related thoughts that aren't tasks yet
4. **AI summarization** — On-demand distillation of a context's notes into actionable signal
5. **Graduation path** — A held thought can become a mesh artifact with one action

---

## Non-Goals (this PRD)

- Backlink graph rendering (future — tracked in FLUX_IAE_PRD.md)
- Full Roam-style bidirectional linking UI
- Real-time collaboration
- Mobile

---

## Core Concept: Contexts

A **Context** is a named source of entries. It has a directory. Flux can switch between contexts. The global daily entry (`2026-04-03.md`) belongs to whichever context is active.

The default context is `personal` — `~/flux/Entries/`. Adding a project context points Flux at a different directory (or a symlinked file within it).

---

## Feature 1: Multi-Context Directory Support

### What it does
Allow Flux to source entries from multiple directories. The user can switch the active context from the sidebar or a menu. All Flux functionality (daily entry, new entry, sidebar list, search) operates on the active context's directory.

### Context definition
```json
{
  "contexts": [
    {
      "id": "personal",
      "label": "Personal",
      "path": "~/flux/Entries",
      "icon": "person",
      "isDefault": true
    },
    {
      "id": "infinity",
      "label": "Infinity",
      "path": "~/Infinity/flux-notes",
      "icon": "building.2",
      "color": "#4A90D9"
    },
    {
      "id": "flux",
      "label": "Flux",
      "path": "~/flux/workspace/notes",
      "icon": "bolt",
      "color": "#9B59B6"
    }
  ],
  "activeContext": "personal"
}
```

Stored in `~/flux/Config/contexts.json`.

### Behavior
- On context switch: sidebar refreshes with that directory's entries, daily entry auto-creates in that directory
- New entries land in the active context's directory
- Context switcher visible in sidebar header — label + icon, tap/click to switch
- Keyboard shortcut: `Cmd+Shift+C` to cycle contexts, or numbered (`Cmd+Ctrl+1/2/3`)
- Last active context persists across app restarts

### Context directory requirements
- Directory must exist (Flux creates it if missing on first switch)
- Any `.md` files in the directory are valid entries
- No required structure — Flux adapts to what's there

---

## Feature 2: Per-Project Flux Note (Project Sink)

### The pattern
Each project gets a single rolling markdown file — `flux-notes.md` (or `FLUX.md`) — that lives inside the project repo. This is the "sink": all captures for that project flow here.

Two implementation approaches — both valid, decision point below.

### Option A: Symlink approach
`~/flux/Entries/infinity.md` → symlinks to `~/Infinity/flux-notes.md`

Flux treats it as a regular entry. When you're in the `personal` context and open `infinity.md`, you're editing the actual file in the Infinity repo. It shows up in git history for Infinity. It's always current.

**Pros:** Dead simple. No sync logic. File lives where it belongs.
**Cons:** Symlink management is manual (or scripted). Doesn't give a dedicated context — it's just one file in the personal list.

### Option B: Context directory approach
`~/Infinity/flux-notes/` is a directory. Added as the `infinity` context in Flux. All Infinity captures go there as dated daily files. The directory lives inside the Infinity repo and is committed with it.

**Pros:** Full context isolation. Infinity notes are version-controlled with the project. Daily entry rhythm works per-project.
**Cons:** Slightly more setup per project. Notes are spread across daily files rather than one rolling document.

### Option C: Hybrid (recommended)
Both exist. The project has a `flux-notes/` directory (Option B context). It also has a `FLUX.md` rolling file that is an auto-generated summary/concatenation of recent flux-notes entries — written by the AI summarization feature (Feature 4). `FLUX.md` is the "catch up" document: an agent or human can read it to understand what's been floating in this project.

**Decision needed:** Josh to confirm preferred pattern before implementation.

### Scaffolding
A `flux init` command (or Flux app action) scaffolds a new project context:
```bash
flux init ~/Infinity
# Creates ~/Infinity/flux-notes/ directory
# Adds "infinity" context to ~/flux/Config/contexts.json
# Optionally creates ~/Infinity/FLUX.md stub
```

Can also be triggered from within the app: File → Add Project Context → select directory.

---

## Feature 3: Pre-Mesh Holding Space

### What it is
A lightweight, frictionless area within a context for thoughts that aren't tasks yet. Not a separate mode — just a convention layer on top of the daily entry system.

### The problem it solves
Mesh artifacts require a name, a phase, and intent. Many thoughts during a work session don't have that yet. They're questions, observations, half-formed ideas, related fragments. They need to live somewhere without pressure to become formal.

### Implementation: Holding entries
A **holding entry** is a regular markdown file with a `type: holding` frontmatter field. It can be created quickly (keyboard shortcut or toolbar button) and doesn't auto-create daily — it accumulates until promoted or archived.

```markdown
---
created: 2026-04-03T14:30:00
type: holding
context: infinity
tags: newco, galley
---

## floating

- What does the invoice builder UX feel like when picking from Galley?
  Unified list or tabbed by section?
- Labor rate data model — don't back into a corner with multiple rate grids
- Last-invoice discount rule — holds for simple cases, what about mid-stream negotiation?
- Does Galley have webhooks or only polling?

## questions

- [ ] Humanity API — can you read assigned vs open shift slots?
- [ ] Cherokee Dock open bar split — is the liquor/wine percentage fixed or variable?

## maybe becomes

- INFINITY-GALLEY-SYNC (if Galley has webhooks, sync architecture changes)
- INFINITY-HUMANITY-ADJUST (depends on shift state API answer)
```

### Quick capture shortcut
`Cmd+Shift+H` — opens a holding entry for the active context. If one exists for today, appends to it. If not, creates one.

### Visual treatment in sidebar
Holding entries appear with a different indicator (e.g. a soft dot or `~` prefix) so they're visually distinct from daily entries and named notes.

### Graduation
From a holding entry, a single action promotes a section to a mesh artifact:
- Select text → right-click → "Create Mesh Artifact"
- Or: dedicated button when a holding entry is open
- This runs `mesh create [GENERATED-ID] --trace "[selected text]"` in the active context's project directory
- The promoted section gets a `→ mesh: ARTIFACT-ID` annotation inline

---

## Feature 4: AI Summarization (On-Demand)

### What it does
Given the active context's recent entries, produce a distilled summary: what was captured, what's open, what's floating, what should be done next.

This is the "catch up" read — useful at the start of a session, or when handing off to another agent/developer.

### Trigger
- Toolbar button: "Summarize Context"
- Keyboard: `Cmd+Shift+S`
- Can be scoped: "Summarize today" / "Summarize this week" / "Summarize all holding entries"

### Output
Written to `FLUX.md` in the context's directory (or displayed inline in a panel — TBD). Format:

```markdown
# Infinity — Flux Summary
Generated: 2026-04-03

## What's been captured (this week)
- Humanity × HubSpot integration fully specced. Blocked on Mary (HubSpot properties) and Tay (Humanity location rename).
- Newco invoice builder architecture defined. Galley sync pattern agreed. Build not started.
- Webhook infrastructure researched — recommendation is Hetzner + Cloudflare CDN layer. Decision pending.

## Open questions (not yet tasks)
- Does Humanity API expose assigned vs open shift state?
- Does Galley have webhooks for product updates?
- Invoice builder UX: unified list or tabbed sections?
- Labor rate data model flexibility

## Mesh artifacts created this session
- INFINITY-WEBHOOK-INFRA (PLAN)
- INFINITY-HUMANITY-SHIFTS (PLAN)
- INFINITY-NEWCO-INVOICE (IDEATE)
- [+ 10 more]

## Suggested next actions
- Josh: decide webhook infra (read research/webhook-infra.md)
- Josh: provide full chart of accounts
- John: can start INFINITY-NEWCO-INVOICE and INFINITY-DISCOUNT-LOGIC now — unblocked
```

### LLMService integration
`LLMService.swift` is already stubbed. This feature wires it. The summarization call reads all `.md` files in the context directory modified in the target time range, concatenates them with filenames as headers, and sends to the LLM with a structured prompt.

---

## Feature 5: Context-Aware Daily Entry

### Current behavior
Single global daily entry: `~/flux/Entries/2026-04-03.md`. Auto-created on launch.

### New behavior
Daily entry is per-context. Switching to the `infinity` context auto-creates `~/Infinity/flux-notes/2026-04-03.md` if it doesn't exist. The daily entry rhythm continues — just scoped to wherever you're working.

### Global daily vs context daily
Two modes, user preference:
- **Global daily only:** One daily file in personal context. Project captures append to it with a context header. Simpler.
- **Per-context daily:** Each context has its own daily file. Cleaner separation, slightly more switching friction.

Default: **global daily**, with an easy opt-in to per-context mode in settings.

---

## Implementation Phases

### Phase 1: Multi-Context Foundation
**Scope:** Context switching, directory sourcing, `contexts.json` config

- [ ] `ContextManager.swift` — loads/saves `contexts.json`, manages active context
- [ ] `FluxWorkspaceManager.swift` refactor — generalize away from hardcoded `~/flux/workspace` path
- [ ] Sidebar context switcher UI — label + icon, tap to switch
- [ ] Daily entry respects active context directory
- [ ] New entry lands in active context directory
- [ ] `flux init [path]` scaffolding (CLI script or app action)

**Unblocked. Can start now.**

---

### Phase 2: Per-Project Sink
**Scope:** Symlink support OR context directory approach (decision needed first)

- [ ] Josh decides: symlink vs context directory vs hybrid
- [ ] Implement chosen approach
- [ ] Scaffold Infinity context: `~/Infinity/flux-notes/`
- [ ] Migrate today's Infinity notes into context

**Blocked on: Josh decision (Option A/B/C above)**

---

### Phase 3: Holding Space
**Scope:** Holding entry type, quick capture shortcut, sidebar visual treatment, graduation action

- [ ] `type: holding` frontmatter support in `Models.swift`
- [ ] `Cmd+Shift+H` quick capture — creates/appends holding entry for active context
- [ ] Sidebar: visual indicator for holding entries
- [ ] Graduation action: select text → "Create Mesh Artifact" → calls `mesh create`
- [ ] Inline annotation after promotion

**Unblocked. Can start after Phase 1.**

---

### Phase 4: AI Summarization
**Scope:** Wire `LLMService.swift`, on-demand context summary, write to `FLUX.md`

- [ ] Wire `LLMService.swift` to actual LLM endpoint (local or API)
- [ ] Summarization prompt: collects recent entries from active context, structured output
- [ ] Toolbar button + `Cmd+Shift+S` shortcut
- [ ] Output written to `[context-dir]/FLUX.md`
- [ ] Scope options: today / this week / all holding entries

**Depends on: Phase 1 (context directory), LLM endpoint decision**

---

## Open Questions

| Question | Owner | Urgency |
|---|---|---|
| Symlink vs context directory vs hybrid (Feature 2) | Josh | Before Phase 2 |
| Global daily vs per-context daily (Feature 5) | Josh | Before Phase 1 ships |
| LLM endpoint for summarization — local (Ollama) or API? | Josh | Before Phase 4 |
| Should `FLUX.md` be auto-generated on a schedule or only on-demand? | Josh | Before Phase 4 |
| Should mesh graduation require being in the context's project dir, or work globally? | Josh | Before Phase 3 |

---

## File Changes

| File | Change |
|---|---|
| `Flux/FluxWorkspaceManager.swift` | Refactor: generalize paths, add context switching |
| `Flux/Models.swift` | Add `holding` type to `FluxMeta.fluxType`, context field |
| `Flux/ContentView.swift` | Context switcher UI in sidebar header |
| `Flux/LLMService.swift` | Wire to actual LLM endpoint |
| `Flux/ContextManager.swift` | New file: context CRUD, `contexts.json` persistence |
| `Config/contexts.json` | New file: context registry |
| `scripts/flux-init.sh` | New: scaffold project context from CLI |

---

## Relationship to FLUX_IAE_PRD.md

This PRD is additive — it does not replace or conflict with the IAE architecture. Context support slots naturally into the Notes mode of the IAE. The holding space and AI summarization become components that can be surfaced in the Dashboard and Agent modes defined in v2.0.

Priority order relative to IAE phases:
- This PRD's Phase 1 (context switching) should run **in parallel** with IAE Phase 1 (today's entry system) — they touch the same files and should be coordinated
- This PRD's Phase 3 (holding space) aligns with IAE Phase 3 (mode system) — holding entries could become a sub-mode or panel

---

*Last updated: 2026-04-03*
