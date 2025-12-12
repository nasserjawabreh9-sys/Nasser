#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

OUT="$ROOT/station_meta/tree/tree_paths.txt"
BIND="$ROOT/station_meta/bindings/bindings.json"

# Build tree list (skip heavy dirs)
find . -type f \
  -not -path "./.git/*" \
  -not -path "./backend/.venv/*" \
  -not -path "./frontend/node_modules/*" \
  -not -path "./station_meta/locks/*" \
  -not -path "./station_logs/*" \
  | sed 's|^\./||' | sort > "$OUT"

# Minimal bindings truth (extend later)
python - << 'PY'
import json, os
root=os.path.expanduser("~/station_root")
p=os.path.join(root,"station_meta","bindings","bindings.json")
data={
  "version":"1.0.0",
  "root": root,
  "backend_dir": os.path.join(root,"backend"),
  "frontend_dir": os.path.join(root,"frontend"),
  "meta_dir": os.path.join(root,"station_meta"),
  "ops_dir": os.path.join(root,"scripts","ops"),
  "guards_dir": os.path.join(root,"scripts","guards"),
  "rooms_dir": os.path.join(root,"scripts","rooms"),
  "tree_authority_dir": os.path.join(root,"scripts","tree_authority")
}
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(data, open(p,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(">>> [tree_update] wrote station_meta/tree/tree_paths.txt and station_meta/bindings/bindings.json")
PY

bash scripts/tree_authority/tree_stamp.sh
echo ">>> [tree_update] stamp updated"
