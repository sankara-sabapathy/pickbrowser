#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG_ENV="$PROJECT_ROOT/.build/dmg-tools"
if [ ! -x "$DMG_ENV/bin/python" ]; then python3 -m venv "$DMG_ENV"; fi
if "$DMG_ENV/bin/python" -c 'from importlib.metadata import version; assert version("ds-store") == "1.3.3" and version("mac-alias") == "2.2.2"' 2>/dev/null; then
  exit 0
fi
"$DMG_ENV/bin/python" -m pip --disable-pip-version-check install --require-hashes --only-binary=:all: \
  -r "$PROJECT_ROOT/scripts/dmg-requirements.txt"
