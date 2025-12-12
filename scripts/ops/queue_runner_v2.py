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
