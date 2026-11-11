#!/bin/sh
# Builds the app and zips it as build/FlashPaste.zip for a GitHub Release.
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/build.sh"
cd "$ROOT/build"
rm -f FlashPaste.zip
ditto -c -k --keepParent FlashPaste.app FlashPaste.zip
echo "release archive: $ROOT/build/FlashPaste.zip"
