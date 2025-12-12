#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

ROOT_ID="9000"
MODE="${1:-PROD}"

echo ">>> [R${ROOT_ID}] ONE-SHOT BUILD (mode=${MODE}) @ $ROOT"

# -------------------------------
# 0) Directories (truth layout)
# -------------------------------
mkdir -p \
  scripts/{ops,guards,rooms,tree_authority} \
  station_meta/{tree,bindings,guards,rooms,dynamo,locks,integrate,stage_reports,queue} \
  station_logs

# -------------------------------
# 1) Guard policy (truth)
# -------------------------------
cat > station_meta/guards/policy.json << 'JSON'
{
  "version": "1.0.0",
  "require_tree_fresh_seconds": 600,
  "require_rooms_broadcast": true,
  "block_heavy_build_deps": true,
  "blocked_markers": ["maturin", "rust", "pydantic-core", "watchfiles"],
  "allowed_modes": ["TRIAL-1","TRIAL-2","TRIAL-3","PROD"]
}
JSON

# -------------------------------
# 2) Tree stamp
# -------------------------------
cat > scripts/tree_authority/tree_stamp.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EPOCH="$(date -u +%s)"
mkdir -p "$ROOT/station_meta/tree"
echo "$TS" > "$ROOT/station_meta/tree/last_tree_update_utc.txt"
echo "$EPOCH" > "$ROOT/station_meta/tree/last_tree_update_epoch.txt"
EOF
chmod +x scripts/tree_authority/tree_stamp.sh

# -------------------------------
# 3) Tree update (writes tree_paths + bindings)
# -------------------------------
cat > scripts/tree_authority/tree_update.sh << 'EOF'
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
EOF
chmod +x scripts/tree_authority/tree_update.sh

# -------------------------------
# 4) Tree broadcast
# -------------------------------
cat > scripts/tree_authority/tree_broadcast.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TREE="$ROOT/station_meta/tree/tree_paths.txt"
OUT="$ROOT/station_meta/tree/broadcast.txt"
[ -f "$TREE" ] || { echo "TREE_MISSING: run tree_update"; exit 11; }
COUNT="$(wc -l < "$TREE" | tr -d ' ')"
{
  echo "STATION TREE BROADCAST"
  echo "ts=$TS"
  echo "paths_count=$COUNT"
  echo "head:"
  head -n 30 "$TREE"
} > "$OUT"
echo ">>> [tree_broadcast] wrote station_meta/tree/broadcast.txt"
EOF
chmod +x scripts/tree_authority/tree_broadcast.sh

# -------------------------------
# 5) Rooms truth + broadcast
# -------------------------------
cat > scripts/rooms/rooms_broadcast.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DIR="$ROOT/station_meta/rooms"
mkdir -p "$DIR"

# 5 Rooms (can grow later)
cat > "$DIR/room_01_tree_authority.json" << 'JSON'
{"room":"tree_authority","scope":"tree_update + bindings + stamps + broadcast","outputs":["station_meta/tree/*","station_meta/bindings/bindings.json"]}
JSON
cat > "$DIR/room_02_guards.json" << 'JSON'
{"room":"guards","scope":"block bad deps + require tree fresh + require rooms broadcast + root id discipline","outputs":["scripts/guards/*","station_meta/guards/policy.json"]}
JSON
cat > "$DIR/room_03_dynamo_ops.json" << 'JSON'
{"room":"dynamo_ops","scope":"pipelines + locks + events + stage push","outputs":["scripts/ops/dynamo.py","station_meta/dynamo/dynamo_config.json","station_meta/dynamo/events.jsonl"]}
JSON
cat > "$DIR/room_04_backend.json" << 'JSON'
{"room":"backend","scope":"backend skeleton + health endpoint + safe deps","outputs":["backend/app/*","backend/requirements.txt"]}
JSON
cat > "$DIR/room_05_frontend.json" << 'JSON'
{"room":"frontend","scope":"frontend skeleton + api client + official UI later","outputs":["frontend/src/*"]}
JSON

echo "$TS" > "$DIR/last_broadcast.txt"
echo ">>> [rooms_broadcast] OK rooms_count=5"
EOF
chmod +x scripts/rooms/rooms_broadcast.sh

# -------------------------------
# 6) Guards (tree fresh, rooms broadcast, termux-safe deps, root id)
# -------------------------------
cat > scripts/guards/guard_tree_fresh.sh << 'EOF'
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
EOF
chmod +x scripts/guards/guard_tree_fresh.sh

