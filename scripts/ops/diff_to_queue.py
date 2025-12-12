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
