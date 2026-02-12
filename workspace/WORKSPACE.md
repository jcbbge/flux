Flux Workspace

Purpose
- Catchall metacognitive layer for planning, AI collaboration, and dev ops
- Not repo src code; this is your scratchpad + operating system
- Simple taxonomy, low friction, fast search, stable naming

Structure
- /workspace/notes/     Napkin, scratchpad, conversations, decisions
- /workspace/research/  Findings, links, experiments, competitor notes
- /workspace/metrics/   Logs, instrumentation, success criteria, observations
- /workspace/prds/      Feature and bug PRDs (small or large)
- /workspace/templates/ Minimal templates for each directory
- /workspace/NEXT_STEPS.md  Session handoff protocol (no sessions dir)

Principles (Flux Space)
- All MD notes live under /workspace (flat or project-subdir)
- No contrived hierarchy; only real project subdirs if needed
- YAML frontmatter for AI enrichment (invisible to humans)
- Filenames use timestamp for uniqueness and time sorting
- Monitor performance; buckle if scans exceed 2s for 1k+ files
- Metrics/logs: high-level only (1-2 line summaries for sessions/commits; no deep analysis)
- Example: git log --oneline -5 for recent activity in reports
- Reports are high-level roll-ups (phase/next/issues/stagnation)

Filename convention
- year-mm-dd-HH-mm-ss-[project-slug?].md
- Timestamp for uniqueness/sorting in local scale; no UUID (dirs provide filtration)
- Collision rare; append -N if same second
- Examples:
  - /workspace/notes/2026-02-10-12-00-00.md
  - /workspace/research/my-project/2026-02-10-12-00-00-auth.md

Frontmatter convention (template)
Always include fluxTitle/type/category/summary/tags/links/insights for AI enrichment.
fluxTitle is human-readable (AI summarizes if empty; fallback first body line).
Scaffolding adds stubs to new/existing MDs non-destructively (insert if missing --- block).
---
fluxTitle: "UI Frustration Rant"
fluxType: journal
category: "Reflection"
summary: "Vent on hacked fork limits"
tags: [ui, dev, hacked]
links: [uuid-task-abc123, uuid-prd-def456]
insights: ["Link to similar in /workspace/research/"]
---

Title logic
- UI uses fluxTitle; if missing, use first non-empty line in body
- System uses filename slug for uniqueness and glob-friendly search

NEXT_STEPS.md protocol
- Update at end of work session
- Keep it short: what changed, what matters next, and why
- Git history is your timeline; no /sessions dir
- Reports include recent commits: git log --oneline -5 for high-level overview

Alignment (must stay true)
- /workspace conventions defined in this doc
- Flux app note system naming + frontmatter conventions
- /skills session ending uses NEXT_STEPS.md protocol
- Flux command center: Path-add /workspace/ to UserDefaults for readonly scoping/reports
- AI generates high-level fluxReport-yyyy-mm-dd.md in /flux/workspace/[slug]/
- Roll-up: recent session/commits (git log --oneline -5), recent MD summaries, logs overview (filenames/mods)
- No deep dives; follow timestamp naming and YAML stubs for synergy
- Alert on add: "Scaffold detected—add project?"

Templates
- /workspace/templates contains minimal stubs
- Copy into the target dir and rename to a timestamp filename

Scaffolding
- Use /spacely/scaffold-workspace.sh from a project root