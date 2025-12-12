#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
LD="$ROOT/station_meta/locks"
mkdir -p "$LD"
echo ">>> [locks_clear] removing lock files in $LD"
ls -1 "$LD" 2>/dev/null || true
rm -f "$LD"/*.lock.json 2>/dev/null || true
echo ">>> [locks_clear] done"
