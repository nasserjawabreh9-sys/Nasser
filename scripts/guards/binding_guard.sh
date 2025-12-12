#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ ! -s station_meta/bindings/bindings.json ]; then
  echo "GUARD_FAIL: BINDINGS_MISSING"
  exit 11
fi

# Future: validate every changed path is mapped to a root_id rule
echo "GUARD_OK: BINDINGS"
