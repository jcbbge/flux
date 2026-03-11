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

### 4. Always Clean Before Building

Old build directories litter the system. **Always run `make clean` before building.**

```bash
make clean    # Remove old build-output/
make install  # Then build fresh
```

Or use the combined target:
```bash
make clean install
```

### 5. Makefile Is Source of Truth

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
make clean          # ALWAYS clean old builds first!
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

- [ ] `make clean` executed FIRST (removes old build-output/)
- [ ] Changes committed to git
- [ ] `make install` executed
- [ ] No errors in build output
- [ ] `make verify` shows match
- [ ] App launches without crash
- [ ] Sidebar shows `[✓]`

---

## Swift Code Standards

### Brace Discipline

This codebase has one large file (`ContentView.swift`, 2700+ lines). Brace errors here
cascade into 50+ false errors. Every function/struct/closure must be explicitly closed.

**After any edit to ContentView.swift**, run:
```bash
xcrun swiftc -typecheck Flux/ContentView.swift 2>&1 | head -20
```

**"Does not conform to protocol 'View'"** = brace mismatch. Do NOT debug logic. Count braces:
```bash
python3 - <<'EOF'
with open('Flux/ContentView.swift') as f:
    lines = f.readlines()
depth = 0
for i, line in enumerate(lines, 1):
    prev = depth
    for ch in line:
        if ch == '{': depth += 1
        elif ch == '}': depth -= 1
    if depth == 0 and i < len(lines) and prev > 0:
        print(f"PREMATURE CLOSE line {i}: {line.strip()[:80]}")
print(f"Final depth: {depth}")
EOF
```

This finds the exact bad line in <1 second. Trust it. Fix only that line.

### SwiftUI Rules

- `ContentView` is a SwiftUI `View` struct — it requires `var body: some View` inside the struct
- All `@State`, `@Binding`, and computed properties must live INSIDE the struct
- Extensions on `NSView` and helper functions at file scope must be OUTSIDE the struct
- File-scope `func` or `extension` blocks inside ContentView = brace mismatch above them

### Safe Edit Workflow for ContentView.swift

```
1. Make targeted edit
2. xcrun swiftc -typecheck Flux/ContentView.swift 2>&1 | head -5
3. If errors → run brace-depth script above
4. Fix the ONE structural line it points to
5. Re-typecheck
6. Only then: make clean install
```

**Never skip step 2.** The file is large enough that a single bad brace is invisible to the eye.

### Cascade Error Rule

If you see the same `@State` variable reported "not in scope" in 3+ functions simultaneously:
- Stop. Do not fix any individual error.
- That is a cascade from a single brace mismatch.
- Run the brace-depth script. Fix the root.

---

## Swift Debugging SOP

### Class 1: Compile Errors

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| `does not conform to protocol 'View'` | `body` is outside ContentView (brace mismatch) | Run brace-depth script |
| `cannot find 'X' in scope` (many) | Method/property displaced outside struct | Same |
| `declaration only valid at file scope` | Extensions/funcs inside struct that shouldn't be | Same |
| Single `cannot find 'X' in scope` | Missing import or actual typo | Check imports, spelling |
| `expression type is ambiguous` | Type inference failure in complex ViewBuilder | Add explicit type annotation |

### Class 2: Runtime / SwiftUI Crashes

- `EXC_BREAKPOINT` on launch → unsigned app in /Applications → `make install`
- State not updating → check that signal is read inside reactive scope (JSX/body)
- View not refreshing → ensure `@State`/`@Binding` used, not plain `var`

---

**Last updated:** 2026-03-11
**Build system:** Makefile-based
**Install target:** `/Applications/Flux.app`
