# Xcode Command Line Tools Fix

## Problem
Xcode installation is corrupted - DVTDownloads framework missing symbols needed by IDESimulatorFoundation.

## Fix Steps

### Step 1: Remove Corrupted Tools
```bash
sudo rm -rf /Library/Developer/CommandLineTools
```

### Step 2: Trigger Install (Opens GUI Dialog)
```bash
xcode-select --install
```

### Step 3: In the GUI Dialog
- Click "Install" (NOT "Get Xcode")
- Wait for download (2-5 minutes)
- Accept any license agreements

### Step 4: Verify
```bash
# Check tools path
xcode-select -p
# Should output: /Library/Developer/CommandLineTools

# Verify git works
git --version

# Then build Flux
make clean
make install
```

## If Still Broken
Try opening Xcode.app directly once to complete first-launch setup:
```bash
open -a Xcode
```
Let it finish setup, then close it and retry.

## Emergency Full Reset
```bash
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --reset
xcode-select --install
```

---
Created: 2026-03-11
Flux project: /Users/jcbbge/flux
