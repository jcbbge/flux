#!/bin/bash
# Deploy built Flux.app to /Applications after xcodebuild
set -e
pkill Flux 2>/dev/null || true
sleep 0.5
rm -rf /Applications/Flux.app
cp -R "/Users/jrg/Library/Developer/Xcode/DerivedData/Flux-ejkelmnfjwtqssffcbtxkaxmkmho/Build/Products/Debug/Flux.app" /Applications/Flux.app
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f /Applications/Flux.app
echo "Deployed to /Applications/Flux.app"
