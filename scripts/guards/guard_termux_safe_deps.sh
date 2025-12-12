#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
POL="$ROOT/station_meta/guards/policy.json"
REQF="$ROOT/backend/requirements.txt"
[ -f "$POL" ] || { echo "GUARD_POLICY_MISSING"; exit 30; }
[ -f "$REQF" ] || { echo "BACKEND_REQUIREMENTS_MISSING"; exit 31; }

BLOCK="$(python - << 'PY'
import json,os
p=os.path.expanduser("~/station_root/station_meta/guards/policy.json")
j=json.load(open(p,"r",encoding="utf-8"))
print(" ".join(j.get("blocked_markers",[])))
PY
)"

FOUND=0
for m in $BLOCK; do
  if grep -qi "$m" "$REQF"; then
    echo "GUARD_BLOCKED_DEP_FOUND marker=$m in backend/requirements.txt"
    FOUND=1
  fi
done

if [ "$FOUND" -ne 0 ]; then
  echo "Action: remove blocked deps OR pin Termux-safe alternatives."
  exit 32
fi
echo ">>> [guard_termux_safe_deps] OK"
