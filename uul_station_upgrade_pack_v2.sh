#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"
SCRIPTS="$ROOT/scripts"
OPS="$ROOT/ops"
SEEDS="$ROOT/seeds"
DOCS="$ROOT/docs"
LOG="$ROOT/station_logs"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$SCRIPTS" "$OPS" "$SEEDS" "$DOCS" "$LOG"

log(){ echo ">>> [UUL-UPGRADE] $*"; }
die(){ echo "!!! [UUL-UPGRADE] $*" >&2; exit 1; }

[ -d "$BE" ] || die "Missing backend dir: $BE"
[ -d "$FE" ] || die "Missing frontend dir: $FE"

################################################################################
# 1) ROOMS + TERMUX-LIKE + PRIVATE AI (BACKEND MODULES + API)
################################################################################
log "1) Backend: install Rooms/AI/Ops modules + endpoints"

# 1.1 Create backend layout (non-destructive)
mkdir -p "$BE/station_core" "$BE/station_core/rooms" "$BE/station_core/ops" "$BE/station_core/ai"

cat > "$BE/station_core/__init__.py" <<'PY'
# station_core package
PY

# 1.2 Rooms Engine (SQLite-backed optional; in-memory fallback)
cat > "$BE/station_core/rooms/engine.py" <<'PY'
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
PY

cat > "$BE/station_core/rooms/api.py" <<'PY'
from typing import Any, Dict
from fastapi import APIRouter
from .engine import list_rooms, ensure_room, rename_room, add_message, get_messages

router = APIRouter(prefix="/rooms", tags=["rooms"])

@router.get("")
def rooms_list():
    return {"ok": True, "rooms": list_rooms()}

@router.post("/ensure")
def rooms_ensure(payload: Dict[str, Any]):
    room_id = str(payload.get("room_id") or "9001")
    title = payload.get("title")
    return ensure_room(room_id, str(title) if title else None)

@router.post("/rename")
def rooms_rename(payload: Dict[str, Any]):
    room_id = str(payload.get("room_id") or "9001")
    title = str(payload.get("title") or f"Room {room_id}")
    return rename_room(room_id, title)

@router.get("/{room_id}/messages")
def rooms_messages(room_id: str, limit: int = 50):
    return {"ok": True, "messages": get_messages(room_id, limit=limit)}

@router.post("/{room_id}/messages")
def rooms_add_message(room_id: str, payload: Dict[str, Any]):
    role = str(payload.get("role") or "user")
    text = str(payload.get("text") or "")
    return add_message(room_id, role, text)
PY

# 1.3 Ops Engine (Termux-like command router: disabled by default)
cat > "$BE/station_core/ops/guards.py" <<'PY'
from typing import Dict, Any

def require_edit_key(payload: Dict[str, Any]) -> None:
    # This is a guard stub: backend should validate edit_key strictly.
    # For now, we only require presence to avoid accidental ops.
    k = str(payload.get("edit_key") or "").strip()
    if not k:
        raise ValueError("edit_key missing")

def require_repo_and_token(keys: Dict[str, Any]) -> None:
    token = str(keys.get("githubToken") or "").strip()
    repo = str(keys.get("githubRepo") or "").strip()
    if not token:
        raise ValueError("githubToken missing")
    if not repo or "/" not in repo:
        raise ValueError("githubRepo missing/invalid (owner/repo)")
PY

cat > "$BE/station_core/ops/api.py" <<'PY'
from typing import Any, Dict
from fastapi import APIRouter
from .guards import require_edit_key, require_repo_and_token

router = APIRouter(prefix="/ops", tags=["ops"])

# Important: No auto-create repo. No git init. No destructive ops.
# These endpoints are "wiring stubs" to match UI buttons.

@router.post("/git_status")
def git_status(payload: Dict[str, Any]):
    require_edit_key(payload)
    keys = payload.get("keys") if isinstance(payload.get("keys"), dict) else {}
    require_repo_and_token(keys)
    return {"ok": True, "mode": "stub", "note": "Implement server-side git status on a Docker-capable host."}

