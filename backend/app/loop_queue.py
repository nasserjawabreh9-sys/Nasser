import json, time, os, uuid
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
QUEUE_DIR = ROOT_DIR / "station_meta" / "queue"
TASKS_JL = QUEUE_DIR / "tasks.jsonl"
LOCK_DIR = QUEUE_DIR / "locks"
LOG_DIR  = ROOT_DIR / "station_meta" / "logs"

def _ensure():
  QUEUE_DIR.mkdir(parents=True, exist_ok=True)
  LOCK_DIR.mkdir(parents=True, exist_ok=True)
  LOG_DIR.mkdir(parents=True, exist_ok=True)
  if not TASKS_JL.exists():
    TASKS_JL.write_text("", encoding="utf-8")

def now() -> float:
  return time.time()

def _append(rec: dict):
  _ensure()
  with TASKS_JL.open("a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")

def submit(kind: str, payload: dict, max_retries: int = 3) -> dict:
  tid = str(uuid.uuid4())
  rec = {
    "id": tid,
    "kind": kind,
    "payload": payload or {},
    "status": "pending",
    "created_at": now(),
    "updated_at": now(),
    "tries": 0,
    "max_retries": int(max_retries),
    "last_error": ""
  }
  _append(rec)
  return rec

def list_tail(limit: int = 200) -> list[dict]:
  _ensure()
  try:
    lines = TASKS_JL.read_text(encoding="utf-8").splitlines()
  except Exception:
    return []
  out = []
  for ln in lines[-limit:]:
    try:
      out.append(json.loads(ln))
    except Exception:
      pass
  return out

def _lock_path(tid: str) -> Path:
  return LOCK_DIR / f"{tid}.lock"

def try_lock(tid: str) -> bool:
  _ensure()
  p = _lock_path(tid)
  try:
    fd = os.open(str(p), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    os.write(fd, str(os.getpid()).encode("utf-8"))
    os.close(fd)
    return True
  except Exception:
    return False

def unlock(tid: str):
  try:
    _lock_path(tid).unlink(missing_ok=True)  # py3.11+
  except Exception:
    pass

def log_line(msg: str):
  _ensure()
  p = LOG_DIR / "dynamo_worker.log"
  with p.open("a", encoding="utf-8") as f:
    f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")
