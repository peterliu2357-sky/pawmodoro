#!/usr/bin/env bash
# Renders the Dozy app icon to packaging/AppIcon.icns (run whenever the art
# changes). package.sh bundles AppIcon.icns automatically if present.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
swift "$DIR/make-icon.swift"
iconutil -c icns "$DIR/AppIcon.iconset" -o "$DIR/AppIcon.icns"
rm -rf "$DIR/AppIcon.iconset"
echo "Wrote $DIR/AppIcon.icns"
