#!/bin/sh
# Builds the app, launches it headless (no permission prompt), checks it stays alive, then quits it.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
./.build/release/FlashPaste --headless &
PID=$!
sleep 4
if kill -0 "$PID" 2>/dev/null; then
    echo "smoke: FlashPaste (pid $PID) is running"
    kill -TERM "$PID"
    wait "$PID" 2>/dev/null || true
    echo "smoke: OK"
else
    echo "smoke: FAIL, process exited early"
    exit 1
fi
