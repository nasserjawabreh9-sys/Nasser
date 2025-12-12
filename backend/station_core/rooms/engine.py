import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
import sqlite3
from typing import Any, Dict, List, Optional

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
DB_PATH = DATA_DIR / "station.db"

def utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def conn() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    return c

def init_rooms_db() -> None:
    with conn() as c:
        c.execute("""
        CREATE TABLE IF NOT EXISTS rooms (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
        """)
        c.execute("""
        CREATE TABLE IF NOT EXISTS room_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          room_id TEXT NOT NULL,
          role TEXT NOT NULL,
          text TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
        """)
        c.commit()

@dataclass
class Room:
    id: str
    title: str
    created_at: str

def list_rooms() -> List[Dict[str, Any]]:
    init_rooms_db()
    with conn() as c:
        rows = c.execute("SELECT id, title, created_at FROM rooms ORDER BY created_at DESC").fetchall()
    return [{"id": r["id"], "title": r["title"], "created_at": r["created_at"]} for r in rows]

def ensure_room(room_id: str, title: Optional[str] = None) -> Dict[str, Any]:
    init_rooms_db()
    title = title or f"Room {room_id}"
    with conn() as c:
        row = c.execute("SELECT id FROM rooms WHERE id=?", (room_id,)).fetchone()
        if not row:
            c.execute("INSERT INTO rooms (id, title, created_at) VALUES (?, ?, ?)", (room_id, title, utc_iso()))
            c.commit()
    return {"ok": True, "id": room_id, "title": title}

def rename_room(room_id: str, title: str) -> Dict[str, Any]:
    init_rooms_db()
    with conn() as c:
        c.execute("UPDATE rooms SET title=? WHERE id=?", (title, room_id))
        c.commit()
    return {"ok": True}

def add_message(room_id: str, role: str, text: str) -> Dict[str, Any]:
    init_rooms_db()
    ensure_room(room_id)
    with conn() as c:
        cur = c.execute(
            "INSERT INTO room_messages (room_id, role, text, created_at) VALUES (?, ?, ?, ?)",
            (room_id, role, text, utc_iso()),
        )
        c.commit()
    return {"ok": True, "id": int(cur.lastrowid)}

def get_messages(room_id: str, limit: int = 50) -> List[Dict[str, Any]]:
    init_rooms_db()
    limit = max(1, min(int(limit), 500))
    with conn() as c:
        rows = c.execute(
            "SELECT id, room_id, role, text, created_at FROM room_messages WHERE room_id=? ORDER BY id DESC LIMIT ?",
            (room_id, limit),
        ).fetchall()
    out: List[Dict[str, Any]] = []
    for r in rows:
        out.append({
            "id": int(r["id"]),
            "room_id": r["room_id"],
            "role": r["role"],
            "text": r["text"],
            "created_at": r["created_at"],
        })
    return list(reversed(out))
