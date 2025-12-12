#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1600"
MODE="${1:-PROD}"
MAXC="${2:-2}"   # حد التزامن الافتراضي (Termux-friendly)

echo ">>> [R${ROOT_ID}] Concurrency + Rooms + Deadlock + MergeGate (mode=${MODE} max=${MAXC})"

mkdir -p station_meta/{concurrency,queue,locks,stage_reports} scripts/{rooms,ops,guards}

# ---------------------------
# 1) Rooms registry (truth)
# ---------------------------
cat > station_meta/concurrency/rooms.json << JSON
{
  "version": "0.1.0",
  "max_concurrency": ${MAXC},
  "rooms": {
    "R1_TREE_AUTHORITY": {"lock":"room_R1_tree", "default_pipeline":"bootstrap_validate", "root_id":1000},
    "R2_BACKEND":        {"lock":"room_R2_backend", "default_pipeline":"termux_env_prepare_backend", "root_id":2000},
    "R3_AI_AGENT":       {"lock":"room_R3_ai", "default_pipeline":"agent_validate", "root_id":3000},
    "R4_FRONTEND":       {"lock":"room_R4_frontend", "default_pipeline":"frontend_build_check", "root_id":4000},
    "R5_OPS":            {"lock":"room_R5_ops", "default_pipeline":"stage_only", "root_id":5000}
  }
}
JSON

