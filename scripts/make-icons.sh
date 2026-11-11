#!/bin/sh
# Regenerates Resources/menubar.pdf, Resources/AppIcon.icns and the PNG previews in Resources/src/previews.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
swiftc -O "$ROOT/Resources/src/IconDesign.swift" "$ROOT/scripts/make-icons.swift" -o "$TMP/make-icons"
"$TMP/make-icons" "$ROOT"
rm -rf "$TMP"
