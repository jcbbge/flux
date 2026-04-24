# WORK — Flux
Updated: 2026-04-24
Phase: Implement

---

## PROJECT

Status: Fork maintained, video feature integrated, build automation complete
Next milestone: Feature parity with upstream as needed

---

## ACTIVE

- [ ] None — clean slate

---

## BLOCKED

None

---

## BACKLOG

- [ ] Fix VersionInfo.swift hardcoded path `/Users/jcbbge/flux` [Flux/]
- [ ] Consider moving video assets from `~/Documents/Freewrite/Videos/` to `~/flux/Videos/` for consistency

---

## DONE

- [x] Auto-deploy build phase — copies .app to /Applications on every build — 2026-04-24
- [x] RUNBOOK.md — complete who/what/where/when/why/how documentation — 2026-04-24
- [x] sync-upstream.sh — interactive upstream sync helper — 2026-04-24
- [x] Fix Spotlight not finding app (stale /Applications/Flux.app) — 2026-04-24
- [x] Integrate upstream video feature (7 commits) — 2026-04-14
- [x] GitCommit build phase — bake hash into Info.plist — 2026-04-14
- [x] Disable app sandbox — fix entries invisible — 2026-04-14
