#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo ">>> [R1810] Fix tree stamp + avoid nested Dynamo locks"

mkdir -p scripts/ops scripts/tree_authority station_meta/tree station_meta/dynamo

# 1) Ensure tree_stamp exists (idempotent)
cat > scripts/tree_authority/tree_stamp.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EPOCH="$(date -u +%s)"
mkdir -p "$ROOT/station_meta/tree"
echo "$TS" > "$ROOT/station_meta/tree/last_tree_update_utc.txt"
echo "$EPOCH" > "$ROOT/station_meta/tree/last_tree_update_epoch.txt"
echo ">>> [tree_stamp] ts=$TS epoch=$EPOCH"
EOF
chmod +x scripts/tree_authority/tree_stamp.sh

# 2) Patch tree_update.sh to always write stamp after update (best-effort)
TU="scripts/tree_authority/tree_update.sh"
if [ -f "$TU" ]; then
  if ! grep -q "tree_stamp.sh" "$TU"; then
    echo "" >> "$TU"
    echo "# [R1810] stamp after tree update" >> "$TU"
    echo "bash scripts/tree_authority/tree_stamp.sh" >> "$TU"
    echo ">>> [R1810] patched $TU to write stamp"
  else
    echo ">>> [R1810] $TU already stamps"
  fi
else
  echo ">>> [R1810] WARN: $TU not found (skip patch). We'll rely on manual stamping after bootstrap."
fi

# 3) Add emergency lock cleaner (use only when stuck)
cat > scripts/ops/locks_clear.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
LD="$ROOT/station_meta/locks"
mkdir -p "$LD"
echo ">>> [locks_clear] removing lock files in $LD"
ls -1 "$LD" 2>/dev/null || true
rm -f "$LD"/*.lock.json 2>/dev/null || true
echo ">>> [locks_clear] done"
EOF
chmod +x scripts/ops/locks_clear.sh

# 4) Patch Dynamo plan_progression to NOT call dynamo.py inside dynamo (no nested locks)
CFG="station_meta/dynamo/dynamo_config.json"
python - << 'PY'
import json, os
p=os.path.expanduser("~/station_root/station_meta/dynamo/dynamo_config.json")
cfg=json.load(open(p,"r",encoding="utf-8"))
pipes=cfg.setdefault("pipelines",{})

# Keep preflight_guards as-is (already added), but fix plan_progression to inline steps
pipes["plan_progression"] = [
  {"name":"guard_tree_fresh","cmd":"bash scripts/guards/guard_tree_fresh.sh"},
  {"name":"rooms_broadcast","cmd":"bash scripts/rooms/rooms_broadcast.sh"},
  {"name":"guard_rooms_broadcast","cmd":"bash scripts/guards/guard_rooms_broadcast.sh"},
  {"name":"guard_termux_safe_deps","cmd":"bash scripts/guards/guard_termux_safe_deps.sh"},
  {"name":"integrate_report","cmd":"bash scripts/ops/integrate_report.sh"}
]

json.dump(cfg, open(p,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(">>> [R1810] patched pipeline: plan_progression (no nested dynamo)")
PY

# 5) Autopush this fix under Root 1810 (if autopush exists)
if [ -x scripts/ops/autopush_by_root.sh ]; then
  bash scripts/ops/autopush_by_root.sh 1810 "[PROD] R1810 Fix stamp + nested lock"
else
  echo ">>> [R1810] autopush_by_root not found (skip push)"
fi

echo ">>> [R1810] DONE"
echo "Next:"
echo "  bash scripts/ops/st.sh dynamo start PROD bootstrap_validate 1000"
echo "  # if stamp still missing (rare): bash scripts/tree_authority/tree_stamp.sh"
echo "  bash scripts/ops/st.sh dynamo start PROD preflight_guards 1800"
echo "  bash scripts/ops/st.sh dynamo start PROD plan_progression 1900"
