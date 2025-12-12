#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1400"
MODE="${1:-PROD}"
MAX_WORKERS="${2:-3}"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo ">>> [R${ROOT_ID}] Room Runner + Concurrency(${MAX_WORKERS}) + Merge Report (mode=${MODE})"

mkdir -p scripts/rooms scripts/ops station_meta/rooms station_meta/merge_reports station_meta/queue

# --- 1) Room Runner (truth) ---
cat > scripts/rooms/room_runner.py << 'PY'
import json, os, sys, time, subprocess, threading
from queue import Queue
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
MAP_PATH=os.path.join(ROOT,"specs/pipelines/rooms_pipeline_map.json")
CFG_PATH=os.path.join(ROOT,"station_meta/dynamo/dynamo_config.json")
MERGE_DIR=os.path.join(ROOT,"station_meta/merge_reports")
RUN_DIR=os.path.join(ROOT,"station_meta/rooms")
LOCK_DIR=os.path.join(ROOT,"station_meta/locks")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def load_json(p):
    with open(p,"r",encoding="utf-8") as f: return json.load(f)

def sh(cmd):
    p=subprocess.Popen(cmd, shell=True, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out=[]
    for line in p.stdout:
        out.append(line)
    p.wait()
    return p.returncode, "".join(out)

def lock_path(name): return os.path.join(LOCK_DIR, f"{name}.lock")

def acquire(lock_name):
    os.makedirs(LOCK_DIR, exist_ok=True)
    lp=lock_path(lock_name)
    if os.path.exists(lp): return False
    with open(lp,"w",encoding="utf-8") as f: f.write(utc())
    return True

def release(lock_name):
    lp=lock_path(lock_name)
    if os.path.exists(lp): os.remove(lp)

def run_dynamo(mode, pipeline, root_id):
    cmd=f"bash scripts/ops/st.sh dynamo start {mode} {pipeline} {root_id}"
    return sh(cmd)

def room_task(room, mode, pipeline, root_id, required_locks):
    # Acquire all locks for the task (strict all-or-nothing)
    acquired=[]
    try:
        for lk in required_locks:
            if not acquire(lk):
                return {"room":room,"pipeline":pipeline,"root_id":root_id,"status":"skipped_lock_busy","lock":lk,"ts":utc()}
            acquired.append(lk)

        rc, out = run_dynamo(mode, pipeline, root_id)
        st="ok" if rc==0 else "fail"
        tail=out[-1200:]
        return {"room":room,"pipeline":pipeline,"root_id":root_id,"status":st,"rc":rc,"out_tail":tail,"ts":utc()}
    finally:
        for lk in reversed(acquired):
            release(lk)

def build_plan(mapj):
    rooms=mapj["rooms"]
    plan=[]
    for room, spec in rooms.items():
        locks=spec.get("locks",[])
        pipes=spec.get("pipelines",[])
        for p in pipes:
            plan.append({"room":room,"pipeline":p,"locks":locks})
    return plan

def write_merge_report(mode, root_id, plan, results):
    os.makedirs(MERGE_DIR, exist_ok=True)
    fn=os.path.join(MERGE_DIR, f"merge_R{root_id}_{int(time.time())}.json")
    payload={
        "generated_utc": utc(),
        "mode": mode,
        "root_id": root_id,
        "plan": plan,
        "results": results,
        "summary": {
            "ok": sum(1 for r in results if r.get("status")=="ok"),
            "fail": sum(1 for r in results if r.get("status")=="fail"),
            "skipped_lock_busy": sum(1 for r in results if r.get("status")=="skipped_lock_busy"),
        }
    }
    with open(fn,"w",encoding="utf-8") as f:
        json.dump(payload,f,ensure_ascii=False,indent=2)
    return fn, payload["summary"]

def main():
    if len(sys.argv)<3:
        print("Usage: python scripts/rooms/room_runner.py <MODE> <ROOT_ID> [MAX_WORKERS]")
        sys.exit(2)
    mode=sys.argv[1].strip()
    root_id=int(sys.argv[2])
    max_workers=int(sys.argv[3]) if len(sys.argv)>=4 else 3

    mapj=load_json(MAP_PATH)
    plan=build_plan(mapj)

    # Prepare run dir
    os.makedirs(RUN_DIR, exist_ok=True)
    run_id=f"{mode}_R{root_id}_{int(time.time())}"
    run_path=os.path.join(RUN_DIR, f"{run_id}.json")
    with open(run_path,"w",encoding="utf-8") as f:
        json.dump({"run_id":run_id,"mode":mode,"root_id":root_id,"plan":plan,"ts":utc()}, f, ensure_ascii=False, indent=2)

    q=Queue()
    for item in plan: q.put(item)

    results=[]
    res_lock=threading.Lock()

    def worker(idx):
        while True:
            try:
                item=q.get_nowait()
            except:
                return
            r=room_task(item["room"], mode, item["pipeline"], root_id, item["locks"])
            with res_lock:
                results.append(r)
            q.task_done()

    threads=[]
    for i in range(max_workers):
        t=threading.Thread(target=worker, args=(i+1,), daemon=True)
        t.start()
        threads.append(t)

    q.join()
    for t in threads: t.join(timeout=0.1)

    rep, summ = write_merge_report(mode, root_id, plan, results)
    print(">>> [ROOM_RUNNER] DONE")
    print(f">>> merge_report={rep}")
    print(f">>> summary={summ}")

if __name__=="__main__":
    main()
PY
chmod +x scripts/rooms/room_runner.py

# --- 2) Add st wrapper command: st rooms run <MODE> <ROOT_ID> [MAX_WORKERS] ---
# Ensure st.sh exists and has a basic structure; if not, do minimal safe wrapper
if [ ! -f scripts/ops/st.sh ]; then
  cat > scripts/ops/st.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cmd="${1:-}"; shift || true
if [ "$cmd" = "help" ] || [ -z "$cmd" ]; then
  echo "Usage: st <dynamo|rooms|status> ..."
  exit 0
fi
if [ "$cmd" = "dynamo" ]; then
  sub="${1:-}"; shift || true
  if [ "$sub" = "start" ]; then
    mode="${1:-PROD}"; pipeline="${2:-bootstrap_validate}"; root="${3:-1000}"
    python scripts/ops/dynamo.py "$mode" "$pipeline" "$root"
    exit 0
  fi
fi
echo "Unknown command. Try: st help"
exit 1
EOF
  chmod +x scripts/ops/st.sh
fi

# Append rooms handler safely (only if not present)
grep -q 'cmd" = "rooms"' scripts/ops/st.sh || cat >> scripts/ops/st.sh << 'EOF'

if [ "$cmd" = "rooms" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    run)
      mode="${1:-PROD}"; root="${2:-1400}"; workers="${3:-3}"
      python scripts/rooms/room_runner.py "$mode" "$root" "$workers"
      ;;
    *)
      echo "Usage: st rooms run <MODE> <ROOT_ID> [MAX_WORKERS]"
      echo "Example: st rooms run PROD 1400 3"
      exit 1
      ;;
  esac
  exit 0
fi
EOF

# --- 3) Run Room Runner once (no service start required) ---
bash scripts/ops/st.sh rooms run "${MODE}" "${ROOT_ID}" "${MAX_WORKERS}"

# --- 4) Snapshot status (events→status.json) ---
bash scripts/ops/st.sh dynamo start "${MODE}" status_snapshot "${ROOT_ID}" || true

# --- 5) Stage/commit/push with tag ---
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} RoomRunner concurrency+merge-report"

echo ">>> [R${ROOT_ID}] DONE"
echo "Artifacts:"
echo "  - station_meta/merge_reports/"
echo "  - station_meta/rooms/"
echo "  - station_meta/status/status.json"
