# Flux Runbook
> **Everything you need to build, update, and run this fork.**
> Last updated: 2026-04-24

---

## TL;DR — The Commands You Actually Need

### Build and launch (does everything)
```bash
cd ~/flux
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Debug build
open /Applications/Flux.app
```

That's it. The build auto-deploys to `/Applications/Flux.app`. Spotlight works. Done.

### Pull upstream changes
```bash
cd ~/flux
git fetch upstream
./scripts/sync-upstream.sh
```

---

## WHO

- **Upstream:** `farzaa/freewrite` — the original macOS journaling app
- **This fork:** `jcbbge/flux` (branch `m5-updates`) — customized version with lens sidebar, AI enrichment, fork-native filename format
- **You:** jrg, the only user and maintainer

---

## WHAT

This is a macOS native journaling app. The fork adds:
- Lens sidebar system
- AI enrichment (Ollama/SurrealDB)
- Fork-native filename format (`yyyy-MM-dd.md`)
- Design tokens, debounced saves, backup system

The upstream occasionally adds features (like video journaling) that need to be manually integrated.

---

## WHERE

| Thing | Location |
|-------|----------|
| Source code | `~/flux/` |
| Built app (auto-deployed) | `/Applications/Flux.app` |
| DerivedData build | `~/Library/Developer/Xcode/DerivedData/Flux-ejkelmnfjwtqssffcbtxkaxmkmho/Build/Products/Debug/Flux.app` |
| Journal entries | `~/flux/Entries/` |
| Entry backups | `~/flux/EntriesBackup/` |
| Video assets | `~/Documents/Freewrite/Videos/` |

---

## WHEN

### Build triggers
- After any code change
- After pulling upstream changes
- After any agent session that modifies Swift files

### Upstream sync triggers
- When you see new commits in upstream you want
- When a feature is missing that upstream has
- Run `git fetch upstream && git log upstream/main --oneline -10` to check

---

## WHY (The Traps)

### Why does Spotlight show an old version?
macOS Spotlight doesn't index symlinks. The build phase now **copies** the built app to `/Applications/Flux.app` on every build. This is automatic.

### Why do entries disappear?
The app sandbox. It's disabled (`Flux.entitlements` has `app-sandbox = false`). If someone re-enables it, entries in `~/flux/Entries/` become invisible. **Do not enable the sandbox.**

### Why can't I cherry-pick/rebase from upstream?
The upstream uses `freewrite/` directory. This fork uses `Flux/`. Every automated merge produces conflicts because Git can't match paths. **Always sync manually.**

### Why is there a stale binary?
Before this fix, `/Applications/Flux.app` was a manually copied old version. Now the build auto-deploys. If you ever see stale code running:
1. Check what's running: `ps -p $(pgrep Flux) -o args=`
2. Should show the DerivedData path being launched via /Applications symlink resolution
3. If not, run a clean build: `xcodebuild ... clean build`

---

## HOW — Step by Step

### 1. Build and Run

```bash
cd ~/flux
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Debug build
open /Applications/Flux.app
```

The build phase:
1. Compiles Swift
2. Bakes git commit hash into Info.plist
3. **Auto-deploys to /Applications/Flux.app**
4. Registers with LaunchServices

### 2. Sync from Upstream

**DO NOT rebase. DO NOT cherry-pick.**

```bash
cd ~/flux
git fetch upstream

# See what's new
git log m5-updates..upstream/main --oneline

# For each file that changed in upstream:
git show upstream/main:freewrite/SomeFile.swift > /tmp/upstream-version.swift
# Compare and manually apply changes to Flux/SomeFile.swift

# Or use the sync script (interactive):
./scripts/sync-upstream.sh
```

The sync script shows you diffs and lets you apply them file-by-file.

### 3. Clean Build (When Things Are Weird)

```bash
cd ~/flux
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Debug clean build
```

### 4. Verify What's Running

```bash
# What process?
pgrep -l Flux

# What binary?
ps -p $(pgrep Flux) -o args=

# What commit is baked in?
/usr/libexec/PlistBuddy -c "Print :GitCommit" /Applications/Flux.app/Contents/Info.plist
```

### 5. Kill and Relaunch

```bash
pkill Flux; sleep 1; open /Applications/Flux.app
```

---

## Build Phases (Automated)

The Xcode project has these build phases in order:

1. **Compile Sources** — standard Swift compilation
2. **Link Binary** — standard linking
3. **Copy Resources** — bundle resources
4. **Bake GitCommit into Info.plist** — stamps current git hash
5. **Deploy to Applications** — copies built .app to /Applications, registers with LaunchServices

Phases 4 and 5 are custom shell scripts added to `project.pbxproj`.

---

## File Map

| Fork file | Upstream equivalent | Notes |
|-----------|---------------------|-------|
| `Flux/ContentView.swift` | `freewrite/ContentView.swift` | ~3300 lines, heavily customized, NEVER auto-merge |
| `Flux/VideoRecordingView.swift` | `freewrite/VideoRecordingView.swift` | Identical to upstream |
| `Flux/VideoPlayerView.swift` | `freewrite/VideoPlayerView.swift` | Identical to upstream |
| `Flux/Models.swift` | `freewrite/Models.swift` | Has `entryType`, `videoFilename` params |
| `Flux/Flux.entitlements` | `freewrite/freewrite.entitlements` | Sandbox disabled |
| `Config/Flux-Info.plist` | `freewrite/Info.plist` | Has GitCommit key |

---

## Emergency Recovery

### Entries missing at runtime
```bash
# Check sandbox isn't re-enabled
grep -A1 "app-sandbox" Flux/Flux.entitlements
# Should show: <false/>

# Check entries exist
ls ~/flux/Entries/
```

### Wrong binary running
```bash
pkill Flux
rm -rf /Applications/Flux.app
xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Debug clean build
open /Applications/Flux.app
```

### Upstream merge destroyed ContentView
```bash
git checkout backup/m5-updates-pre-rebase -- Flux/ContentView.swift
# Or reset to last known good commit
git log --oneline -20
git checkout <good-commit> -- Flux/ContentView.swift
```

---

## Scripts

| Script | What it does |
|--------|--------------|
| `scripts/deploy-to-applications.sh` | Manual deploy (now automated in build) |
| `scripts/sync-upstream.sh` | Interactive upstream sync helper |
| `scripts/embed-git-commit.sh` | Legacy, now handled by build phase |

