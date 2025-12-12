import json, os, sys, time, subprocess, hashlib
from datetime import datetime, timezone

ROOT_DIR = os.path.expanduser("~/station_root")

def utc_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def sh(cmd: str) -> tuple[int, str]:
    p = subprocess.Popen(cmd, shell=True, cwd=ROOT_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out = []
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
    data = {"name": name, "owner": owner, "acquired_at": now, "lease_seconds": lease_seconds, "renew_count": 0}
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

def stage_commit_push(root_id: int, msg: str) -> tuple[int, str]:
    cmd = f"bash scripts/ops/stage_commit_push.sh {root_id} \"{msg}\""
    return sh(cmd)

def write_stage_report(stage_reports_dir: str, stage_id_hint: str, payload: dict):
    os.makedirs(os.path.join(ROOT_DIR, stage_reports_dir), exist_ok=True)
    fn = f"{stage_id_hint}_{int(time.time())}.json"
    path = os.path.join(ROOT_DIR, stage_reports_dir, fn)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

def run_pipeline(cfg: dict, pipeline_name: str, mode: str, root_id: int):
    event_log = cfg["event_log"]
    lock_dir = cfg["lock_dir"]
    lease = int(cfg["lease_seconds"])
    owner = f"dynamo::{mode}::R{root_id}"

    # Single-writer locks for truth files
    locks = ["tree", "bindings", "env", "stage"]
    for ln in locks:
        acquire_lock(lock_dir, ln, owner, lease)

    try:
        steps = cfg["pipelines"].get(pipeline_name, [])
        if not steps:
            raise RuntimeError(f"PIPELINE_NOT_FOUND:{pipeline_name}")

        for i, step in enumerate(steps, start=1):
            e_start = {
                "ts": utc_now(),
                "mode": mode,
                "root_id": root_id,
                "pipeline": pipeline_name,
                "step_index": i,
                "step_name": step["name"],
                "status": "started",
                "cmd": step["cmd"]
            }
            write_event(event_log, e_start)

            rc, out = sh(step["cmd"])

            e_end = {
                "ts": utc_now(),
                "mode": mode,
                "root_id": root_id,
                "pipeline": pipeline_name,
                "step_index": i,
                "step_name": step["name"],
                "status": "succeeded" if rc == 0 else "failed",
                "rc": rc,
                "out_sha256": sha256_text(out[-2000:])  # last 2k chars hash (ledger safe)
            }
            write_event(event_log, e_end)

            if rc != 0:
                raise RuntimeError(f"STEP_FAILED:{pipeline_name}:{step['name']}")

        # Stage commit push (ledger)
        stage_msg = f"[{mode}] Dynamo pipeline={pipeline_name}"
        rc2, out2 = stage_commit_push(root_id, stage_msg)

        write_stage_report(cfg["stage_reports_dir"], f"{mode}_R{root_id}", {
            "ts": utc_now(),
            "mode": mode,
            "root_id": root_id,
            "pipeline": pipeline_name,
            "stage_commit_rc": rc2,
            "stage_commit_out_tail": out2[-1200:]
        })

        if rc2 != 0:
            raise RuntimeError("STAGE_COMMIT_PUSH_FAILED")

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
