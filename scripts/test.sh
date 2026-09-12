#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Some standalone Command Line Tools releases ship Swift Testing but SwiftPM does
# not discover the framework and its interop library. Full Xcode needs no override.
DEVELOPER_PATH="$(xcode-select -p)"
FRAMEWORKS="$DEVELOPER_PATH/Library/Developer/Frameworks"
INTEROP="$DEVELOPER_PATH/Library/Developer/usr/lib"
if [ -d "$FRAMEWORKS/Testing.framework" ]; then
  swift test --disable-xctest --enable-swift-testing \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$INTEROP" "$@"
else
  swift test --disable-xctest --enable-swift-testing "$@"
fi
