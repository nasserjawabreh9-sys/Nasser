import json, time, traceback
from pathlib import Path

from app.loop_queue import TASKS_JL, list_tail, try_lock, unlock, log_line, now

ROOT_DIR = Path(__file__).resolve().parents[2]

def _read_all() -> list[dict]:
  try:
    lines = TASKS_JL.read_text(encoding="utf-8").splitlines()
  except Exception:
    return []
  out = []
  for ln in lines:
    try:
      out.append(json.loads(ln))
    except Exception:
      pass
  return out

def _write_all(records: list[dict]):
  TASKS_JL.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records) + ("\n" if records else ""), encoding="utf-8")

def _pick_next(records: list[dict]) -> dict|None:
  # first pending or failed with retries left
  for r in records:
    if r.get("status") == "pending":
      return r
  for r in records:
    if r.get("status") == "failed" and int(r.get("tries", 0)) < int(r.get("max_retries", 0)):
      return r
  return None

def _backoff_seconds(tries: int) -> float:
  # exponential backoff: 1,2,4,8... capped 20
  return min(20.0, float(2 ** max(0, tries)))

def _execute_task(task: dict) -> dict:
  kind = (task.get("kind") or "").strip()
  payload = task.get("payload") or {}

  # Extend here later: git ops, render ops, llm ops, etc.
  if kind == "ping":
    return {"ok": True, "kind": "ping", "ts": now(), "payload": payload}

  if kind == "echo":
    return {"ok": True, "kind": "echo", "payload": payload}

  # unknown
  return {"ok": False, "error": "unknown_task_kind", "kind": kind, "payload": payload}

def run_once() -> dict:
  records = _read_all()
  task = _pick_next(records)
  if not task:
    return {"ok": True, "message": "no_tasks"}

  tid = task["id"]
  if not try_lock(tid):
    return {"ok": True, "message": "locked_skip", "task_id": tid}

  try:
    # backoff if retrying
    tries = int(task.get("tries", 0))
    if task.get("status") == "failed" and tries > 0:
      time.sleep(_backoff_seconds(tries))

    # mark running
    for r in records:
      if r.get("id") == tid:
        r["status"] = "running"
        r["updated_at"] = now()
    _write_all(records)

    # execute
    res = _execute_task(task)

    # mark done/failed
    records = _read_all()
    for r in records:
      if r.get("id") == tid:
        r["tries"] = int(r.get("tries", 0)) + 1
        r["updated_at"] = now()
        if res.get("ok"):
          r["status"] = "done"
          r["result"] = res
          r["last_error"] = ""
        else:
          r["status"] = "failed"
          r["result"] = res
          r["last_error"] = str(res.get("error") or "failed")
    _write_all(records)

    log_line(f"[RUN] {tid} kind={task.get('kind')} status={'done' if res.get('ok') else 'failed'}")
    return {"ok": True, "task_id": tid, "result": res}

  except Exception as e:
    records = _read_all()
    for r in records:
      if r.get("id") == tid:
        r["tries"] = int(r.get("tries", 0)) + 1
        r["updated_at"] = now()
        r["status"] = "failed"
        r["last_error"] = str(e)
        r["result"] = {"ok": False, "error": str(e), "trace": traceback.format_exc()}
    _write_all(records)
    log_line(f"[ERR] {tid} {e}")
    return {"ok": False, "task_id": tid, "error": str(e)}

  finally:
    unlock(tid)

def daemon_loop(interval_sec: float = 2.0):
  log_line("[BOOT] dynamo_worker started")
  while True:
    run_once()
    time.sleep(max(0.5, float(interval_sec)))
