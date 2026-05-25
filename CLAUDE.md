# Flux — Agent Ground Truth
> **This is the canonical reference for AI agents working in this repo.**
> Keep this file and `CLAUDE.md` in sync. Update both after any session that changes architecture, storage, build config, or permissions.

---

## CRITICAL: Read This Before Touching Anything

### This is a fork, not the upstream

This repo (`jcbbge/flux`, branch `main`) is a **heavily customized fork** of `farzaa/freewrite`. The upstream project and this fork share almost no file paths, naming conventions, or architecture. Do not apply anything you know about the upstream without verifying it applies here.

**Upstream remote:** `https://github.com/farzaa/freewrite` (configured as `upstream`)
**There is one branch: `main`.** Past attempts to rebase upstream corrupted `ContentView.swift`. Do not rebase or cherry-pick from upstream without explicit instruction.

---

## The Actual Build

**One repo. One scheme. One binary. One machine.**

```
Repo:    /Users/jrg/flux
Scheme:  Flux
Project: Flux.xcodeproj
Binary:  /Users/jrg/Library/Developer/Xcode/DerivedData/Flux-ejkelmnfjwtqssffcbtxkaxmkmho/Build/Products/Debug/Flux.app
```

**Build command (always use this):**
```bash
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Debug build
```

This auto-deploys to `/Applications/Flux.app` via build phase. Spotlight/Finder will find it.

**Clean build:**
```bash
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Debug clean build
```

**Launch:**
```bash
open /Applications/Flux.app
```

**Verify what's running:**
```bash
pgrep -l Flux
# Then check which binary:
ps -p <PID> -o args=
```

**Incremental builds do not always pick up all changes.** When in doubt, `clean build`. The GitCommit bake script runs every build but Swift recompilation may be skipped if nothing changed — this can leave a stale binary stamped with an old hash while the code is actually current. If you're unsure what's running, check:
```bash
/usr/libexec/PlistBuddy -c "Print :GitCommit" \
  "/Users/jrg/Library/Developer/Xcode/DerivedData/Flux-ejkelmnfjwtqssffcbtxkaxmkmho/Build/Products/Debug/Flux.app/Contents/Info.plist"
```
That hash is what's actually built and running.

---

## File Storage — The #1 Trap

**Entries live here:**
```
~/flux/Entries/
```

**NOT** `~/Documents/Freewrite/` (that is the upstream location and it does not exist or is empty on this machine).

**Video assets live here:**
```
~/Documents/Freewrite/Videos/
```
(Video directory still uses the upstream path — this is a known inconsistency, not a bug to fix without instruction.)

**Backup directory:**
```
~/flux/EntriesBackup/
```

### Why entries were invisible in the app (2026-04-14 incident)

The app sandbox (`com.apple.security.app-sandbox = true` in `Flux.entitlements`) blocked reads to `~/flux/Entries/` because the macOS sandbox only grants free access to `~/Documents`, `~/Downloads`, etc. — not arbitrary subdirectories of `$HOME`.

**The fix applied:** `com.apple.security.app-sandbox` is now set to `false` in `Flux/Flux.entitlements`.

**Do not re-enable the sandbox** unless you also add the `com.apple.security.files.downloads.read-write` or equivalent entitlement that covers `~/flux/`. If you re-enable it without that, entries will silently disappear again — `loadExistingEntries()` will catch no files, create a blank welcome entry, and the user will think their data is gone.

---

## Project Structure (Actual)

```
/Users/jrg/flux/
├── Flux.xcodeproj/
│   └── project.pbxproj          # Hand-edited to add GitCommit build phase
├── Flux/
│   ├── FluxApp.swift
│   ├── ContentView.swift        # ~3300 lines. Source of truth for all UI.
│   ├── VideoRecordingView.swift # ~853 lines. From upstream, adapted.
│   ├── VideoPlayerView.swift    # ~258 lines. From upstream.
│   ├── Models.swift             # HumanEntry, EntryType, etc.
│   ├── VersionInfo.swift        # Reads GitCommit from bundle Info.plist
│   ├── Flux.entitlements        # sandbox=false
│   └── ...
├── Config/
│   └── Flux-Info.plist          # GENERATE_INFOPLIST_FILE = NO. GitCommit key present.
├── Entries/                     # User's actual journal entries (not in git)
├── EntriesBackup/               # Auto-backup of entries (not in git)
├── AGENTS.md                    # This file
└── CLAUDE.md                    # Clone of this file — keep in sync
```

**The Swift target directory is `Flux/`, not `freewrite/`.** The upstream uses `freewrite/`. This caused every cherry-pick to produce conflicts because Git couldn't match the file paths.

---

## Filename Formats

This fork uses **two** filename formats for entries. Both are valid and `loadExistingEntries()` parses both.

