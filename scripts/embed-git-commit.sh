#!/bin/bash
#
# embed-git-commit.sh
# Run this script as a build phase to embed the current git commit into Info.plist
#
# Add to Xcode:
# 1. Select project → Flux target → Build Phases
# 2. Click + → New Run Script Phase
# 3. Name: "Embed Git Commit"
# 4. Move this phase BEFORE "Copy Bundle Resources"
# 5. Shell: /bin/sh
# 6. Script: /Users/jcbbge/flux/scripts/embed-git-commit.sh
#

# Get the git commit hash
cd /Users/jcbbge/flux
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Path to the Info.plist in the built app
PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

# Check if plist exists
if [ -f "$PLIST" ]; then
    # Add or update GitCommit key
    /usr/libexec/PlistBuddy -c "Delete :GitCommit" "$PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :GitCommit string ${COMMIT}" "$PLIST"
    echo "✅ Embedded git commit: ${COMMIT}"
else
    echo "⚠️ Info.plist not found at: $PLIST"
    exit 0
fi
