#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

out="station_meta/tree/broadcast.txt"
count="$(wc -l < station_meta/tree/tree_paths.txt 2>/dev/null || echo 0)"

{
  echo "STATION TREE BROADCAST"
  echo "ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "paths_count=$count"
  echo "head:"
  head -n 20 station_meta/tree/tree_paths.txt 2>/dev/null || true
} > "$out"

cat "$out"
echo ">>> [tree_broadcast] wrote $out"

# --- Guard stamp update (truth) ---
bash scripts/guards/update_tree_stamp.sh || true
