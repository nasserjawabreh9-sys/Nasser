#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TREE="$ROOT/station_meta/tree/tree_paths.txt"
OUT="$ROOT/station_meta/tree/broadcast.txt"
[ -f "$TREE" ] || { echo "TREE_MISSING: run tree_update"; exit 11; }
COUNT="$(wc -l < "$TREE" | tr -d ' ')"
{
  echo "STATION TREE BROADCAST"
  echo "ts=$TS"
  echo "paths_count=$COUNT"
  echo "head:"
  head -n 30 "$TREE"
} > "$OUT"
echo ">>> [tree_broadcast] wrote station_meta/tree/broadcast.txt"
