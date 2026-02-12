# Flux Build Workflow

One-command build and install system. No Xcode GUI needed.

## Quick Start

```bash
cd /Users/jcbbge/flux
make install
```

This builds, embeds git commit, signs, and installs to `/Applications`.

## Commands

| Command | Purpose |
|---------|---------|
| `make build` | Build Release app, embed commit, sign |
| `make install` | Build + install to `/Applications` |
| `make run` | Launch installed app |
| `make dev` | Build + run from build dir (no install) |
| `make clean` | Delete build output |
| `make clean-all` | Delete build + installed app |
| `make verify` | Check commit match and signature |

## Verification

After `make install`, check sidebar shows:
- `build: abc1234 [✓]` — commit matches repo HEAD
- `build: abc1234 [X]` — stale build
- `build: unknown [?]` — commit not embedded

Manual verification:
```bash
defaults read /Applications/Flux.app/Contents/Info GitCommit
git rev-parse --short HEAD
```

## Rules

1. **Always use `make install`** — never manually copy to `/Applications`
2. **Never run unsigned builds** — macOS rejects them
3. **Commit before building** — uncommitted changes show `[X]` mismatch
4. **Verify after install** — check `[✓]` in sidebar

## Troubleshooting

**App won't launch (signature error):**
```bash
make clean-all
make install
```

**Wrong commit showing:**
```bash
git status          # check for uncommitted changes
git add -A && git commit -m "..."
make clean install
```

**Want to test without installing:**
```bash
make dev            # runs from build dir, no signing issues
```

## Technical Details

- **Build location:** `./build-output/Build/Products/Release/Flux.app`
- **Install location:** `/Applications/Flux.app`
- **Commit embedding:** `Info.plist` key `GitCommit`
- **Signing:** Ad-hoc (`codesign -s -`) required for `/Applications`
