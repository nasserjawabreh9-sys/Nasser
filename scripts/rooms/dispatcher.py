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
