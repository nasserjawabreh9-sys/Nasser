#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT_DIR="$HOME/station_root"
STAMP="$ROOT_DIR/station_meta/guards/last_tree_stamp.json"
TREE="$ROOT_DIR/station_meta/tree/tree_paths.txt"
BIND="$ROOT_DIR/station_meta/bindings/bindings.json"
mkdir -p "$ROOT_DIR/station_meta/guards"
HEAD="$(git rev-parse HEAD 2>/dev/null || echo "NO_GIT")"
TREE_MTIME="$(stat -c %Y "$TREE" 2>/dev/null || echo 0)"
BIND_MTIME="$(stat -c %Y "$BIND" 2>/dev/null || echo 0)"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$STAMP" << JSON
{"head":"$HEAD","tree_mtime":$TREE_MTIME,"bind_mtime":$BIND_MTIME,"ts":"$TS"}
JSON
echo ">>> [GUARD] stamp updated"
