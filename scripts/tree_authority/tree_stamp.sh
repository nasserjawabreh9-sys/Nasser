#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EPOCH="$(date -u +%s)"
mkdir -p "$ROOT/station_meta/tree"
echo "$TS" > "$ROOT/station_meta/tree/last_tree_update_utc.txt"
echo "$EPOCH" > "$ROOT/station_meta/tree/last_tree_update_epoch.txt"
echo ">>> [tree_stamp] ts=$TS epoch=$EPOCH"
