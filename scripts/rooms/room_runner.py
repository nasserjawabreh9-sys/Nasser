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