cat > scripts/guards/guard_rooms_broadcast.sh << 'EOF'
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
EOF
chmod +x scripts/guards/guard_rooms_broadcast.sh

cat > scripts/guards/guard_termux_safe_deps.sh << 'EOF'
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
EOF
chmod +x scripts/guards/guard_termux_safe_deps.sh

cat > scripts/guards/guard_root_id_arg.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
RID="${1:-}"
[ -n "$RID" ] || { echo "GUARD_ROOT_ID_MISSING"; exit 40; }
echo "$RID" | grep -Eq '^[0-9]+$' || { echo "GUARD_ROOT_ID_NOT_NUMERIC"; exit 41; }
echo ">>> [guard_root_id_arg] OK root_id=$RID"
EOF
chmod +x scripts/guards/guard_root_id_arg.sh

# -------------------------------
# 7) Integrate report (single truth snapshot)
# -------------------------------
cat > scripts/ops/integrate_report.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUT="$ROOT/station_meta/integrate/integrate_${TS}.txt"
mkdir -p "$ROOT/station_meta/integrate"

{
  echo "INTEGRATE_REPORT ts=$TS"
  echo
  echo "[TREE]"
  ls -la "$ROOT/station_meta/tree" || true
  echo
  echo "[ROOMS]"
  ls -la "$ROOT/station_meta/rooms" || true
  echo
  echo "[GUARDS]"
  ls -la "$ROOT/scripts/guards" || true
  echo
  echo "[DYNAMO]"
  ls -la "$ROOT/scripts/ops" || true
} > "$OUT"

echo ">>> [integrate_report] wrote $OUT"
EOF
chmod +x scripts/ops/integrate_report.sh

# -------------------------------
# 8) stage_commit_push (single pipeline for pushes)
# -------------------------------
cat > scripts/ops/stage_commit_push.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

RID="${1:-}"; shift || true
MSG="${1:-}"; shift || true

bash scripts/guards/guard_root_id_arg.sh "$RID"

if [ -z "$MSG" ]; then
  MSG="[R${RID}] stage"
fi

git add -A

if git diff --cached --quiet; then
  echo ">>> [stage_commit_push] no changes to commit"
else
  git commit -m "$MSG"
fi

echo ">>> [stage_commit_push] pushing to origin..."
git push
echo ">>> [stage_commit_push] push OK"
EOF
chmod +x scripts/ops/stage_commit_push.sh

cat > scripts/ops/autopush_by_root.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
RID="${1:-}"; shift || true
MSG="${1:-}"; shift || true
bash scripts/ops/stage_commit_push.sh "$RID" "${MSG:-[R${RID}] autopush}"
EOF
chmod +x scripts/ops/autopush_by_root.sh

# -------------------------------
# 9) Dynamo (locks + pipelines)
# -------------------------------
cat > scripts/ops/dynamo.py << 'PY'
import json, os, sys, time, subprocess, hashlib
from datetime import datetime, timezone

ROOT_DIR = os.path.expanduser("~/station_root")

