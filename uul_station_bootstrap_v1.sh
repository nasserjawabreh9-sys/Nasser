#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"
LOG="$ROOT/station_logs"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$LOG"

log(){ echo ">>> [BOOT] $*"; }
die(){ echo "!!! [BOOT] $*" >&2; exit 1; }

log "0) Preconditions: Termux base packages"
pkg update -y >>"$LOG/boot_${TS}.log" 2>&1 || true
pkg upgrade -y >>"$LOG/boot_${TS}.log" 2>&1 || true

# Termux toolchain + runtime
pkg install -y \
  git curl wget unzip zip tar \
  python nodejs-lts \
  clang make pkg-config \
  openssl libffi \
  >>"$LOG/boot_${TS}.log" 2>&1 || true

log "1) Validate project root"
[ -d "$ROOT" ] || die "Missing $ROOT"
[ -d "$FE" ] || die "Missing $FE"
[ -d "$BE" ] || die "Missing $BE"

log "2) Update project tree snapshot"
TREE_FILE="$ROOT/PROJECT_TREE.txt"
{
  echo "Station Root: $ROOT"
  echo "Generated: $(date -Iseconds)"
  echo
  echo "=== BACKEND TREE ==="
  (cd "$BE" && find . -maxdepth 4 -type f | sed 's|^\./||' | sort) || true
  echo
  echo "=== FRONTEND TREE ==="
  (cd "$FE" && find . -maxdepth 4 -type f | sed 's|^\./||' | sort) || true
} > "$TREE_FILE"

log "3) Backend: create/refresh venv + pinned deps (Termux-safe)"
cd "$BE"
python -V | tee "$LOG/python_version_${TS}.log" >/dev/null

# venv
if [ ! -d ".venv" ]; then
  python -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install -U pip setuptools wheel >>"$LOG/pip_upgrade_${TS}.log" 2>&1

# requirements: enforce stable Termux-safe pins
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
  # minimal guard: ensure key deps exist (do not destroy user's file if customized)
  grep -qi '^fastapi' "$REQ" || echo 'fastapi==0.110.3' >>"$REQ"
  grep -qi '^uvicorn' "$REQ" || echo 'uvicorn[standard]==0.30.6' >>"$REQ"
  grep -qi '^pydantic' "$REQ" || echo 'pydantic==2.8.2' >>"$REQ"
  grep -qi '^python-multipart' "$REQ" || echo 'python-multipart==0.0.9' >>"$REQ"
  grep -qi '^requests' "$REQ" || echo 'requests==2.32.3' >>"$REQ"
fi

pip install -r requirements.txt >>"$LOG/pip_install_${TS}.log" 2>&1

# Ensure a predictable ASGI entrypoint exists: app.py with `app = FastAPI()`
if [ ! -f "$BE/app.py" ] && [ ! -f "$BE/main.py" ]; then
  log "3b) Creating backend/app.py baseline (health + CORS stub)"
  cat > "$BE/app.py" <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="station-backend")

# CORS for local dev
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

# Optional stubs to match UI (safe no-op)
@app.post("/chat")
def chat(payload: dict):
    text = str(payload.get("text",""))
    return {"answer": f"[stub] received: {text[:200]}"}

@app.post("/keys")
def keys(payload: dict):
    return {"ok": True, "stored": "stub"}
PY
fi

deactivate || true

log "4) Frontend: ensure deps + TS clean + Vite env"
cd "$FE"
node -v | tee "$LOG/node_version_${TS}.log" >/dev/null
npm -v  | tee "$LOG/npm_version_${TS}.log"  >/dev/null

# Ensure package.json exists
[ -f "$FE/package.json" ] || die "Missing frontend/package.json"

# Install deps (idempotent)
npm install >>"$LOG/npm_install_${TS}.log" 2>&1

# Ensure env template exists
if [ ! -f "$FE/.env.example" ]; then
  cat > "$FE/.env.example" <<'ENV'
# Frontend config
VITE_BACKEND_URL=http://127.0.0.1:8000
ENV
fi

log "5) Patch UI Official (uses existing patch script if present; else create it)"
PATCH="$FE/patch_ui_official_v1.sh"
if [ ! -f "$PATCH" ]; then
  cat > "$PATCH" <<'PATCHSCRIPT'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd ~/station_root/frontend

mkdir -p src/components src/styles

