#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

# Guard policy (skeleton): require tree_paths exists and non-empty
if [ ! -s station_meta/tree/tree_paths.txt ]; then
  echo "GUARD_FAIL: TREE_NOT_BUILT"
  exit 10
fi

# Future: compare repo mtime vs tree build time and stop if stale
echo "GUARD_OK: TREE"