# ---------------------------
# 2) Global semaphore (truth)
# ---------------------------
cat > station_meta/concurrency/semaphore.json << JSON
{
  "version": "0.1.0",
  "max_concurrency": ${MAXC},
  "active": [],
  "updated_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON

# ---------------------------
# 3) Deadlock / lock cleaner
# ---------------------------
cat > scripts/ops/lock_cleaner.py << 'PY'
import os, json, time
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
LOCK_DIR=os.path.join(ROOT,"station_meta","locks")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def main():
    if not os.path.isdir(LOCK_DIR):
        print(">>> [lock_cleaner] no lock dir")
        return
    now=int(time.time())
    removed=0
    for fn in os.listdir(LOCK_DIR):
        if not fn.endswith(".lock.json"): 
            continue
        path=os.path.join(LOCK_DIR,fn)
        try:
            data=json.load(open(path,"r",encoding="utf-8"))
            acquired=int(data.get("acquired_at",0))
            lease=int(data.get("lease_seconds",0))
            exp=acquired+lease
            if lease>0 and now>exp+5:
                os.remove(path)
                removed+=1
        except Exception:
            # corrupted lock -> remove
            try:
                os.remove(path)
                removed+=1
            except Exception:
                pass
    print(f">>> [lock_cleaner] removed={removed} ts={utc()}")

if __name__=="__main__":
    main()
PY
chmod +x scripts/ops/lock_cleaner.py

# ---------------------------
# 4) Room runner (concurrency-safe)
# ---------------------------
cat > scripts/rooms/room_runner.py << 'PY'
import os, json, time, subprocess, threading
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
LOCK_DIR=os.path.join(ROOT,"station_meta","locks")
SEMA=os.path.join(ROOT,"station_meta","concurrency","semaphore.json")
ROOMS=os.path.join(ROOT,"station_meta","concurrency","rooms.json")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def read_json(p):
    return json.load(open(p,"r",encoding="utf-8"))

def write_json(p, obj):
    with open(p,"w",encoding="utf-8") as f:
        json.dump(obj,f,ensure_ascii=False,indent=2)

def lock_path(name):
    return os.path.join(LOCK_DIR, f"{name}.lock.json")

def acquire_lock(name, owner, lease=120):
    os.makedirs(LOCK_DIR, exist_ok=True)
    lp=lock_path(name)
    now=int(time.time())
    if os.path.exists(lp):
        data=read_json(lp)
        exp=int(data.get("acquired_at",0))+int(data.get("lease_seconds",0))
        if now < exp:
            raise RuntimeError(f"LOCK_BUSY:{name}:owned_by={data.get('owner')}")
    write_json(lp, {"name":name,"owner":owner,"acquired_at":now,"lease_seconds":lease,"ts":utc()})

def release_lock(name, owner):
    lp=lock_path(name)
    if not os.path.exists(lp): 
        return
    data=read_json(lp)
    if data.get("owner") != owner:
        raise RuntimeError(f"LOCK_OWNER_MISMATCH:{name}")
    os.remove(lp)

def sema_acquire(owner):
    # single writer lock on semaphore itself
    acquire_lock("semaphore", owner, lease=120)
    try:
        s=read_json(SEMA)
        maxc=int(s.get("max_concurrency",1))
        active=list(s.get("active",[]))
        if owner in active:
            return True
        if len(active) >= maxc:
            return False
        active.append(owner)
        s["active"]=active
        s["updated_utc"]=utc()
        write_json(SEMA, s)
        return True
    finally:
        release_lock("semaphore", owner)

def sema_release(owner):
    acquire_lock("semaphore", owner, lease=120)
    try:
        s=read_json(SEMA)
        active=list(s.get("active",[]))
        if owner in active:
            active=[x for x in active if x!=owner]
            s["active"]=active
            s["updated_utc"]=utc()
            write_json(SEMA, s)
    finally:
        release_lock("semaphore", owner)

def sh(cmd):
    p=subprocess.Popen(cmd, shell=True, cwd=ROOT)
    p.wait()
    return p.returncode

def run_room(room_key, mode, pipeline, root_id):
    owner=f"{room_key}::{mode}::R{root_id}::{int(time.time())}"
    rooms=read_json(ROOMS)["rooms"]
    lock_name=rooms[room_key]["lock"]

    # room lock (single-writer per room)
    acquire_lock(lock_name, owner, lease=180)
    try:
        # global semaphore
        for _ in range(120):
            if sema_acquire(owner):
                break
            time.sleep(1)
        else:
            raise RuntimeError("SEMAPHORE_TIMEOUT")

        try:
            cmd=f"bash scripts/ops/st.sh dynamo start {mode} {pipeline} {root_id}"
            rc=sh(cmd)
            return rc
        finally:
            sema_release(owner)
    finally:
        release_lock(lock_name, owner)

def main():
    import argparse
    ap=argparse.ArgumentParser()
    ap.add_argument("--mode", default="PROD")
    ap.add_argument("--room", required=True)
    ap.add_argument("--pipeline", required=True)
    ap.add_argument("--root", type=int, required=True)
    args=ap.parse_args()

    rc=run_room(args.room, args.mode, args.pipeline, args.root)
    print(f">>> [room_runner] room={args.room} rc={rc}")
    raise SystemExit(rc)

if __name__=="__main__":
    main()
PY
chmod +x scripts/rooms/room_runner.py

# ---------------------------
# 5) Concurrent Queue Runner v2 (uses Rooms + semaphore)
# ---------------------------
cat > scripts/ops/queue_runner_v2.py << 'PY'
import os, json, time, threading, subprocess
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
Q=os.path.join(ROOT,"station_meta/queue/tasks.jsonl")
PROCESSED=os.path.join(ROOT,"station_meta/queue/processed.jsonl")
ROOMS=os.path.join(ROOT,"station_meta/concurrency/rooms.json")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

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

def sh(cmd):
    p=subprocess.Popen(cmd, shell=True, cwd=ROOT)
    p.wait()
    return p.returncode

def map_task_to_room_key(t):
    room=t.get("room","R5")
    if room=="R1": return "R1_TREE_AUTHORITY"
    if room=="R2": return "R2_BACKEND"
    if room=="R3": return "R3_AI_AGENT"
    if room=="R4": return "R4_FRONTEND"
    return "R5_OPS"

def worker(job, results):
    room_key, mode, pipeline, root_id, items = job
    cmd=f"python scripts/rooms/room_runner.py --mode {mode} --room {room_key} --pipeline {pipeline} --root {root_id}"
    rc=sh(cmd)
    results.append((job, rc))

    for it in items:
        it2=dict(it)
        it2["processed_utc"]=utc()
        it2["status"]="done" if rc==0 else "failed"
        it2["run_rc"]=rc
        append(PROCESSED, it2)

def main():
    mode=os.environ.get("ST_MODE","PROD")
    tasks=load_lines(Q)
    tasks=[t for t in tasks if t.get("status")=="queued"]
    if not tasks:
        print(">>> [queue_runner_v2] empty queue")
        return

    # stop-the-world guard before running anything
    rcg=sh("bash scripts/guards/guard_ops_gate.sh")
    if rcg!=0:
        print(">>> [queue_runner_v2] GUARD FAILED -> stop")
        return

    rooms_cfg=json.load(open(ROOMS,"r",encoding="utf-8"))
    maxc=int(rooms_cfg.get("max_concurrency",1))

    # group by (room_key,pipeline)
    groups={}
    for t in tasks:
        room_key=map_task_to_room_key(t)
        pipeline=t.get("pipeline","stage_only")
        root_id=int(rooms_cfg["rooms"][room_key]["root_id"])
        key=(room_key,pipeline,root_id)
        groups.setdefault(key, []).append(t)

    jobs=[(rk,mode,pip,rid,items) for (rk,pip,rid), items in groups.items()]

    print(f">>> [queue_runner_v2] jobs={len(jobs)} max_concurrency={maxc}")

    results=[]
    threads=[]
    sem=threading.Semaphore(maxc)

    def wrapped(job):
        with sem:
            worker(job, results)

    for job in jobs:
        th=threading.Thread(target=wrapped, args=(job,), daemon=True)
        threads.append(th)
        th.start()

    for th in threads:
        th.join()

    failed=[(j,rc) for (j,rc) in results if rc!=0]
    print(f">>> [queue_runner_v2] done failed={len(failed)}")
    if failed:
        for (j,rc) in failed[:10]:
            print(" -", j[0], j[2], "rc=", rc)

if __name__=="__main__":
    main()
PY
chmod +x scripts/ops/queue_runner_v2.py

# ---------------------------
# 6) Merge Gate (no push if any failure)
# ---------------------------
cat > scripts/ops/merge_gate.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo ">>> [merge_gate] running stop-the-world checks..."

# Guard must pass
bash scripts/guards/guard_ops_gate.sh

# If processed has failures -> block
PROCESSED="station_meta/queue/processed.jsonl"
if [ -f "$PROCESSED" ]; then
  if grep -q '"status":"failed"' "$PROCESSED"; then
    echo "☠️ [merge_gate] BLOCKED: found failed tasks in processed queue."
    echo "Fix failures then rerun queue."
    exit 93
  fi
fi

echo ">>> [merge_gate] OK"
EOF
chmod +x scripts/ops/merge_gate.sh

# ---------------------------
# 7) st commands: lock clean / queue v2 / merge gate / rooms
# ---------------------------
grep -q 'cmd" = "locks"' scripts/ops/st.sh || cat >> scripts/ops/st.sh << 'EOF'

if [ "$cmd" = "locks" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    clean)
      python scripts/ops/lock_cleaner.py
      ;;
    *)
      echo "Usage: st locks clean"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "queue2" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    run)
      export ST_MODE="${1:-PROD}"
      python scripts/ops/queue_runner_v2.py
      ;;
    *)
      echo "Usage: st queue2 run <MODE>"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "merge" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    gate)
      bash scripts/ops/merge_gate.sh
      ;;
    *)
      echo "Usage: st merge gate"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "rooms" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    show)
      cat station_meta/concurrency/rooms.json
      ;;
    *)
      echo "Usage: st rooms show"
      exit 1
      ;;
  esac
  exit 0
fi
EOF

# ---------------------------
# 8) Stage/Commit/Push R1600
# ---------------------------
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} Concurrency+Rooms+Deadlock+MergeGate"
echo ">>> [R${ROOT_ID}] DONE"

echo "Use (plan-only):"
echo "  st locks clean"
echo "  st rooms show"
echo "  st queue autodiff"
echo "  st queue2 run PROD"
echo "  st merge gate"
