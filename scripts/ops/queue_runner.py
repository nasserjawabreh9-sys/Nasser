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
