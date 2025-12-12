#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
POL="$ROOT/station_meta/guards/policy.json"
TREE="$ROOT/station_meta/tree/tree_paths.txt"
STAMP="$ROOT/station_meta/tree/last_tree_update_epoch.txt"

[ -f "$POL" ] || { echo "GUARD_POLICY_MISSING"; exit 10; }
[ -f "$TREE" ] || { echo "GUARD_TREE_MISSING: run tree_update"; exit 11; }
[ -f "$STAMP" ] || { echo "GUARD_STAMP_MISSING: run tree_update"; exit 12; }

REQ="$(python - << 'PY'
import json,os
p=os.path.expanduser("~/station_root/station_meta/guards/policy.json")
print(int(json.load(open(p,"r",encoding="utf-8"))["require_tree_fresh_seconds"]))
PY
)"

NOW="$(date -u +%s)"
LAST="$(cat "$STAMP" | tr -d '\r\n')"
AGE=$(( NOW - LAST ))

if [ "$AGE" -gt "$REQ" ]; then
  echo "GUARD_TREE_STALE age_seconds=$AGE limit=$REQ"
  echo "Action: bash scripts/tree_authority/tree_update.sh && bash scripts/tree_authority/tree_broadcast.sh"
  exit 14
fi

echo ">>> [guard_tree_fresh] OK age_seconds=$AGE"
