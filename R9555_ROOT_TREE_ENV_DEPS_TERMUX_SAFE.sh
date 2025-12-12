#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9555] Root/Tree/Env/Deps Termux-safe @ $ROOT"

# -----------------------------
# 0) Guard: ensure root
# -----------------------------
if [ ! -d "$ROOT/backend" ] || [ ! -d "$ROOT/frontend" ]; then
  echo "ERROR: expected dirs backend/ and frontend/ under $ROOT"
  echo "Current:"
  ls -la
  exit 1
fi

# -----------------------------
# 1) Termux packages (safe set)
# -----------------------------
echo ">>> [R9555] pkg update/upgrade + base tooling"
pkg update -y >/dev/null || true
pkg upgrade -y >/dev/null || true

pkg install -y \
  git curl openssh ca-certificates \
  python nodejs-lts \
  jq nano \
  clang make pkg-config \
  >/dev/null || true

# -----------------------------
# 2) Python venv (backend) + pinned deps (no heavy builds)
# -----------------------------
echo ">>> [R9555] backend venv + pip deps"
cd "$ROOT/backend"
python -V

if [ ! -d ".venv" ]; then
  python -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install --upgrade pip setuptools wheel >/dev/null

# Enforce minimal requirements (Termux-safe)
REQ="requirements.txt"
if [ ! -f "$REQ" ]; then
  cat > "$REQ" <<'EOF'
starlette==0.36.3
uvicorn==0.23.2
anyio==3.7.1
python-multipart==0.0.9
requests==2.31.0
EOF
else
  # ensure required pins exist (append if missing)
  grep -q "^starlette==" "$REQ" || echo "starlette==0.36.3" >> "$REQ"
  grep -q "^uvicorn==" "$REQ"   || echo "uvicorn==0.23.2"   >> "$REQ"
  grep -q "^anyio==" "$REQ"     || echo "anyio==3.7.1"      >> "$REQ"
  grep -q "^python-multipart==" "$REQ" || echo "python-multipart==0.0.9" >> "$REQ"
  grep -q "^requests==" "$REQ"  || echo "requests==2.31.0"  >> "$REQ"
fi

python -m pip install -r "$REQ" >/dev/null

python - <<'PY'
import starlette, uvicorn, anyio, requests
print("OK deps:", "starlette", starlette.__version__, "| uvicorn", uvicorn.__version__, "| anyio", anyio.__version__, "| requests", requests.__version__)
PY

deactivate || true

# -----------------------------
# 3) Frontend deps (React/Vite) + ensure router lib
# -----------------------------
echo ">>> [R9555] frontend npm deps (vite/react)"
cd "$ROOT/frontend"
node -v
npm -v

# Install deps (won't recreate project)
npm install >/dev/null 2>&1 || true
npm i react-router-dom >/dev/null 2>&1 || true

# -----------------------------
# 4) Root metadata dirs (standard)
# -----------------------------
echo ">>> [R9555] ensure meta dirs"
cd "$ROOT"
mkdir -p \
  station_meta/{queue,locks,logs,settings,notifications,bindings} \
  docs scripts/ops \
  >/dev/null 2>&1 || true

# -----------------------------
# 5) Tree snapshot + health of key files
# -----------------------------
echo ">>> [R9555] write TREE + INVENTORY"
TS="$(date +%Y%m%d_%H%M%S)"
TREE_OUT="docs/TREE_${TS}.txt"
INV_OUT="docs/INVENTORY_${TS}.md"

# Tree (best effort)
{
  echo "ROOT: $ROOT"
  echo "DATE: $TS"
  echo
  echo "== top =="
  ls -la
  echo
  echo "== backend/app =="
  ls -la backend/app 2>/dev/null || true
  echo
  echo "== backend/app/routes =="
  ls -la backend/app/routes 2>/dev/null || true
  echo
  echo "== frontend/src =="
  ls -la frontend/src 2>/dev/null || true
  echo
  echo "== scripts/ops =="
  ls -la scripts/ops 2>/dev/null || true
} > "$TREE_OUT"

# Inventory (paths we care about)
{
  echo "# Inventory Snapshot ($TS)"
  echo
  echo "## Root"
  echo "- \`$ROOT\`"
  echo
  echo "## Backend"
  for f in \
    backend/app/main.py \
    backend/app/settings_store.py \
    backend/app/loop_queue.py \
    backend/app/loop_worker.py \
    backend/app/routes/settings.py \
    backend/app/routes/loop.py \
    backend/app/routes/ops_run_cmd.py
  do
    if [ -f "$f" ]; then
      echo "- OK: \`$f\`"
    else
      echo "- MISSING: \`$f\`"
    fi
  done
  echo
  echo "## Frontend"
  for f in \
    frontend/package.json \
    frontend/vite.config.* \
    frontend/src/main.jsx \
    frontend/src/App.jsx
  do
    if ls $f >/dev/null 2>&1; then
      echo "- OK: \`$f\`"
    else
      echo "- MISSING: \`$f\`"
    fi
  done
  echo
  echo "## Ops Scripts"
  for f in \
    scripts/ops/loop_start.sh \
    scripts/ops/loop_stop.sh \
    scripts/ops/loop_status.sh \
    scripts/ops/verify_loop_e2e.sh
  do
    if [ -f "$f" ]; then
      echo "- OK: \`$f\`"
    else
      echo "- MISSING: \`$f\`"
    fi
  done
  echo
  echo "## Versions"
  echo "- Python: $(python -V 2>&1 || true)"
  echo "- Node: $(node -v 2>&1 || true)"
  echo "- NPM: $(npm -v 2>&1 || true)"
} > "$INV_OUT"

echo ">>> [R9555] DONE"
echo "TREE: $TREE_OUT"
echo "INV : $INV_OUT"

# -----------------------------
# 6) Quick status
# -----------------------------
echo
echo ">>> [R9555] git status (brief)"
git status --porcelain || true
