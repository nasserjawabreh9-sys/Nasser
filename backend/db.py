import json
import sqlite3
from pathlib import Path
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

DB_PATH = Path(__file__).parent / "data" / "station.db"
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def conn() -> sqlite3.Connection:
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c

def init_db() -> None:
    with conn() as c:
        c.execute("""
        CREATE TABLE IF NOT EXISTS keys (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          data TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        """)
        c.execute("""
        CREATE TABLE IF NOT EXISTS events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
        """)
        c.commit()

def save_keys(data: Dict[str, Any]) -> Dict[str, Any]:
    init_db()
    payload = json.dumps(data, ensure_ascii=True)
    with conn() as c:
        c.execute(
            "INSERT OR REPLACE INTO keys (id, data, updated_at) VALUES (1, ?, ?)",
            (payload, _utc_now_iso()),
        )
        c.commit()
    return {"ok": True}

def load_keys() -> Dict[str, Any]:
    init_db()
    with conn() as c:
        row = c.execute("SELECT data, updated_at FROM keys WHERE id=1").fetchone()
    if not row:
        return {"ok": True, "keys": {}, "updated_at": None}
    try:
        data = json.loads(row["data"])
    except Exception:
        data = {}
    return {"ok": True, "keys": data, "updated_at": row["updated_at"]}

def push_event(ev_type: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    init_db()
    p = json.dumps(payload, ensure_ascii=True)
    with conn() as c:
        cur = c.execute(
            "INSERT INTO events (type, payload, created_at) VALUES (?, ?, ?)",
            (ev_type, p, _utc_now_iso()),
        )
        c.commit()
        return {"ok": True, "id": int(cur.lastrowid)}

def list_events(limit: int = 50, after_id: int = 0) -> Dict[str, Any]:
    init_db()
    limit = max(1, min(int(limit), 200))
    after_id = max(0, int(after_id))
    with conn() as c:
        rows = c.execute(
            "SELECT id, type, payload, created_at FROM events WHERE id > ? ORDER BY id DESC LIMIT ?",
            (after_id, limit),
        ).fetchall()
    out: List[Dict[str, Any]] = []
    for r in rows:
        try:
            payload = json.loads(r["payload"])
        except Exception:
            payload = {}
        out.append(
            {"id": int(r["id"]), "type": r["type"], "payload": payload, "created_at": r["created_at"]}
        )
    return {"ok": True, "events": out}
