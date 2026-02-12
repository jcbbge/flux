# Agent Build Protocol

**File location:** `/Users/jcbbge/flux/AGENTS.md`  
**Purpose:** Prevent build/deployment errors when modifying Flux

## Critical Rules

### 1. Never Manually Copy to /Applications

**WRONG:**
```bash
cp -R build-temp/.../Flux.app /Applications/   # CRASH: code signing
```

**RIGHT:**
```bash
make install    # Handles signing automatically
```

### 2. Always Commit Before Building

Uncommitted changes = `[X]` mismatch in app. User sees stale build.

```bash
git add -A
git commit -m "feat: ..."
make install
```

### 3. Verify After Every Install

Sidebar must show `[✓]`, not `[X]` or `[?]`.

```bash
make verify     # Automated check
# OR manually:
defaults read /Applications/Flux.app/Contents/Info GitCommit
```

### 4. Makefile Is Source of Truth

All build logic lives in `Makefile`. Do not:
- Create one-off xcodebuild commands
- Skip the signing step
- Use DerivedData directly

## Workflow for Code Changes

```bash
cd /Users/jcbbge/flux

# 1. Make changes
# ... edit files ...

# 2. Commit
make clean          # optional but safe
git add -A
git commit -m "type: description"

# 3. Build and install
make install

# 4. Verify
# - Check sidebar shows [✓]
# - Test functionality
```

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `EXC_BREAKPOINT` crash | Unsigned app in `/Applications` | Run `make install` |
| `[X]` in sidebar | Built before committing | Commit, then `make clean install` |
| `[?]` in sidebar | GitCommit not in plist | `make clean install` |
| App won't open | Quarantine attributes | `make install` (runs `xattr -cr`) |

## Emergency Recovery

If `/Applications/Flux.app` is broken:

```bash
cd /Users/jcbbge/flux
make clean-all
make install
```

## Quick Test (No Install)

For rapid iteration without `/Applications` issues:

```bash
make dev    # Builds and opens from build dir
```

No signing required. Good for UI testing before final install.

## Version Info Component

Located in `Flux/VersionInfo.swift`. Shows:
- Short commit hash
- Match status: `[✓]` `[X]` `[?]`

Style requirements:
- Size 10 font (matches sidebar "History" path text)
- Gray color, no emojis
- Position: sidebar header, below "History" button

## Git Commit Hash Flow

1. `Makefile` runs `embed-git-commit` target
2. Gets HEAD: `git rev-parse --short HEAD`
3. Injects into `Info.plist` key `GitCommit`
4. App reads via `Bundle.main.infoDictionary`
5. Sidebar displays via `VersionInfoBar`

No Xcode build phase scripts needed — all in Makefile.

## Checklist for Agents

Before claiming "build complete":

- [ ] Changes committed to git
- [ ] `make install` executed
- [ ] No errors in build output
- [ ] `make verify` shows match
- [ ] App launches without crash
- [ ] Sidebar shows `[✓]`

---

**Last updated:** 2026-02-12  
**Build system:** Makefile-based  
**Install target:** `/Applications/Flux.app`