@router.post("/git_push")
def git_push(payload: Dict[str, Any]):
    require_edit_key(payload)
    keys = payload.get("keys") if isinstance(payload.get("keys"), dict) else {}
    require_repo_and_token(keys)
    return {"ok": True, "mode": "stub", "note": "Implement server-side stage/commit/push on host. Guard prevents repo auto-create."}

@router.post("/render_deploy")
def render_deploy(payload: Dict[str, Any]):
    require_edit_key(payload)
    return {"ok": True, "mode": "stub", "note": "Implement Render deploy trigger via Render API on host."}
PY

# 1.4 Private Intelligence Stub (no external calls; room-aware routing)
cat > "$BE/station_core/ai/api.py" <<'PY'
from typing import Any, Dict
from fastapi import APIRouter
from station_core.rooms.engine import add_message

router = APIRouter(prefix="/ai", tags=["ai"])

@router.post("/route")
def ai_route(payload: Dict[str, Any]):
    # This is a deterministic local stub:
    # - It records the message into the room
    # - It returns a structured response that UI can render
    room_id = str(payload.get("room_id") or "9001")
    text = str(payload.get("text") or "").strip()
    if not text:
        return {"ok": True, "answer": "[stub] empty", "room_id": room_id}

    add_message(room_id, "user", text)

    # Simple local "private intelligence" policy stub:
    # classify intent
    t = text.lower()
    intent = "general"
    if "deploy" in t or "render" in t:
        intent = "deploy_ops"
    elif "db" in t or "sqlite" in t:
        intent = "data_ops"
    elif "room" in t:
        intent = "rooms"
    elif "termux" in t or "shell" in t or "cmd" in t:
        intent = "termux_like"

    answer = f"[stub-private-ai] intent={intent} | received={text[:200]}"
    add_message(room_id, "system", answer)

    return {
        "ok": True,
        "room_id": room_id,
        "intent": intent,
        "answer": answer,
        "policy": {"external_calls": False, "notes": "Private AI stub only (no network)."},
    }
PY

# 1.5 Ensure backend app.py includes routers (non-destructive)
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

MARK="# --- UUL_ROOMS_OPS_AI_ROUTERS_V1 ---"
if ! grep -q "$MARK" "$APP"; then
  cat >> "$APP" <<'PY'

# --- UUL_ROOMS_OPS_AI_ROUTERS_V1 ---
from station_core.rooms.api import router as rooms_router
from station_core.ops.api import router as ops_router
from station_core.ai.api import router as ai_router

app.include_router(rooms_router)
app.include_router(ops_router)
app.include_router(ai_router)
PY
fi

################################################################################
# 2) FRONTEND: ROOM UI + TERMUX-LIKE PANEL + AI ROUTE (NON-BREAKING)
################################################################################
log "2) Frontend: add Rooms + Termux-like panel + AI route (safe wiring)"

mkdir -p "$FE/src/components/rooms" "$FE/src/components/termux"

# 2.1 Rooms panel
cat > "$FE/src/components/rooms/RoomsPanel.tsx" <<'TSX'
import { useEffect, useState } from "react";
import { jget, jpost } from "../api";

type Room = { id: string; title: string; created_at: string };
type Msg = { id: number; role: string; text: string; created_at: string };

