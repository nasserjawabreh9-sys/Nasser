#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"

echo "=== [S0] Sanity ==="
test -d "$ROOT" || { echo "Missing: $ROOT"; exit 1; }
test -d "$BE" || { echo "Missing: $BE"; exit 1; }
test -d "$FE" || { echo "Missing: $FE"; exit 1; }

mkdir -p "$ROOT/scripts/ops" "$ROOT/station_logs"

# -----------------------
# (1) BACKEND PATCH
# -----------------------
echo "=== [B1] Backend: Termux-safe venv + deps (NO rust) ==="
cd "$BE"
if [ -d ".venv" ]; then
  echo "Backend venv exists: .venv"
else
  python -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install -U pip wheel setuptools >/dev/null

# Termux-safe: avoid uvicorn[standard] (watchfiles/uvloop/httptools)
pip install \
  "uvicorn==0.23.2" \
  "starlette==0.36.3" \
  "anyio==3.7.1" \
  "requests==2.31.0" \
  "python-multipart==0.0.9" \
  "click==8.3.1" \
  "h11==0.16.0" >/dev/null

pip freeze > requirements.txt

echo "=== [B2] Backend: ensure VERSION ==="
cd "$ROOT"
if [ ! -f VERSION ]; then
  echo "station-1.0.0" > VERSION
fi

echo "=== [B3] Backend: inject /info + /version + CORS + Ops endpoints (safe-append) ==="
cd "$BE"
MAIN="main.py"
test -f "$MAIN" || { echo "Missing backend/main.py"; exit 1; }

python - <<'PY'
from pathlib import Path
p = Path("main.py")
txt = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === STATION_OPS_BLOCK_V2 ==="
if marker in txt:
    print("Ops block already present. Skipping.")
    raise SystemExit(0)