**New format (fork-native):**
```
yyyy-MM-dd.md              # daily entry, no UUID
yyyy-MM-dd-XXXXXXXX.md    # additional entry that day, 8-char hex suffix
```
Examples: `2026-04-14.md`, `2026-04-14-30B6679E.md`

**Old format (upstream-compatible, still present in Entries/):**
```
[UUID]-[yyyy-MM-dd-HH-mm-ss].md
```
Example: `[17A00D90-1D23-492D-9BE2-9C29B492CAEE]-[2026-02-04-20-19-27].md`

**Video entry metadata files** use the old UUID format. The corresponding video asset lives in `~/Documents/Freewrite/Videos/[base-name]/[base-name].mov`.

**README.md** exists in `~/flux/Entries/` — `loadExistingEntries()` will attempt to parse it and fail gracefully (it won't match any format and is skipped). Do not remove it without checking if anything depends on it.

---

## GitCommit Build Phase

A `PBXShellScriptBuildPhase` was manually added to `project.pbxproj` (ID `2800F7422DA1CEA0008FE5F9`). It runs after `Resources` on every build and stamps the current `git rev-parse --short HEAD` into the built app's `Info.plist` under the `GitCommit` key.

`VersionInfo.swift` reads this key from `Bundle.main.infoDictionary` and displays it in the sidebar.

**Requirements for this to work:**
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` must be set in both Flux target Debug and Release configs (it is — added 2026-04-14). Without this, `git` and `PlistBuddy` are blocked by the build sandbox.
- `GitCommit` key must exist in `Config/Flux-Info.plist` (it does — added 2026-04-14).

**Known pre-existing issue:** `VersionInfo.swift` also has a `verifyAgainstRepo()` function with a hardcoded path `/Users/jcbbge/flux` (old username). This always returns `[?]`. It is a pre-existing issue and has not been fixed.

---

## Sandbox: The Full Picture

`Flux/Flux.entitlements` currently:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```

Camera, microphone, and speech recognition entitlements are still present — they are required for AVFoundation/Speech even without the sandbox.

**If you ever see entries missing at runtime and there are no code errors**, the first thing to check is whether sandbox got re-enabled. The symptom is: files exist on disk, `loadExistingEntries()` runs, but loads 0 entries and creates a blank welcome entry instead.

---

## Upstream Integration: What Happened and What to Know

### What was integrated (2026-04-14 session)

All 7 upstream commits (`4e8446a` through `c21d71c`) adding video journaling were surgically merged into the fork's `ContentView.swift`. This was done by hand — **not** by cherry-pick or rebase — because the file path rename (`freewrite/` → `Flux/`) made automated merges produce conflicts in every file.

### Do not use rebase or cherry-pick from upstream

A full rebase was attempted early in the session. It destroyed the fork's `ContentView.swift` by mixing upstream and fork code, broke the nav layout, and lost entry loading. The branch was reset from a backup at commit `9193469`. (Historical safety backup branches have since been deleted during the 2026-05-25 consolidation — recovery would require git reflog.)

**If you need to pull future upstream changes:**
1. `git fetch upstream`
2. `git show upstream/main:<file>` to inspect individual files
3. Manually apply only the relevant diffs into the fork's files
4. Never run `git rebase upstream/main` or `git cherry-pick` on commits that touch `ContentView.swift`

### Upstream file that showed up as untracked

After cherry-pick attempts, a `freewrite/` directory appeared in the working tree containing `default.md` (the upstream welcome guide). It was removed in the 2026-04-14 session. If it reappears, just `rm -rf /Users/jrg/flux/freewrite/`.

---

## ContentView.swift

**This is the most important file in the repo. It is ~3300 lines.**

Do not let any tool, merge, or rebase overwrite it automatically. Always diff before accepting changes.

Key things this file owns that the upstream does not have:
- Lens sidebar system
- AI enrichment (Ollama / SurrealDB integration)
- `entryDictionary` for O(1) entry lookup
- Debounced saves
- Backup directory logic
- `DateFormatterCache` for performance
- Fork-native filename format (`yyyy-MM-dd.md`)
- Design token system (custom colors, spacing)
- `VersionInfoInline` component

**Line count is a rough guide only — it changes as features are added.**

---

## Models.swift

`HumanEntry` init requires `entryType` and `videoFilename` parameters (added during video integration). If you ever see a compile error like `extra argument in call` or `missing argument` on a `HumanEntry(...)` call, check that all call sites pass these two fields:
```swift
entryType: .text,
videoFilename: nil
```

---

## Build Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Entries missing at runtime | Sandbox re-enabled | Check `Flux.entitlements`, ensure `app-sandbox = false` |
| App shows old code after build | Incremental build skipped recompile | `clean build` |
| GitCommit shows `unknown` | Script sandboxed or key missing | Check `ENABLE_USER_SCRIPT_SANDBOXING = NO` in pbxproj; check `Config/Flux-Info.plist` has `GitCommit` key |
| GitCommit shows stale hash | Binary not rebuilt after commit | `clean build` then relaunch |
| `VideoRecordingView` / `VideoPlayerView` missing | Files empty or absent in `Flux/` | Restore from `git show upstream/main:freewrite/<file>` |
| Compile error on `HumanEntry(...)` | Missing `entryType`/`videoFilename` params | Add `entryType: .text, videoFilename: nil` to call site |
| Cherry-pick/rebase conflicts in ContentView | File path mismatch (`freewrite/` vs `Flux/`) | Do not use cherry-pick; apply changes manually |

---

## Auto-Deploy Build Phase

A `PBXShellScriptBuildPhase` called "Deploy to Applications" (ID `2800F7432DA1CEA1008FE5F9`) was added to `project.pbxproj`. It runs after the GitCommit phase on every build and:

1. Kills running Flux process
2. Copies built `.app` to `/Applications/Flux.app`
3. Registers with LaunchServices

This ensures Spotlight/Finder always finds the current build. No manual deployment needed.

---

## Upstream Sync

**NEVER rebase or cherry-pick.** Use the sync script:

```bash
./scripts/sync-upstream.sh
```

This fetches upstream, shows what changed, and provides diff commands for manual review. ContentView.swift should NEVER be auto-merged — it has fork-specific code throughout.

See `RUNBOOK.md` for complete step-by-step instructions.

---

## Session Log

### 2026-04-14

**What was done:**
- Integrated upstream video feature (7 commits) into fork by hand
- Added `upstream` remote pointing to `farzaa/freewrite`
- Created safety backup branch at `9193469` (later deleted in 2026-05-25 consolidation)
- Survived a failed rebase (reset back to backup)
- Added `PBXShellScriptBuildPhase` to bake `GitCommit` into `Info.plist` at build time
- Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` on Flux target
- **Disabled app sandbox** (`app-sandbox = false`) to fix entries being invisible
- Removed stray `freewrite/` directory from working tree

**What went wrong:**
- Assumed sandbox was not a problem — it was the entire reason entries were missing
- Spent time on red herrings (wrong binary, stale binary) before identifying sandbox as root cause
- The AGENTS.md/CLAUDE.md in this repo described the upstream project, not the fork — all paths, structures, and storage locations in those docs were wrong for this machine

**Current HEAD:** `0b3b181`
**Branch:** `main` (at the time of this session, the working branch was named `m5-updates`; later consolidated to `main` on 2026-05-25)
**Status:** Build succeeds, entries load, video feature integrated, GitCommit baked in

### 2026-04-24

**What was done:**
- Added "Deploy to Applications" build phase — auto-copies built app to `/Applications/Flux.app` on every build
- Created `RUNBOOK.md` — complete who/what/where/when/why/how documentation
- Created `scripts/sync-upstream.sh` — interactive upstream sync helper
- Fixed Spotlight issue — symlinks don't work, must copy actual .app bundle

**Root cause of "missing video updates":**
- `/Applications/Flux.app` was a stale copy from a previous manual install
- Spotlight was launching that instead of the DerivedData build
- Build was fine, source was fine, fork was fine — wrong binary was running

**Current HEAD:** `9a04c4c`
**Branch:** `main` (at the time of this session, the working branch was named `m5-updates`; later consolidated to `main` on 2026-05-25)
**Status:** Build auto-deploys to /Applications, Spotlight works, upstream sync documented

### 2026-05-25

**What was done:**
- **Branch consolidation.** Collapsed `m5-updates`, `backup-20260419`, and `backup/m5-updates-pre-rebase` into a single `main` branch.
- `main` now points at `4d06cea` (the tip of `backup-20260419`), which is the working state with video integration, auto-deploy, and GitCommit baking.
- Deleted local branches: `m5-updates`, `backup-20260419`, `backup/m5-updates-pre-rebase`.
- Deleted remote branches: `origin/m5-updates`, `origin/backup-20260419`.
- Force-pushed `main` to `origin/main` (the previous `origin/main` history — which contained a divergent ContentView refactor — is no longer on the remote).
- Updated `AGENTS.md`, `CLAUDE.md`, `RUNBOOK.md`, `scripts/sync-upstream.sh` to reference `main` everywhere.

**Why:**
- Only one user, only one machine, never distributed, never PRed upstream. Multiple branches were a remnant of the rebase recovery and added zero value.

**Current HEAD after consolidation:** `4d06cea` (plus this docs commit on top)
**Branch:** `main` — the only branch. There are no others. Do not create any.
**Status:** Build still auto-deploys to /Applications. Video feature still works. Nothing about the running app changed.
