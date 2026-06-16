#!/usr/bin/env bash
#
# Builds Pawmodoro from source and installs it into /Applications, then launches
# it. Because the app is built on THIS Mac, it carries no quarantine flag and
# Gatekeeper does not block it — so no Apple Developer account, code-signing, or
# notarization is needed. This is the simplest way to run Pawmodoro from source.
#
#   scripts/install.sh
#
# Prerequisites: macOS 14+ and the Xcode Command Line Tools. If the build fails
# with "swift: command not found", run:  xcode-select --install

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
APP="Pawmodoro"
DEST="/Applications/$APP.app"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: the Swift toolchain isn't installed." >&2
  echo "Run 'xcode-select --install', then re-run this script." >&2
  exit 1
fi

echo "==> Building ${APP} (this can take a minute the first time)"
"${REPO_ROOT}/packaging/package.sh" >/dev/null

echo "==> Installing to ${DEST}"
osascript -e 'tell application "Pawmodoro" to quit' >/dev/null 2>&1 || true
pkill -f "${APP}.app/Contents/MacOS/${APP}" 2>/dev/null || true
rm -rf "${DEST}"
cp -R "${REPO_ROOT}/dist/${APP}.app" "${DEST}"
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true

echo "==> Launching"
open "${DEST}"

echo
echo "Done. ${APP} is installed in /Applications and running."
echo "  Look for the cat/paw icon in your menu bar (top-right). Click it, then Start."
echo "  Adjust work/rest lengths under (menu bar icon) > Settings."