add = r'''
# === STATION_OPS_BLOCK_V2 ===
# Adds:
# - GET  /info, /version
# - POST /ops/git/status, /ops/git/push
# - POST /ops/render/deploy
# - Optional CORS via ALLOWED_ORIGINS
# Security:
# - ops requires x-edit-key header == STATION_EDIT_KEY (or fallback 1234)

import os, json, time, subprocess
from typing import Dict, Any

try:
    from starlette.responses import JSONResponse, PlainTextResponse
    from starlette.routing import Route
    from starlette.middleware.cors import CORSMiddleware
except Exception:
    JSONResponse = None
    PlainTextResponse = None
    Route = None
    CORSMiddleware = None

def _now_iso():
    try:
        import datetime
        return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    except Exception:
        return None

def _read_version():
    try:
        here = os.path.dirname(__file__)
        root = os.path.abspath(os.path.join(here, ".."))
        vp = os.path.join(root, "VERSION")
        if os.path.exists(vp):
            return open(vp, "r", encoding="utf-8").read().strip()
    except Exception:
        pass
    return "station-unknown"

def _edit_key_ok(request) -> bool:
    want = os.getenv("STATION_EDIT_KEY", "1234")
    got = request.headers.get("x-edit-key", "")
    return bool(got) and got == want

# tiny in-memory rate-limit for ops (per IP per minute)
_OPS_BUCKET: Dict[str, Dict[str, Any]] = {}
def _ops_allow(ip: str, limit: int = 30):
    now = int(time.time())
    w = now // 60
    b = _OPS_BUCKET.get(ip)
    if not b or b.get("w") != w:
        _OPS_BUCKET[ip] = {"w": w, "c": 1}
        return True
    if b["c"] >= limit:
        return False
    b["c"] += 1
    return True

async def _info(request):
    return JSONResponse({
        "name": "station",
        "engine": os.getenv("ENGINE", "starlette-core"),
        "env": os.getenv("ENV", "local"),
        "runtime": os.getenv("RUNTIME", "termux"),
        "version": _read_version(),
        "time": _now_iso(),
    })

async def _version(request):
    return JSONResponse({"version": _read_version(), "time": _now_iso()})

def _run(cmd, cwd=None, timeout=30):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

async def _ops_git_status(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok": False, "error": "rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    rc, out, err = _run(["git", "status", "--porcelain=v1", "-b"], cwd=root)
    return JSONResponse({"ok": rc == 0, "rc": rc, "out": out, "err": err})

async def _ops_git_push(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok": False, "error": "rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    # stage+commit (if changes), then push
    _run(["git", "add", "-A"], cwd=root, timeout=60)
    rc1, out1, err1 = _run(["git", "commit", "-m", "station: ops commit"], cwd=root, timeout=60)
    rc2, out2, err2 = _run(["git", "push"], cwd=root, timeout=120)
    return JSONResponse({
        "ok": (rc2 == 0),
        "commit": {"rc": rc1, "out": out1, "err": err1},
        "push": {"rc": rc2, "out": out2, "err": err2},
    })

async def _ops_render_deploy(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok": False, "error": "rate_limited"}, status_code=429)

    try:
        body = await request.json()
    except Exception:
        body = {}

    api_key = (body.get("render_api_key") or os.getenv("RENDER_API_KEY") or "").strip()
    service_id = (body.get("render_service_id") or os.getenv("RENDER_SERVICE_ID") or "").strip()
    if not api_key or not service_id:
        return JSONResponse({"ok": False, "error": "missing_render_api_key_or_service_id"}, status_code=400)

    import requests
    url = f"https://api.render.com/v1/services/{service_id}/deploys"
    r = requests.post(url, headers={"Authorization": f"Bearer {api_key}"}, timeout=30)
    return JSONResponse({"ok": r.ok, "status": r.status_code, "json": (r.json() if r.content else None)})

def _apply_cors(app_obj):
    if CORSMiddleware is None:
        return
    allowed = os.getenv("ALLOWED_ORIGINS", "").strip()
    origins = [o.strip() for o in allowed.split(",") if o.strip()]
    if not origins:
        origins = ["http://localhost:5173", "http://127.0.0.1:5173"]
    try:
        # don't duplicate
        for m in getattr(app_obj, "user_middleware", []) or []:
            if getattr(m, "cls", None) is CORSMiddleware:
                return
        app_obj.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    except Exception:
        pass

def _register_routes(app_obj):
    if JSONResponse is None or Route is None:
        return
    try:
        routes = getattr(app_obj.router, "routes", None)
        if routes is None:
            return
        paths = set(getattr(r, "path", None) for r in routes)
        def add_route(path, fn, methods):
            if path not in paths:
                routes.append(Route(path, fn, methods=methods))
        add_route("/info", _info, ["GET"])
        add_route("/version", _version, ["GET"])
        add_route("/ops/git/status", _ops_git_status, ["POST"])
        add_route("/ops/git/push", _ops_git_push, ["POST"])
        add_route("/ops/render/deploy", _ops_render_deploy, ["POST"])
    except Exception:
        pass

try:
    if "app" in globals():
        _apply_cors(app)
        _register_routes(app)
except Exception:
    pass
'''

p.write_text(txt.rstrip() + "\n\n" + marker + "\n" + add + "\n", encoding="utf-8")
print("Patched main.py: added ops block v2")
PY

echo "=== [B4] Backend: official runner (stable) ==="
cat > "$BE/run_backend_official.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -f .venv/bin/activate ]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"
export TARGET="${TARGET:-main:app}"
echo ">>> [station] backend $TARGET @ $HOST:$PORT"
python -m uvicorn "$TARGET" --host "$HOST" --port "$PORT"
SH
chmod +x "$BE/run_backend_official.sh"

# -----------------------
# (2) STRENGTHEN STATION (minimal hardening)
# -----------------------
echo "=== [H1] Backend hardening: env template + sane defaults ==="
cd "$ROOT"
cat > "$ROOT/station_env.example.sh" <<'ENV'
#!/data/data/com.termux/files/usr/bin/bash
# Station env example (DO NOT commit secrets)
export ENV="termux"
export RUNTIME="station"
export ENGINE="starlette-core"

# Edit mode key for Ops endpoints (header x-edit-key)
export STATION_EDIT_KEY="1234"

# CORS (comma-separated) for Render later:
# export ALLOWED_ORIGINS="https://your-frontend.onrender.com"

