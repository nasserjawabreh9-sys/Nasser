#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1200"
MODE="${1:-PROD}"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo ">>> [R${ROOT_ID}] Enable Guards + Rooms Queue + Concurrency (mode=${MODE})"

# --- Ensure dirs ---
mkdir -p scripts/ops scripts/rooms station_meta/queue station_meta/locks station_meta/stage_reports

# --- Queue files ---
[ -f station_meta/queue/tasks.jsonl ] || : > station_meta/queue/tasks.jsonl

# --- Guards Runner (preflight) ---
cat > scripts/ops/run_guards.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

echo ">>> [GUARDS] tree_guard"
bash scripts/guards/tree_guard.sh

echo ">>> [GUARDS] binding_guard"
bash scripts/guards/binding_guard.sh

echo ">>> [GUARDS] env_guard"
bash scripts/guards/env_guard.sh

echo ">>> [GUARDS] stage_guard"
bash scripts/guards/stage_guard.sh

echo ">>> [GUARDS] ALL OK"
EOF
chmod +x scripts/ops/run_guards.sh

# --- Dispatcher: assigns tasks to rooms with locks ---
cat > scripts/rooms/dispatcher.py << 'PY'
import json, os, time, subprocess, sys
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
QUEUE=os.path.join(ROOT,"station_meta/queue/tasks.jsonl")
LOCKS=os.path.join(ROOT,"station_meta/locks")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def acquire(name):
    os.makedirs(LOCKS, exist_ok=True)
    p=os.path.join(LOCKS,f"{name}.lock")
    if os.path.exists(p): return False
    open(p,"w").write(utc())
    return True

def release(name):
    p=os.path.join(LOCKS,f"{name}.lock")
    if os.path.exists(p): os.remove(p)

def sh(cmd):
    p=subprocess.Popen(cmd, shell=True, cwd=ROOT)
    return p.wait()

def read_tasks():
    if not os.path.exists(QUEUE): return []
    with open(QUEUE,"r",encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]

def write_tasks(ts):
    with open(QUEUE,"w",encoding="utf-8") as f:
        for t in ts: f.write(json.dumps(t,ensure_ascii=False)+"\n")

def main():
    tasks=read_tasks()
    if not tasks:
        print("DISPATCHER: no tasks")
        return
    rest=[]
    for t in tasks:
        room=t["room"]
        lock=t["lock"]
        cmd=t["cmd"]
        if not acquire(lock):
            rest.append(t); continue
        try:
            print(f">>> DISPATCH {room} cmd={cmd}")
            rc=sh(cmd)
            if rc!=0: raise RuntimeError(f"ROOM_FAIL:{room}")
        finally:
            release(lock)
    write_tasks(rest)

if __name__=="__main__":
    main()
PY
chmod +x scripts/rooms/dispatcher.py

# --- Extend Dynamo: preflight guards before every pipeline ---
python - << 'PY'
import json, os
cfg_path="station_meta/dynamo/dynamo_config.json"
cfg=json.load(open(cfg_path,"r",encoding="utf-8"))
cfg["preflight"]="bash scripts/ops/run_guards.sh"
json.dump(cfg, open(cfg_path,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(">>> [DYNAMO] preflight guards enabled")
PY

# --- Patch Dynamo to call preflight ---
sed -i 's/run_pipeline(cfg, pipeline, mode, rid)/os.system(cfg.get("preflight","true")); run_pipeline(cfg, pipeline, mode, rid)/' scripts/ops/dynamo.py

# --- Seed example tasks for rooms (safe stubs) ---
cat >> station_meta/queue/tasks.jsonl << EOF
{"room":"R1","lock":"tree","cmd":"bash scripts/tree_authority/tree_update.sh"}
{"room":"R1","lock":"bindings","cmd":"bash scripts/tree_authority/tree_broadcast.sh"}
{"room":"R2","lock":"env","cmd":"echo ENV_OK"}
{"room":"R5","lock":"stage","cmd":"bash scripts/ops/stage_commit_push.sh 1200 \"[${MODE}] R1200 room-dispatch\""}
EOF

# --- Stage commit & push ---
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} Guards+Queue+Concurrency enabled"

echo ">>> [R${ROOT_ID}] DONE"
