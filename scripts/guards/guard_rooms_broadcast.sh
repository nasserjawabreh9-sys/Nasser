#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
POL="$ROOT/station_meta/guards/policy.json"
[ -f "$POL" ] || { echo "GUARD_POLICY_MISSING"; exit 20; }

REQ="$(python - << 'PY'
import json,os
p=os.path.expanduser("~/station_root/station_meta/guards/policy.json")
print(bool(json.load(open(p,"r",encoding="utf-8"))["require_rooms_broadcast"]))
PY
)"
if [ "$REQ" != "True" ]; then
  echo ">>> [guard_rooms_broadcast] SKIP by policy"
  exit 0
fi

LB="$ROOT/station_meta/rooms/last_broadcast.txt"
[ -f "$LB" ] || { echo "GUARD_ROOMS_BROADCAST_MISSING: run rooms_broadcast"; exit 21; }
echo ">>> [guard_rooms_broadcast] OK"