cat > src/styles/app.css <<'CSS'
/* (same CSS as official UI pack) */
:root{--bg0:#071423;--bg1:#0b1f35;--panel:#0e2a47;--panel2:#0a223b;--line: rgba(255,255,255,.10);--txt: rgba(255,255,255,.92);--muted: rgba(255,255,255,.68);--blue:#2aa7ff;--blue2:#0b6bff;--danger:#ff4d4d;--ok:#3ddc97;--shadow: 0 10px 30px rgba(0,0,0,.35);--radius: 14px;--radius2: 18px;--font: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Arial;}
*{ box-sizing:border-box; }html,body{ height:100%; }body{margin:0;font-family: var(--font);color: var(--txt);background: radial-gradient(1200px 700px at 20% 10%, #103d66 0%, var(--bg0) 55%) , linear-gradient(160deg, var(--bg1), var(--bg0));overflow:hidden;}
a{ color: var(--blue); text-decoration:none; }button, input, textarea{ font-family: inherit; }
.glass{background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.03));border: 1px solid var(--line);box-shadow: var(--shadow);border-radius: var(--radius);backdrop-filter: blur(10px);}
.appRoot{height:100vh;display:flex;flex-direction:column;}
.topBar{height:54px;display:flex;align-items:center;justify-content:space-between;padding: 0 14px;border-bottom: 1px solid var(--line);background: linear-gradient(180deg, rgba(14,42,71,.92), rgba(9,25,41,.86));}
.brand{display:flex;align-items:center;gap:10px;font-weight:700;letter-spacing:.2px;}
.brandBadge{width:34px;height:34px;border-radius:10px;display:grid;place-items:center;border:1px solid var(--line);background: radial-gradient(18px 18px at 30% 30%, rgba(42,167,255,.55), rgba(11,107,255,.18));}
.brandTitle{display:flex;flex-direction:column;line-height:1.1;}
.brandTitle small{color: var(--muted);font-weight:600;}
.topActions{display:flex;align-items:center;gap:8px;}
.btn{border:1px solid var(--line);background: rgba(255,255,255,.04);color: var(--txt);padding:8px 10px;border-radius: 12px;cursor:pointer;}
.btn:hover{border-color: rgba(42,167,255,.55);}
.btnPrimary{background: linear-gradient(180deg, rgba(42,167,255,.35), rgba(11,107,255,.20));border-color: rgba(42,167,255,.45);}
.btnDanger{background: linear-gradient(180deg, rgba(255,77,77,.25), rgba(255,77,77,.12));border-color: rgba(255,77,77,.35);}
.pill{padding:6px 10px;border-radius:999px;border:1px solid var(--line);color: var(--muted);background: rgba(0,0,0,.12);font-size:12px;}
.mainRow{height: calc(100vh - 54px);display:flex;gap:10px;padding: 10px;}
.sideBar{width: 260px;padding: 10px;border-right: 1px solid var(--line);background: linear-gradient(180deg, rgba(14,42,71,.62), rgba(7,20,35,.35));border-radius: var(--radius2);}
.navItem{width:100%;display:flex;gap:10px;align-items:center;padding:10px 10px;border-radius: 12px;cursor:pointer;border:1px solid transparent;color: var(--muted);}
.navItem:hover{background: rgba(255,255,255,.04);}
.navItemActive{color: var(--txt);border-color: rgba(42,167,255,.35);background: linear-gradient(180deg, rgba(42,167,255,.22), rgba(11,107,255,.10));}
.content{flex:1;display:flex;flex-direction:column;gap:10px;overflow:hidden;}
.stripStack{display:flex;flex-direction:column;gap:8px;}
.strip{padding:10px 12px;border-radius: 14px;border:1px solid var(--line);background: rgba(0,0,0,.18);display:flex;align-items:center;justify-content:space-between;gap:10px;}
.strip strong{font-size:13px;}
.strip small{display:block;color:var(--muted);margin-top:2px;}
.stripLeft{display:flex;flex-direction:column;}
.grid2{display:grid;grid-template-columns: 1.3fr .7fr;gap:10px;height: 100%;overflow:hidden;}
.panel{padding: 12px;border-radius: var(--radius2);border:1px solid var(--line);background: linear-gradient(180deg, rgba(14,42,71,.55), rgba(7,20,35,.30));box-shadow: var(--shadow);overflow:hidden;}
.panelHeader{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;}
.panelHeader h3{margin:0;font-size:14px;letter-spacing:.2px;}
.panelHeader span{color:var(--muted);font-size:12px;}
.chatWrap{height: calc(100% - 46px);display:flex;flex-direction:column;gap:10px;}
.chatLog{flex:1;border:1px solid var(--line);border-radius: 14px;background: rgba(0,0,0,.18);overflow:auto;padding:10px;}
.msg{margin: 8px 0;padding:10px 10px;border-radius: 12px;max-width: 92%;border: 1px solid rgba(255,255,255,.10);}
.msgUser{margin-left:auto;background: linear-gradient(180deg, rgba(42,167,255,.20), rgba(11,107,255,.08));}
.msgSys{margin-right:auto;background: rgba(255,255,255,.04);}
.msgMeta{color: var(--muted);font-size: 11px;margin-bottom: 6px;}
.chatInputRow{display:flex;gap:10px;}
.chatInputRow textarea{flex:1;resize:none;height: 54px;padding: 10px;border-radius: 14px;border: 1px solid var(--line);background: rgba(0,0,0,.20);color: var(--txt);outline:none;}
.chatInputRow textarea:focus{border-color: rgba(42,167,255,.50);}
.rightCol{display:flex;flex-direction:column;gap:10px;height:100%;overflow:hidden;}
.kv{display:flex;flex-direction:column;gap:8px;}
.kvRow{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px;border:1px solid var(--line);border-radius: 14px;background: rgba(0,0,0,.16);}
.kvRow b{font-size:12px;}
.kvRow code{color: var(--muted);font-size: 11px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width: 140px;}
.modalBack{position:fixed;inset:0;background: rgba(0,0,0,.55);display:grid;place-items:center;z-index: 50;}
.modal{width:min(760px, 92vw);max-height: 86vh;overflow:auto;padding: 14px;border-radius: 18px;border: 1px solid var(--line);background: linear-gradient(180deg, rgba(14,42,71,.92), rgba(7,20,35,.88));box-shadow: var(--shadow);}
.formGrid{display:grid;grid-template-columns: 1fr 1fr;gap:10px;}
.field{display:flex;flex-direction:column;gap:6px;}
.field label{font-size:12px;color: var(--muted);}
.field input{padding:10px;border-radius: 12px;border:1px solid var(--line);background: rgba(0,0,0,.18);color: var(--txt);outline:none;}
.field input:focus{border-color: rgba(42,167,255,.50);}
.landing{height:100%;display:grid;place-items:center;padding: 18px;}
.landingCard{width:min(980px, 96vw);display:grid;grid-template-columns: 1.05fr .95fr;gap: 14px;padding: 14px;border-radius: 18px;}
.hero{padding: 18px;border-radius: 18px;border: 1px solid var(--line);background: rgba(0,0,0,.18);}
.hero h1{margin:0 0 8px 0;font-size: 26px;}
.hero p{margin:0;color: var(--muted);line-height:1.7;}
.heroFooter{margin-top: 14px;display:flex;gap:10px;align-items:center;flex-wrap:wrap;}
.quote{font-weight: 700;letter-spacing:.2px;}
.animBox{display:grid;place-items:center;padding: 18px;border-radius: 18px;border: 1px solid var(--line);background: radial-gradient(220px 220px at 30% 30%, rgba(42,167,255,.22), rgba(0,0,0,.18));position: relative;overflow:hidden;}
.dwarf{width: 140px;height: 140px;border-radius: 28px;border: 1px solid rgba(255,255,255,.14);background: linear-gradient(180deg, rgba(42,167,255,.28), rgba(11,107,255,.12));display:grid;place-items:center;transform: translateY(0);animation: dwarfMove 5s ease-in-out 1;box-shadow: 0 16px 40px rgba(0,0,0,.35);}
.dwarfInner{width: 92px;height: 92px;border-radius: 22px;border:1px solid rgba(255,255,255,.14);background: rgba(0,0,0,.16);display:grid;place-items:center;font-weight:800;letter-spacing:.6px;}
@keyframes dwarfMove{0%{transform: translateY(18px) rotate(-3deg);filter: brightness(1);}30%{transform: translateY(-8px) rotate(2deg);filter: brightness(1.08);}60%{transform: translateY(10px) rotate(-2deg);filter: brightness(1.02);}100%{transform: translateY(0) rotate(0deg);filter: brightness(1.12);}}
CSS

if [ -f src/main.tsx ]; then
  grep -q 'src/styles/app.css' src/main.tsx || sed -i '1i import "./styles/app.css";' src/main.tsx
else
  cat > src/main.tsx <<'TS'
import "./styles/app.css";
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
TS
fi

cat > src/App.tsx <<'TSX'
import StationConsole from "./StationConsole";
export default function App(){ return <StationConsole/>; }
TSX

# Keep your already-built StationConsole.tsx if it exists; otherwise minimal fallback.
if [ ! -f src/StationConsole.tsx ]; then
  cat > src/StationConsole.tsx <<'TSX'
export default function StationConsole(){
  return <div style={{padding:20,color:"#fff"}}>StationConsole stub. Run official patch again.</div>;
}
TSX
fi

npm run build
PATCHSCRIPT
  chmod +x "$PATCH"
fi

# Apply official patch (non-destructive if you already applied full UI earlier)
log "6) Apply official UI patch"
bash "$PATCH" >>"$LOG/ui_patch_${TS}.log" 2>&1 || true

log "7) Final: verify & print key run commands"
{
  echo "=== Station Bootstrap DONE ==="
  echo "Backend venv: $BE/.venv"
  echo "Frontend: $FE"
  echo
  echo "Run backend (choose existing entrypoint):"
  echo "  cd ~/station_root/backend"
  echo "  source .venv/bin/activate"
  echo "  python -m uvicorn app:app --host 0.0.0.0 --port 8000"
  echo
  echo "Run frontend preview:"
  echo "  cd ~/station_root/frontend"
  echo "  export VITE_BACKEND_URL=http://127.0.0.1:8000"
  echo "  npm run preview -- --host 0.0.0.0 --port 5173"
  echo
  echo "Open: http://127.0.0.1:5173"
  echo "Logs: $LOG"
} | tee "$LOG/BOOT_DONE_${TS}.txt"

