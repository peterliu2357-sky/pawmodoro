#!/usr/bin/env bash
# Runs the unit tests.
#
# This machine has only the Command Line Tools (no full Xcode). Swift Testing
# ships there, but SwiftPM doesn't add its framework search path automatically,
# and the Foundation<->Testing cross-import overlay has no swiftmodule in CLT —
# so we point at the framework dir and disable cross-import overlays.
# With full Xcode installed, a plain `swift test` works and this script is moot.
set -euo pipefail

FW="$(xcode-select -p)/Library/Developer/Frameworks"

# DYLD_FRAMEWORK_PATH lets the test bundle find Testing.framework at load time;
# the baked-in rpath covers direct invocations of the built bundle.
export DYLD_FRAMEWORK_PATH="$FW${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"

exec swift test \
  -Xswiftc -F -Xswiftc "$FW" \
  -Xlinker -F -Xlinker "$FW" \
  -Xlinker -rpath -Xlinker "$FW" \
  -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
  "$@"
