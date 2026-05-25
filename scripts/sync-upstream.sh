#!/bin/bash
# Sync upstream changes into this fork
# NEVER rebases or cherry-picks — shows diffs for manual application
set -e

cd "$(dirname "$0")/.."

echo "=== Flux Upstream Sync ==="
echo ""

# Fetch latest
git fetch upstream

# Show what's new
echo "New commits in upstream/main since last sync:"
echo "----------------------------------------------"
git log main..upstream/main --oneline
echo ""

# Key files to check
FILES=(
    "freewrite/VideoRecordingView.swift:Flux/VideoRecordingView.swift"
    "freewrite/VideoPlayerView.swift:Flux/VideoPlayerView.swift"
    "freewrite/ContentView.swift:Flux/ContentView.swift"
    "freewrite/Models.swift:Flux/Models.swift"
)

echo "Checking each tracked file for changes..."
echo ""

for pair in "${FILES[@]}"; do
    upstream_file="${pair%%:*}"
    fork_file="${pair##*:}"
    
    echo "--- $fork_file ---"
    
    if ! git show upstream/main:"$upstream_file" > /dev/null 2>&1; then
        echo "  [SKIP] Not in upstream"
        continue
    fi
    
    if [ ! -f "$fork_file" ]; then
        echo "  [NEW] File doesn't exist in fork — copying from upstream"
        git show upstream/main:"$upstream_file" > "$fork_file"
        continue
    fi
    
    # Compare
    if diff -q <(git show upstream/main:"$upstream_file") "$fork_file" > /dev/null 2>&1; then
        echo "  [OK] Identical to upstream"
    else
        echo "  [DIFF] Changes detected"
        echo ""
        echo "  To see diff:"
        echo "    diff <(git show upstream/main:$upstream_file) $fork_file"
        echo ""
        echo "  To see upstream version:"
        echo "    git show upstream/main:$upstream_file"
        echo ""
        
        if [[ "$fork_file" == *"ContentView.swift" ]]; then
            echo "  ⚠️  WARNING: ContentView.swift is heavily customized."
            echo "     DO NOT overwrite. Review changes manually and apply selectively."
        fi
    fi
    echo ""
done

echo "=== Done ==="
echo ""
echo "After applying changes, rebuild:"
echo "  xcodebuild -project Flux.xcodeproj -scheme Flux -configuration Debug build"
echo ""
