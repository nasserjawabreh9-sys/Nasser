#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_DIR="$HOME/station_root"
TREE_PATH="$ROOT_DIR/station_meta/tree/tree_paths.txt"
BIND_PATH="$ROOT_DIR/station_meta/bindings/bindings.json"
STAMP_PATH="$ROOT_DIR/station_meta/guards/last_tree_stamp.json"

mkdir -p "$ROOT_DIR/station_meta/guards"

now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

fail() {
  echo "☠️ [GUARD] STOP-THE-WORLD: $1"
  echo "Fix: run -> bash scripts/ops/st.sh dynamo start PROD bootstrap_validate 1000"
  exit 91
}

# required files
[ -f "$TREE_PATH" ] || fail "Missing tree_paths.txt"
[ -f "$BIND_PATH" ] || fail "Missing bindings.json"

# compute current git HEAD + file mtimes
HEAD="$(git rev-parse HEAD 2>/dev/null || echo "NO_GIT")"
TREE_MTIME="$(stat -c %Y "$TREE_PATH" 2>/dev/null || echo 0)"
BIND_MTIME="$(stat -c %Y "$BIND_PATH" 2>/dev/null || echo 0)"

# if stamp missing -> force refresh once
if [ ! -f "$STAMP_PATH" ]; then
  cat > "$STAMP_PATH" << JSON
{"head":"$HEAD","tree_mtime":$TREE_MTIME,"bind_mtime":$BIND_MTIME,"ts":"$(now_utc())"}
JSON
  echo ">>> [GUARD] First stamp created. OK."
  exit 0
fi

STAMP_HEAD="$(python -c 'import json;print(json.load(open("'"$STAMP_PATH"'"))["head"])' 2>/dev/null || echo "")"
STAMP_TREE="$(python -c 'import json;print(json.load(open("'"$STAMP_PATH"'"))["tree_mtime"])' 2>/dev/null || echo 0)"
STAMP_BIND="$(python -c 'import json;print(json.load(open("'"$STAMP_PATH"'"))["bind_mtime"])' 2>/dev/null || echo 0)"

# If HEAD changed since last stamp, require tree/bindings to be regenerated AFTER change.
if [ "$HEAD" != "$STAMP_HEAD" ]; then
  # allow if tree/bindings are newer than stamp record
  if [ "$TREE_MTIME" -le "$STAMP_TREE" ] || [ "$BIND_MTIME" -le "$STAMP_BIND" ]; then
    fail "HEAD changed ($STAMP_HEAD -> $HEAD) but tree/bindings not refreshed."
  fi
fi

# Basic sanity: bindings.json must contain 'root' keys and generated_utc
python - << 'PY' || exit 92
import json,sys
p="station_meta/bindings/bindings.json"
j=json.load(open(p,"r",encoding="utf-8"))
assert isinstance(j,dict)
assert "generated_utc" in j
assert "roots" in j and isinstance(j["roots"],dict) and len(j["roots"])>0
print(">>> [GUARD] bindings.json shape OK")
PY

echo ">>> [GUARD] OK"
