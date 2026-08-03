#!/bin/bash
# Start BLEUnlock (Debug build from DerivedData)
#
# IMPORTANT: run from the DerivedData path, NOT /Applications.
# Accessibility (TCC) permission for this ad-hoc-signed build is bound to the
# original path. Launching from a different path (e.g. /Applications) loses the
# permission and unlock silently fails.
#
# Usage:
#   ./start.sh          # start (kills any existing instance first)
#   ./start.sh --build  # rebuild via xcodebuild, then start

set -e

# Find the most recent Debug build
APP=$(ls -dt "$HOME/Library/Developer/Xcode/DerivedData"/BLEUnlock-*/Build/Products/Debug/BLEUnlock.app 2>/dev/null | head -1 || true)
LOG="$HOME/Library/Logs/BLEUnlock/bleunlock.log"

if [ "$1" = "--build" ]; then
    echo "Building BLEUnlock..."
    xcodebuild -project "$(dirname "$0")/BLEUnlock.xcodeproj" \
               -scheme BLEUnlock -configuration Debug build | tail -5
    APP=$(ls -dt "$HOME/Library/Developer/Xcode/DerivedData"/BLEUnlock-*/Build/Products/Debug/BLEUnlock.app 2>/dev/null | head -1 || true)
fi

if [ -z "$APP" ] || [ ! -x "$APP/Contents/MacOS/BLEUnlock" ]; then
    echo "ERROR: BLEUnlock binary not found."
    echo "Build it first with:  ./start.sh --build"
    exit 1
fi

# Kill any existing instance (including one running from /Applications)
pkill -f "BLEUnlock.app/Contents/MacOS/BLEUnlock" 2>/dev/null || true
sleep 1

mkdir -p "$(dirname "$LOG")"
nohup "$APP/Contents/MacOS/BLEUnlock" > "$LOG" 2>&1 &
echo "BLEUnlock started from: $APP"
echo "PID: $!"
echo "Log: $LOG"

# Verify the HTTP server is up
sleep 2
if lsof -nP -iTCP:8123 -sTCP:LISTEN | grep -q BLEUnlock; then
    echo "Remote Unlock server: listening on port 8123"
else
    echo "WARNING: port 8123 not listening. Check log: $LOG"
fi