export default function RoomsPanel() {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [active, setActive] = useState<string>("9001");
  const [title, setTitle] = useState<string>("Room 9001");
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [text, setText] = useState<string>("");

  async function refresh() {
    const r = await jget("/rooms");
    setRooms(r.rooms || []);
  }

  async function load(roomId: string) {
    setActive(roomId);
    const r = await jget(`/rooms/${roomId}/messages?limit=80`);
    setMsgs(r.messages || []);
  }

  useEffect(() => {
    void refresh();
    void load(active);
  }, []);

  async function ensure() {
    await jpost("/rooms/ensure", { room_id: active, title });
    await refresh();
  }

  async function rename() {
    await jpost("/rooms/rename", { room_id: active, title });
    await refresh();
  }

  async function send(role: string) {
    const t = text.trim();
    if (!t) return;
    setText("");
    await jpost(`/rooms/${active}/messages`, { role, text: t });
    await load(active);
  }

  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>Rooms</h3>
        <span>SQLite-backed</span>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "280px 1fr", gap: 10, height: "calc(100% - 40px)" }}>
        <div style={{ border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", overflow: "auto" }}>
          <div style={{ padding: 10, display: "flex", gap: 8 }}>
            <input
              value={active}
              onChange={(e) => setActive(e.target.value)}
              placeholder="room_id"
              style={{ flex: 1, padding: 10, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.15)", color: "rgba(255,255,255,.9)" }}
            />
          </div>
          <div style={{ padding: 10, display: "flex", gap: 8 }}>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="title"
              style={{ flex: 1, padding: 10, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.15)", color: "rgba(255,255,255,.9)" }}
            />
          </div>
          <div style={{ padding: 10, display: "flex", gap: 8, flexWrap: "wrap" }}>
            <button className="btn btnPrimary" onClick={() => void ensure()}>Ensure</button>
            <button className="btn" onClick={() => void rename()}>Rename</button>
            <button className="btn" onClick={() => void refresh()}>Refresh</button>
            <button className="btn" onClick={() => void load(active)}>Load</button>
          </div>

          <div style={{ padding: 10, borderTop: "1px solid rgba(255,255,255,.08)" }}>
            <div style={{ color: "rgba(255,255,255,.65)", fontSize: 12, marginBottom: 6 }}>Known rooms</div>
            {rooms.map((r) => (
              <div
                key={r.id}
                onClick={() => void load(r.id)}
                style={{
                  padding: "10px 10px",
                  borderRadius: 12,
                  cursor: "pointer",
                  marginBottom: 6,
                  border: "1px solid rgba(255,255,255,.08)",
                  background: r.id === active ? "rgba(42,167,255,.14)" : "rgba(0,0,0,.12)",
                }}
              >
                <b style={{ fontSize: 13 }}>{r.title}</b>
                <div style={{ color: "rgba(255,255,255,.55)", fontSize: 11 }}>{r.id}</div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 10, height: "100%" }}>
          <div style={{ flex: 1, border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", overflow: "auto", padding: 10 }}>
            {msgs.map((m) => (
              <div key={m.id} style={{ marginBottom: 10 }}>
                <div style={{ color: "rgba(255,255,255,.55)", fontSize: 11 }}>{m.role.toUpperCase()} • {new Date(m.created_at).toLocaleString()}</div>
                <div style={{ whiteSpace: "pre-wrap" }}>{m.text}</div>
              </div>
            ))}
          </div>

          <div style={{ display: "flex", gap: 10 }}>
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Write message to room..."
              style={{ flex: 1, height: 56, padding: 10, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", color: "rgba(255,255,255,.9)" }}
            />
            <button className="btn btnPrimary" onClick={() => void send("user")}>Send</button>
          </div>
        </div>
      </div>
    </div>
  );
}
TSX

# 2.2 Termux-like panel (UI only; no real command execution)
cat > "$FE/src/components/termux/TermuxPanel.tsx" <<'TSX'
import { useState } from "react";

type Item = { ts: number; line: string };

export default function TermuxPanel() {
  const [hist, setHist] = useState<Item[]>([
    { ts: Date.now(), line: "Welcome to Station Termux-like Console (UI-only stub)." },
    { ts: Date.now(), line: "Type commands, keep history, copy output. No server execution." },
  ]);
  const [cmd, setCmd] = useState<string>("");

  function runLocal() {
    const c = cmd.trim();
    if (!c) return;
    setCmd("");
    const out =
      c === "help"
        ? "Commands: help | clear | echo <text> | pwd | whoami"
        : c === "clear"
        ? "(cleared)"
        : c.startsWith("echo ")
        ? c.slice(5)
        : c === "pwd"
        ? "/station_root (virtual)"
        : c === "whoami"
        ? "operator"
        : `unknown command: ${c}`;

    setHist((h) => {
      if (c === "clear") return [{ ts: Date.now(), line: "Console cleared." }];
      return [...h, { ts: Date.now(), line: `$ ${c}` }, { ts: Date.now(), line: out }];
    });
  }

  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>Termux-like</h3>
        <span>UI stub (safe)</span>
      </div>

      <div style={{ height: "calc(100% - 48px)", display: "flex", flexDirection: "column", gap: 10 }}>
        <div style={{ flex: 1, border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", padding: 10, overflow: "auto" }}>
          {hist.map((x, i) => (
            <div key={i} style={{ fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace", fontSize: 12, color: "rgba(255,255,255,.82)", whiteSpace: "pre-wrap" }}>
              {x.line}
            </div>
          ))}
        </div>

        <div style={{ display: "flex", gap: 10 }}>
          <input
            value={cmd}
            onChange={(e) => setCmd(e.target.value)}
            placeholder="Type command (help/clear/echo/pwd/whoami)"
            style={{ flex: 1, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", color: "rgba(255,255,255,.9)" }}
            onKeyDown={(e) => {
              if (e.key === "Enter") runLocal();
            }}
          />
          <button className="btn btnPrimary" onClick={runLocal}>Run</button>
        </div>
      </div>
    </div>
  );
}
TSX

# 2.3 Wire navigation items in SideBar (adds Rooms + Termux)
# We patch SideBar.tsx minimally: add nav keys and menu items if not present.
SIDEBAR="$FE/src/components/SideBar.tsx"
if grep -q 'type NavKey = "landing"' "$SIDEBAR"; then
  sed -i 's/type NavKey = "landing" | "dashboard" | "ops" | "about";/type NavKey = "landing" | "dashboard" | "rooms" | "termux" | "ops" | "about";/g' "$SIDEBAR" || true
fi

if ! grep -q 'k="rooms"' "$SIDEBAR"; then
  # Insert menu items before Ops
  sed -i 's/Item k="ops"/Item k="rooms" label="Rooms" sub="SQLite rooms & messages" active={p.active} onNav={p.onNav} />\n      <Item k="termux" label="Termux-like" sub="Console UI stub" active={p.active} onNav={p.onNav} />\n      <Item k="ops"/' "$SIDEBAR" || true
fi

# 2.4 Wire StationConsole rendering
SC="$FE/src/StationConsole.tsx"
if ! grep -q 'RoomsPanel' "$SC"; then
  # Add imports
  sed -i '1i import RoomsPanel from "./components/rooms/RoomsPanel";\nimport TermuxPanel from "./components/termux/TermuxPanel";\n' "$SC" || true
fi

# Add rendering branches (rooms/termux)
if ! grep -q 'nav === "rooms"' "$SC"; then
  # naive insertion: extend ternary chain
  sed -i 's/nav === "dashboard" ? (/nav === "dashboard" ? (/g' "$SC" || true
  # Replace the block area by adding new branches before ops
  sed -i 's/) : nav === "ops" ? (/) : nav === "rooms" ? (\n              <RoomsPanel />\n            ) : nav === "termux" ? (\n              <TermuxPanel />\n            ) : nav === "ops" ? (/g' "$SC" || true
fi

################################################################################
# 3) UPDATE FULL STATION TREE
################################################################################
log "3) Update full Station tree snapshot"
TREE="$ROOT/PROJECT_TREE_FULL.txt"
{
  echo "Station Root: $ROOT"
  echo "Generated: $(date -Iseconds)"
  echo
  echo "=== ROOT ==="
  (cd "$ROOT" && find . -maxdepth 2 -type d | sed 's|^\./||' | sort) || true
  echo
  echo "=== FILES (maxdepth 5) ==="
  (cd "$ROOT" && find . -maxdepth 5 -type f | sed 's|^\./||' | sort) || true
} > "$TREE"

################################################################################
# 4) REORDER: PREVIEWS + FUNCTIONS + SEEDS (STANDARDIZE)
################################################################################
log "4) Reorder Station structure (previews/functions/seeds)"

# Seeds
cat > "$SEEDS/seed_rooms_demo.json" <<'JSON'
{
  "room_id": "9001",
  "title": "Core Room 9001",
  "messages": [
    { "role": "system", "text": "Rooms demo seed loaded." },
    { "role": "user", "text": "Create rooms, persist messages, wire AI stub." }
  ]
}
JSON

cat > "$DOCS/README_STATION_AR.md" <<'MD'
# Station (UUL Standard)

## Run Local (Termux)
- Backend:
  - cd ~/station_root/backend
  - source .venv/bin/activate
  - python -m uvicorn app:app --host 0.0.0.0 --port 8000
- Frontend:
  - cd ~/station_root/frontend
  - export VITE_BACKEND_URL=http://127.0.0.1:8000
  - npm run dev -- --host 0.0.0.0 --port 5173

## APIs
- GET /health
- Rooms: /rooms
- Private AI stub: POST /ai/route
- Ops stubs: /ops/*
MD

################################################################################
# 5) FULL RE-RUN FROM ZERO (CLEAN + REBUILD) - SAFE BACKUP
################################################################################
log "5) Full re-run from zero (safe backup + clean + rebuild)"

BACKUP="$ROOT/_backup_${TS}"
mkdir -p "$BACKUP"

# Backup key assets (non-destructive)
cp -f "$TREE" "$BACKUP/" 2>/dev/null || true
cp -rf "$BE/app.py" "$BACKUP/" 2>/dev/null || true
cp -rf "$BE/station_core" "$BACKUP/" 2>/dev/null || true
cp -rf "$FE/src" "$BACKUP/frontend_src" 2>/dev/null || true

# Clean frontend build artifacts
rm -rf "$FE/dist" 2>/dev/null || true
rm -rf "$FE/node_modules" 2>/dev/null || true

# Clean backend venv
rm -rf "$BE/.venv" 2>/dev/null || true

log "5a) Recreate backend venv + install"
cd "$BE"
python -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install -U pip setuptools wheel >>"$LOG/pip_${TS}.log" 2>&1
pip install -r requirements.txt >>"$LOG/pip_install_${TS}.log" 2>&1
deactivate || true

log "5b) Reinstall frontend deps + build"
cd "$FE"
npm install >>"$LOG/npm_install_${TS}.log" 2>&1
npm run build >>"$LOG/npm_build_${TS}.log" 2>&1

################################################################################
# 6) PATCH TO GITHUB DIRECT (COMMIT + PUSH) - NO NEW REPO
################################################################################
log "6) GitHub patch: commit + push (no repo creation)"

cd "$ROOT"

# If not a git repo, we initialize locally but DO NOT create remote repo.
if [ ! -d "$ROOT/.git" ]; then
  git init
fi

# Ensure .gitignore exists
if [ ! -f "$ROOT/.gitignore" ]; then
  cat > "$ROOT/.gitignore" <<'IGN'
# Python
backend/.venv/
backend/__pycache__/
backend/data/*.db
backend/data/*.db-journal

# Node
frontend/node_modules/
frontend/dist/

# Logs / backups
station_logs/
_backup_*/
IGN
fi

git add -A

MSG="UUL upgrade v2: rooms + termux-like + private-ai + tree + reorder + rerun"
git commit -m "$MSG" >/dev/null 2>&1 || true

# Push only if remote exists
if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin main >/dev/null 2>&1 || git push -u origin master >/dev/null 2>&1 || true
  log "Git push attempted (origin exists)."
else
  log "No 'origin' remote set. Not creating a new repo. Set origin then rerun push step:"
  echo "  cd ~/station_root"
  echo "  git remote add origin https://github.com/<owner>/<repo>.git"
  echo "  git push -u origin main"
fi

log "DONE."
echo
echo "Run now:"
echo "  (1) Backend:"
echo "      cd ~/station_root/backend && source .venv/bin/activate && python -m uvicorn app:app --host 0.0.0.0 --port 8000"
echo "  (2) Frontend dev:"
echo "      cd ~/station_root/frontend && export VITE_BACKEND_URL=http://127.0.0.1:8000 && npm run dev -- --host 0.0.0.0 --port 5173"
echo
echo "Tree: $ROOT/PROJECT_TREE_FULL.txt"
echo "Backup: $BACKUP"