# Optional: Render API deploy (can be passed from frontend too)
# export RENDER_API_KEY="..."
# export RENDER_SERVICE_ID="..."
ENV
chmod +x "$ROOT/station_env.example.sh"

# -----------------------
# (3) FRONTEND OPS BUTTONS + FIXES
# -----------------------
echo "=== [F1] Frontend: ensure typescript & build tooling ==="
cd "$FE"
npm install >/dev/null
npm install -D typescript >/dev/null

echo "=== [F2] Frontend: patch imports/types to satisfy TS strict flags ==="
python - <<'PY'
from pathlib import Path

# Fix StationConsole: type-only imports and remove unused panels unless rendered.
p = Path("src/StationConsole.tsx")
if p.exists():
    txt = p.read_text(encoding="utf-8", errors="ignore").splitlines()
    out=[]
    for line in txt:
        # convert `import SideBar, { NavKey }` -> type-only
        if 'import SideBar, { NavKey }' in line:
            out.append('import SideBar, { type NavKey } from "./components/SideBar";')
            continue
        # convert KeysState import to type-only
        if 'import { KeysState,' in line:
            out.append('import { type KeysState, loadKeysSafe, saveKeysSafe } from "./components/storage";')
            continue
        # drop unused RoomsPanel/TermuxPanel imports if present
        if "RoomsPanel" in line or "TermuxPanel" in line:
            # keep only if you already render them; otherwise drop
            continue
        out.append(line)
    p.write_text("\n".join(out) + "\n", encoding="utf-8")

# Fix KeysState type-only imports in components that import it.
targets = [
    "src/components/Dashboard.tsx",
    "src/components/Landing.tsx",
    "src/components/OpsPanel.tsx",
    "src/components/SettingsModal.tsx",
]
for t in targets:
    fp = Path(t)
    if not fp.exists(): 
        continue
    lines = fp.read_text(encoding="utf-8", errors="ignore").splitlines()
    o=[]
    for ln in lines:
        if ln.strip() == 'import { KeysState } from "./storage";':
            o.append('import type { KeysState } from "./storage";')
        else:
            o.append(ln)
    fp.write_text("\n".join(o) + "\n", encoding="utf-8")

# Fix ChatItem role typing (if present) to allow "assistant"
dash = Path("src/components/Dashboard.tsx")
if dash.exists():
    s = dash.read_text(encoding="utf-8", errors="ignore")
    # widen union if strict role exists
    s = s.replace('role: "user" | "system"', 'role: "user" | "system" | "assistant"')
    dash.write_text(s, encoding="utf-8")

print("Frontend type patches applied.")
PY

echo "=== [F3] Frontend: OpsPanel add buttons for Git status / Git push / Render deploy ==="
OPS="$FE/src/components/OpsPanel.tsx"
python - <<'PY'
from pathlib import Path
p = Path("src/components/OpsPanel.tsx")
if not p.exists():
    print("OpsPanel not found, skipping.")
    raise SystemExit(0)

txt = p.read_text(encoding="utf-8", errors="ignore")
if "ops/render/deploy" in txt and "ops/git/status" in txt:
    print("OpsPanel already contains ops calls. Skipping.")
    raise SystemExit(0)

# Minimal insertion strategy:
# - If file already has a button area, we add three actions.
# - Otherwise, append a small section at end of component.
needle = "export default function OpsPanel"
idx = txt.find(needle)
if idx < 0:
    print("Cannot find OpsPanel component. Skipping.")
    raise SystemExit(0)

# Append helper functions near bottom (simple + safe)
addon = r'''

// --- Station Ops helpers (auto-added) ---
async function postJSON(url: string, body: any, editKey: string) {
  const r = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-edit-key": editKey || "",
    },
    body: JSON.stringify(body || {}),
  });
  const t = await r.text();
  try { return { ok: r.ok, status: r.status, json: JSON.parse(t) }; }
  catch { return { ok: r.ok, status: r.status, text: t }; }
}
'''
if addon not in txt:
    txt += "\n" + addon + "\n"

