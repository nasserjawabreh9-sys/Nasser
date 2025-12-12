#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1500"
MODE="${1:-PROD}"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo ">>> [R${ROOT_ID}] Guards + AutoQueue(diff) + Stop-the-world (mode=${MODE})"

mkdir -p scripts/guards scripts/ops station_meta/guards station_meta/queue station_meta/tree station_meta/bindings

# --- 1) Guard: ensure tree + bindings are fresh and consistent ---
cat > scripts/guards/guard_tree_bindings.sh << 'EOF'
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
EOF
chmod +x scripts/guards/guard_tree_bindings.sh

# --- 2) Guard: require clean bindings for any Ops pipeline (stop world otherwise) ---
cat > scripts/guards/guard_ops_gate.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
bash scripts/guards/guard_tree_bindings.sh
EOF
chmod +x scripts/guards/guard_ops_gate.sh

# --- 3) Auto-queue from git diff (creates tasks.jsonl) ---
cat > scripts/ops/diff_to_queue.py << 'PY'
import os, sys, json, subprocess, time
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
Q=os.path.join(ROOT,"station_meta/queue/tasks.jsonl")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def sh(cmd):
    p=subprocess.Popen(cmd, shell=True, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out=p.communicate()[0] or ""
    return p.returncode, out

def main():
    os.makedirs(os.path.dirname(Q), exist_ok=True)

    # changed files since last commit (staged+unstaged)
    _, out = sh("git status --porcelain")
    lines=[ln.strip() for ln in out.splitlines() if ln.strip()]
    if not lines:
        print(">>> [diff_to_queue] no changes -> no tasks")
        return

    # categorize into rooms
    tasks=[]
    for ln in lines:
        path=ln[3:] if len(ln)>3 else ln
        room="R5"
        pipeline="stage_only"

        if path.startswith("specs/") or path.startswith("station_meta/tree") or path.startswith("station_meta/bindings"):
            room="R1"; pipeline="bootstrap_validate"
        elif path.startswith("backend/"):
            room="R2"; pipeline="termux_env_prepare_backend"
        elif path.startswith("frontend/"):
            room="R4"; pipeline="frontend_build_check"
        elif path.startswith("scripts/"):
            room="R5"; pipeline="stage_only"

        tasks.append({
            "ts": utc(),
            "room": room,
            "pipeline": pipeline,
            "path": path,
            "status": "queued"
        })

    # append tasks
    with open(Q,"a",encoding="utf-8") as f:
        for t in tasks:
            f.write(json.dumps(t, ensure_ascii=False)+"\n")

    print(f">>> [diff_to_queue] queued={len(tasks)} -> {Q}")

if __name__=="__main__":
    main()
PY
chmod +x scripts/ops/diff_to_queue.py

# --- 4) Queue Runner: read tasks.jsonl and execute via Room Runner (locked) ---
cat > scripts/ops/queue_runner.py << 'PY'
import os, json, time, subprocess
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
Q=os.path.join(ROOT,"station_meta/queue/tasks.jsonl")
PROCESSED=os.path.join(ROOT,"station_meta/queue/processed.jsonl")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def sh(cmd):
    p=subprocess.Popen(cmd, shell=True, cwd=ROOT)
    p.wait()
    return p.returncode

def load_lines(path):
    if not os.path.exists(path): return []
    out=[]
    with open(path,"r",encoding="utf-8") as f:
        for ln in f:
            ln=ln.strip()
            if not ln: continue
            try: out.append(json.loads(ln))
            except: pass
    return out

def append(path,obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path,"a",encoding="utf-8") as f:
        f.write(json.dumps(obj, ensure_ascii=False)+"\n")

def main():
    tasks=load_lines(Q)
    if not tasks:
        print(">>> [queue_runner] empty queue")
        return

    # simple: group by pipeline
    by={}
    for t in tasks:
        if t.get("status")!="queued": continue
        key=(t.get("room"), t.get("pipeline"))
        by.setdefault(key, []).append(t)

    # run guard first (stop-the-world)
    rc=sh("bash scripts/guards/guard_ops_gate.sh")
    if rc!=0:
        print(">>> [queue_runner] GUARD FAILED -> stop")
        return

    for (room,pipeline), items in by.items():
        # run single pipeline via dynamo to keep ledger consistent
        mode=os.environ.get("ST_MODE","PROD")
        root=os.environ.get("ST_ROOT","1500")
        cmd=f"bash scripts/ops/st.sh dynamo start {mode} {pipeline} {root}"
        print(f">>> [queue_runner] run {room} {pipeline} count={len(items)}")
        rc2=sh(cmd)
        for it in items:
            it2=dict(it)
            it2["processed_utc"]=utc()
            it2["run_rc"]=rc2
            it2["status"]="done" if rc2==0 else "failed"
            append(PROCESSED, it2)

    print(">>> [queue_runner] DONE")

if __name__=="__main__":
    main()
PY
chmod +x scripts/ops/queue_runner.py

# --- 5) st commands: guard / queue / autodiff ---
grep -q 'cmd" = "guard"' scripts/ops/st.sh || cat >> scripts/ops/st.sh << 'EOF'

if [ "$cmd" = "guard" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    tree)
      bash scripts/guards/guard_tree_bindings.sh
      ;;
    *)
      echo "Usage: st guard tree"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "queue" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    autodiff)
      python scripts/ops/diff_to_queue.py
      ;;
    run)
      export ST_MODE="${1:-PROD}"
      export ST_ROOT="${2:-1500}"
      python scripts/ops/queue_runner.py
      ;;
    *)
      echo "Usage: st queue autodiff"
      echo "       st queue run <MODE> <ROOT_ID>"
      exit 1
      ;;
  esac
  exit 0
fi
EOF

# --- 6) Update last_tree_stamp after bootstrap_validate runs (hook) ---
# We implement a small helper and add it at the end of tree_broadcast script if present.
cat > scripts/guards/update_tree_stamp.sh << 'EOF'
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
EOF
chmod +x scripts/guards/update_tree_stamp.sh

if [ -f scripts/tree_authority/tree_broadcast.sh ]; then
  grep -q "update_tree_stamp" scripts/tree_authority/tree_broadcast.sh || cat >> scripts/tree_authority/tree_broadcast.sh << 'EOF'

# --- Guard stamp update (truth) ---
bash scripts/guards/update_tree_stamp.sh || true
EOF
fi

# --- 7) Run guards once (will create stamp if missing) ---
bash scripts/guards/guard_tree_bindings.sh || true

# --- 8) Stage/commit/push with tag ---
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} Guards(stop-world) + AutoQueue(diff) + QueueRunner"

echo ">>> [R${ROOT_ID}] DONE"
echo "Use:"
echo "  st guard tree"
echo "  st queue autodiff"
echo "  st queue run PROD 1500"
