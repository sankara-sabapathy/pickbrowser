#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$PROJECT_ROOT/scripts/prepare-dmg-tools.sh"
exec "$PROJECT_ROOT/.build/dmg-tools/bin/python" "$PROJECT_ROOT/scripts/dmg.py" build \
  "${1:-$PROJECT_ROOT/dist/PickBrowser.app}" "${2:-$PROJECT_ROOT/dist/release/PickBrowser.dmg}" \
  "${PICKBROWSER_VERSION:-$(tr -d '\n' < "$PROJECT_ROOT/VERSION")}"
