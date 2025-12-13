import os, time, json, sqlite3
from typing import Optional, Dict, Any, List, Tuple

DB_PATH = os.getenv("STATION_AGENT_DB", os.path.join(os.path.dirname(__file__), "agent_queue.sqlite3"))

def _db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("""
    CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        runner_id TEXT,
        task_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        result_json TEXT,
        error_text TEXT
    )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status, created_at)")
    conn.commit()
    return conn

def _now() -> int:
    return int(time.time())

def submit_task(task_type: str, payload: Dict[str, Any]) -> int:
    conn = _db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO tasks(created_at, status, runner_id, task_type, payload_json) VALUES(?, 'queued', NULL, ?, ?)",
        (_now(), task_type, json.dumps(payload, ensure_ascii=True)),
    )
    conn.commit()
    tid = int(cur.lastrowid)
    conn.close()
    return tid

def claim_next(runner_id: str) -> Optional[Tuple[int, Dict[str, Any], str]]:
    conn = _db()
    cur = conn.cursor()
    cur.execute("SELECT id, payload_json, task_type FROM tasks WHERE status='queued' ORDER BY created_at ASC LIMIT 1")
    row = cur.fetchone()
    if not row:
        conn.close()
        return None
    tid, payload_json, task_type = row
    cur.execute("UPDATE tasks SET status='running', runner_id=? WHERE id=? AND status='queued'", (runner_id, tid))
    conn.commit()
    cur.execute("SELECT status FROM tasks WHERE id=?", (tid,))
    st = cur.fetchone()
    if not st or st[0] != "running":
        conn.close()
        return None
    conn.close()
    return int(tid), json.loads(payload_json), str(task_type)

def set_result(tid: int, ok: bool, result: Dict[str, Any], error_text: str = "") -> None:
    conn = _db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE tasks SET status=?, result_json=?, error_text=? WHERE id=?",
        ("done" if ok else "failed", json.dumps(result, ensure_ascii=True), error_text, tid),
    )
    conn.commit()
    conn.close()

def get_task(tid: int) -> Optional[Dict[str, Any]]:
    conn = _db()
    cur = conn.cursor()
    cur.execute("SELECT id, created_at, status, runner_id, task_type, payload_json, result_json, error_text FROM tasks WHERE id=?", (tid,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "id": row[0],
        "created_at": row[1],
        "status": row[2],
        "runner_id": row[3],
        "task_type": row[4],
        "payload": json.loads(row[5]) if row[5] else None,
        "result": json.loads(row[6]) if row[6] else None,
        "error": row[7],
    }

def list_recent(limit: int = 25) -> List[Dict[str, Any]]:
    conn = _db()
    cur = conn.cursor()
    cur.execute("SELECT id FROM tasks ORDER BY id DESC LIMIT ?", (int(limit),))
    ids = [r[0] for r in cur.fetchall()]
    conn.close()
    out = []
    for tid in ids:
        t = get_task(int(tid))
        if t:
            out.append(t)
    return out