# Try to inject UI inside component JSX by locating a place that renders something;
# We'll add a small panel using a conservative marker: first occurrence of 'return ('.
pos = txt.find("return (", idx)
if pos < 0:
    p.write_text(txt, encoding="utf-8")
    print("No return() found; wrote helpers only.")
    raise SystemExit(0)

# Insert block right after 'return (' line.
lines = txt.splitlines()
out=[]
inserted=False
for i, ln in enumerate(lines):
    out.append(ln)
    if not inserted and ln.strip().startswith("return ("):
        out.append('    <>')
        out.append('      <div style={{ padding: 12, border: "1px solid rgba(0,0,0,0.1)", borderRadius: 12, marginBottom: 12 }}>')
        out.append('        <div style={{ fontWeight: 700, marginBottom: 8 }}>Ops</div>')
        out.append('        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>')
        out.append('          <button onClick={async () => {')
        out.append('            const base = (keys.backendUrl || "").trim();')
        out.append('            const url = (base || "").replace(/\\/$/, "") + "/ops/git/status";')
        out.append('            const res = await postJSON(url, {}, keys.editKey || "");')
        out.append('            setOutput(JSON.stringify(res, null, 2));')
        out.append('          }}>Git Status (Backend)</button>')
        out.append('          <button onClick={async () => {')
        out.append('            const base = (keys.backendUrl || "").trim();')
        out.append('            const url = (base || "").replace(/\\/$/, "") + "/ops/git/push";')
        out.append('            const res = await postJSON(url, {}, keys.editKey || "");')
        out.append('            setOutput(JSON.stringify(res, null, 2));')
        out.append('          }}>Stage + Commit + Push (Backend)</button>')
        out.append('          <button onClick={async () => {')
        out.append('            const base = (keys.backendUrl || "").trim();')
        out.append('            const url = (base || "").replace(/\\/$/, "") + "/ops/render/deploy";')
        out.append('            const res = await postJSON(url, {')
        out.append('              render_api_key: keys.renderApiKey || "",')
        out.append('              render_service_id: keys.renderServiceId || "",')
        out.append('            }, keys.editKey || "");')
        out.append('            setOutput(JSON.stringify(res, null, 2));')
        out.append('          }}>Trigger Render Deploy</button>')
        out.append('        </div>')
        out.append('        <div style={{ opacity: 0.7, marginTop: 8, fontSize: 12 }}>')
        out.append('          Uses backend ops endpoints. Requires Edit Mode Key.')
        out.append('        </div>')
        out.append('      </div>')
        inserted=True
    # close fragment before the original closing return render if we detect the immediate next JSX root.
    # We won't attempt smart closing; assume existing component already returns a single root.
# If we inserted fragment, we must close it near end: easiest is to add </> just before final ');'
if inserted:
    # Insert closing fragment before last line that contains ');' that closes return.
    # We'll do a reverse scan.
    for j in range(len(out)-1, -1, -1):
        if out[j].strip() == ");":
            out.insert(j, "    </>")
            break

p.write_text("\n".join(out) + "\n", encoding="utf-8")
print("OpsPanel patched with ops buttons (best-effort).")
PY

echo "=== [F4] Frontend: build ==="
cd "$FE"
npm run build

# -----------------------
# Smoke helpers
# -----------------------
echo "=== [S1] Write smoke script (backend) ==="
cat > "$ROOT/scripts/ops/station_runtime_smoke_v3.sh" <<'SMOKE'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="${1:-http://127.0.0.1:8000}"
EDIT="${2:-1234}"

echo "== health =="
curl -s "$BASE/health"; echo
echo "== info =="
curl -s "$BASE/info"; echo
echo "== version =="
curl -s "$BASE/version"; echo
echo "== ops git status =="
curl -s -X POST "$BASE/ops/git/status" -H "x-edit-key: $EDIT" -H "Content-Type: application/json" -d '{}' ; echo
SMOKE
chmod +x "$ROOT/scripts/ops/station_runtime_smoke_v3.sh"

echo "=== DONE: upgrade applied ==="
echo "Run backend:"
echo "  cd $BE && ./run_backend_official.sh"
echo "Smoke:"
echo "  $ROOT/scripts/ops/station_runtime_smoke_v3.sh"
echo "Frontend build output:"
echo "  $FE/dist"