def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def sh(cmd: str) -> tuple[int, str]:
    p = subprocess.Popen(cmd, shell=True, cwd=ROOT_DIR,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out=[]
    for line in p.stdout:
        out.append(line)
        print(line, end="")
    p.wait()
    return p.returncode, "".join(out)

def read_json(path: str):
    with open(os.path.join(ROOT_DIR, path), "r", encoding="utf-8") as f:
        return json.load(f)

def write_event(event_path: str, e: dict):
    full = os.path.join(ROOT_DIR, event_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "a", encoding="utf-8") as f:
        f.write(json.dumps(e, ensure_ascii=False) + "\n")

def lock_path(lock_dir: str, name: str) -> str:
    return os.path.join(ROOT_DIR, lock_dir, f"{name}.lock.json")

def acquire_lock(lock_dir: str, name: str, owner: str, lease_seconds: int) -> None:
    os.makedirs(os.path.join(ROOT_DIR, lock_dir), exist_ok=True)
    lp = lock_path(lock_dir, name)
    now = int(time.time())
    if os.path.exists(lp):
        data = json.load(open(lp, "r", encoding="utf-8"))
        exp = data.get("acquired_at", 0) + data.get("lease_seconds", 0)
        if now < exp:
            raise RuntimeError(f"LOCK_BUSY:{name}:owned_by={data.get('owner')} until={exp}")
    data = {"name": name, "owner": owner, "acquired_at": now, "lease_seconds": lease_seconds}
    with open(lp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def release_lock(lock_dir: str, name: str, owner: str) -> None:
    lp = lock_path(lock_dir, name)
    if not os.path.exists(lp):
        return
    data = json.load(open(lp, "r", encoding="utf-8"))
    if data.get("owner") != owner:
        raise RuntimeError(f"LOCK_OWNER_MISMATCH:{name}")
    os.remove(lp)

def sha256_text(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()

def run_pipeline(cfg: dict, pipeline_name: str, mode: str, root_id: int):
    event_log = cfg["event_log"]
    lock_dir = cfg["lock_dir"]
    lease = int(cfg["lease_seconds"])
    owner = f"dynamo::{mode}::R{root_id}"

    locks = ["tree", "bindings", "env", "stage"]
    for ln in locks:
        acquire_lock(lock_dir, ln, owner, lease)

    try:
        steps = cfg["pipelines"].get(pipeline_name, [])
        if not steps:
            raise RuntimeError(f"PIPELINE_NOT_FOUND:{pipeline_name}")

        for i, step in enumerate(steps, start=1):
            e_start = {"ts": utc_now(), "mode": mode, "root_id": root_id,
                       "pipeline": pipeline_name, "step_index": i,
                       "step_name": step["name"], "status": "started", "cmd": step["cmd"]}
            write_event(event_log, e_start)

            rc, out = sh(step["cmd"])

            e_end = {"ts": utc_now(), "mode": mode, "root_id": root_id,
                     "pipeline": pipeline_name, "step_index": i,
                     "step_name": step["name"], "status": "succeeded" if rc == 0 else "failed",
                     "rc": rc, "out_sha256": sha256_text(out[-2000:])}
            write_event(event_log, e_end)

            if rc != 0:
                raise RuntimeError(f"STEP_FAILED:{pipeline_name}:{step['name']}")

    finally:
        for ln in reversed(locks):
            try:
                release_lock(lock_dir, ln, owner)
            except Exception:
                pass

def main():
    if len(sys.argv) < 3:
        print("Usage: python scripts/ops/dynamo.py <MODE> <PIPELINE> [ROOT_ID]")
        sys.exit(1)

    mode = sys.argv[1].strip()
    pipeline = sys.argv[2].strip()
    root_id = int(sys.argv[3]) if len(sys.argv) >= 4 else None

    cfg = read_json("station_meta/dynamo/dynamo_config.json")
    if mode not in cfg["modes"]:
        print(f"Invalid mode: {mode}. Allowed: {cfg['modes']}")
        sys.exit(2)

    rid = root_id if root_id is not None else int(cfg["default_root_id"])
    print(f">>> [DYNAMO] mode={mode} root_id={rid} pipeline={pipeline}")
    run_pipeline(cfg, pipeline, mode, rid)
    print(">>> [DYNAMO] DONE")

if __name__ == "__main__":
    main()
PY
chmod +x scripts/ops/dynamo.py

# Dynamo config truth (pipelines)
cat > station_meta/dynamo/dynamo_config.json << 'JSON'
{
  "version": "1.0.0",
  "modes": ["TRIAL-1","TRIAL-2","TRIAL-3","PROD"],
  "default_root_id": 1000,
  "event_log": "station_meta/dynamo/events.jsonl",
  "lock_dir": "station_meta/locks",
  "queue_file": "station_meta/queue/tasks.jsonl",
  "stage_reports_dir": "station_meta/stage_reports",
  "lease_seconds": 120,
  "pipelines": {
    "bootstrap_validate": [
      {"name":"tree_update","cmd":"bash scripts/tree_authority/tree_update.sh"},
      {"name":"tree_broadcast","cmd":"bash scripts/tree_authority/tree_broadcast.sh"}
    ],
    "preflight_guards": [
      {"name":"guard_tree_fresh","cmd":"bash scripts/guards/guard_tree_fresh.sh"},
      {"name":"rooms_broadcast","cmd":"bash scripts/rooms/rooms_broadcast.sh"},
      {"name":"guard_rooms_broadcast","cmd":"bash scripts/guards/guard_rooms_broadcast.sh"},
      {"name":"guard_termux_safe_deps","cmd":"bash scripts/guards/guard_termux_safe_deps.sh"}
    ],
    "plan_progression": [
      {"name":"integrate_report","cmd":"bash scripts/ops/integrate_report.sh"}
    ]
  }
}
JSON

# Ensure ledgers exist
: > station_meta/dynamo/events.jsonl
: > station_meta/queue/tasks.jsonl

# -------------------------------
# 10) ops wrapper (st.sh) - clean, no syntax errors
# -------------------------------
cat > scripts/ops/st.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/station_root"

cmd="${1:-}"; shift || true

case "$cmd" in
  tree)
    sub="${1:-}"; shift || true
    case "$sub" in
      update) bash scripts/tree_authority/tree_update.sh ;;
      broadcast) bash scripts/tree_authority/tree_broadcast.sh ;;
      *) echo "Usage: st tree {update|broadcast}"; exit 1 ;;
    esac
    ;;
  rooms)
    sub="${1:-}"; shift || true
    case "$sub" in
      broadcast) bash scripts/rooms/rooms_broadcast.sh ;;
      *) echo "Usage: st rooms {broadcast}"; exit 1 ;;
    esac
    ;;
  guards)
    bash scripts/guards/guard_tree_fresh.sh
    bash scripts/guards/guard_rooms_broadcast.sh
    bash scripts/guards/guard_termux_safe_deps.sh
    ;;
  integrate)
    bash scripts/ops/integrate_report.sh
    ;;
  dynamo)
    sub="${1:-}"; shift || true
    case "$sub" in
      start)
        mode="${1:-PROD}"; pipeline="${2:-bootstrap_validate}"; root="${3:-1000}"
        python scripts/ops/dynamo.py "$mode" "$pipeline" "$root"
        ;;
      *) echo "Usage: st dynamo start <MODE> <PIPELINE> [ROOT_ID]"; exit 1 ;;
    esac
    ;;
  push)
    rid="${1:-9000}"; shift || true
    msg="${1:-[R${rid}] push}"; shift || true
    bash scripts/ops/stage_commit_push.sh "$rid" "$msg"
    ;;
  *)
    echo "Usage:"
    echo "  st tree update|broadcast"
    echo "  st rooms broadcast"
    echo "  st guards"
    echo "  st integrate"
    echo "  st dynamo start <MODE> <PIPELINE> [ROOT_ID]"
    echo "  st push <ROOT_ID> \"message\""
    exit 1
    ;;
