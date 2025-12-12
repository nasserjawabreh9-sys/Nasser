#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BE="$HOME/station_root/backend"
[ -d "$BE" ] || { echo "Missing backend dir: $BE"; exit 1; }

mkdir -p "$BE/data"
mkdir -p "$BE/app"

# --- db.py (SQLite helper) ---
cat > "$BE/db.py" <<'PY'
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
PY

# --- Ensure requirements include sqlite-safe deps only (sqlite is stdlib) ---
REQ="$BE/requirements.txt"
if [ ! -f "$REQ" ]; then
  cat > "$REQ" <<'REQS'
fastapi==0.110.3
uvicorn[standard]==0.30.6
pydantic==2.8.2
python-multipart==0.0.9
requests==2.32.3
REQS
else
  grep -qi '^fastapi' "$REQ" || echo 'fastapi==0.110.3' >>"$REQ"
  grep -qi '^uvicorn' "$REQ" || echo 'uvicorn[standard]==0.30.6' >>"$REQ"
  grep -qi '^pydantic' "$REQ" || echo 'pydantic==2.8.2' >>"$REQ"
  grep -qi '^python-multipart' "$REQ" || echo 'python-multipart==0.0.9' >>"$REQ"
  grep -qi '^requests' "$REQ" || echo 'requests==2.32.3' >>"$REQ"
fi

# --- Patch app.py (create if missing) ---
APP="$BE/app.py"
if [ ! -f "$APP" ]; then
  cat > "$APP" <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="station-backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"ok": True, "service": "station-backend"}
PY
fi

# Append endpoints safely (idempotent marker)
MARKER="# --- STATION_DB_ENDPOINTS_V1 ---"
if ! grep -q "$MARKER" "$APP"; then
  cat >> "$APP" <<'PY'

# --- STATION_DB_ENDPOINTS_V1 ---
from typing import Any, Dict
from db import init_db, load_keys, save_keys, list_events, push_event

@app.on_event("startup")
def _startup():
    init_db()

@app.get("/keys")
def get_keys():
    return load_keys()

@app.post("/keys")
def post_keys(payload: Dict[str, Any]):
    # Accept {keys:{...}} or direct {openaiKey:...}
    data = payload.get("keys") if isinstance(payload.get("keys"), dict) else payload
    return save_keys(data)

@app.get("/events")
def get_events(limit: int = 50, after_id: int = 0):
    return list_events(limit=limit, after_id=after_id)

@app.post("/events")
def post_event(payload: Dict[str, Any]):
    ev_type = str(payload.get("type") or "generic")
    ev_payload = payload.get("payload") if isinstance(payload.get("payload"), dict) else payload
    return push_event(ev_type, ev_payload)

@app.post("/chat")
def chat(payload: Dict[str, Any]):
    # Safe stub so UI never breaks
    text = str(payload.get("text", "")).strip()
    if not text:
        return {"answer": "[stub] empty message"}
    # Optional: write event
    try:
        push_event("chat", {"text": text[:500]})
    except Exception:
        pass
    return {"answer": f"[stub] received: {text[:200]}"}
PY
fi

echo "== Backend patch applied =="
echo "Files:"
echo "  $BE/db.py"
echo "  $BE/app.py (updated)"
echo "  $BE/requirements.txt (ensured)"

echo
echo "Next:"
echo "  cd ~/station_root/backend"
echo "  python -m venv .venv  (if not exists)"
echo "  source .venv/bin/activate"
echo "  pip install -r requirements.txt"
echo "  python -m uvicorn app:app --host 0.0.0.0 --port 8000"
