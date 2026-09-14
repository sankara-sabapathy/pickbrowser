#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$PROJECT_ROOT/scripts/prepare-dmg-tools.sh"
exec "$PROJECT_ROOT/.build/dmg-tools/bin/python" "$PROJECT_ROOT/scripts/dmg.py" verify \
  "${1:?Usage: verify-dmg.sh PickBrowser.dmg [version]}" "${2:-}"