esac
EOF
chmod +x scripts/ops/st.sh

# -------------------------------
# 11) Minimal backend deps (Termux-safe)
# (No FastAPI here to avoid mismatch; we only enforce structure now)
# -------------------------------
mkdir -p backend/app
cat > backend/requirements.txt << 'EOF'
starlette==0.36.3
uvicorn==0.23.2
anyio==3.7.1
EOF
cat > backend/app/__init__.py << 'EOF'
# station backend package
EOF

# NOTE: We do NOT start servers here. This stage is BUILD+TRUTH+OPS only.
cat > backend/app/main.py << 'EOF'
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route

async def health(request):
    return JSONResponse({"ok": True, "service": "station-backend", "engine": "starlette"})

routes = [
    Route("/health", health, methods=["GET"]),
]

app = Starlette(debug=False, routes=routes)
EOF

# -------------------------------
# 12) Execute the full truth pipeline (no server run)
# -------------------------------
echo ">>> [R${ROOT_ID}] Running truth pipelines..."
bash scripts/tree_authority/tree_update.sh
bash scripts/tree_authority/tree_broadcast.sh
bash scripts/rooms/rooms_broadcast.sh
bash scripts/guards/guard_tree_fresh.sh
bash scripts/guards/guard_rooms_broadcast.sh
bash scripts/guards/guard_termux_safe_deps.sh
bash scripts/ops/integrate_report.sh

# -------------------------------
# 13) Single Commit + Single Push (ONE TIME)
# -------------------------------
echo ">>> [R${ROOT_ID}] ONE COMMIT + ONE PUSH..."
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[R${ROOT_ID}] ONE-SHOT build: tree+guards+rooms+dynamo+ops+report"

echo ">>> [R${ROOT_ID}] DONE"
echo "Next verification (local, no run):"
echo "  bash scripts/ops/st.sh tree broadcast"
echo "  bash scripts/ops/st.sh rooms broadcast"
echo "  bash scripts/ops/st.sh guards"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} bootstrap_validate 1000"
echo "  bash scripts/ops/st.sh dynamo start ${MODE} preflight_guards 1800"
echo "  tail -n 50 station_meta/dynamo/events.jsonl"
