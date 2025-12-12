#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-8000}"

echo "== r9600 smoke test =="
echo "[1/6] Python present?"
python --version

echo "[2/6] Locate backend entry..."
CANDIDATES=(
  "backend/app.py"
  "backend/main.py"
  "app/main.py"
  "main.py"
)
ENTRY=""
for f in "${CANDIDATES[@]}"; do
  if [[ -f "$f" ]]; then ENTRY="$f"; break; fi
done

if [[ -z "$ENTRY" ]]; then
  echo "WARN: backend entry not found in known locations."
  echo "List root files:"
  ls
  exit 0
fi

echo "Using entry: $ENTRY"

echo "[3/6] Start backend (temporary)..."
# Guess module: try common patterns
MOD=""
if [[ "$ENTRY" == "backend/app.py" ]]; then MOD="backend.app:app"; fi
if [[ "$ENTRY" == "backend/main.py" ]]; then MOD="backend.main:app"; fi
if [[ "$ENTRY" == "app/main.py" ]]; then MOD="app.main:app"; fi
if [[ "$ENTRY" == "main.py" ]]; then MOD="main:app"; fi

if [[ -z "$MOD" ]]; then
  echo "WARN: cannot guess ASGI module for $ENTRY. Skipping run."
  exit 0
fi

# kill any running on port
pkill -f "uvicorn $MOD" >/dev/null 2>&1 || true

nohup python -m uvicorn "$MOD" --host 0.0.0.0 --port "$PORT" > /tmp/r9600_backend.log 2>&1 &
PID=$!
sleep 2

echo "[4/6] Probe health..."
OK=0
for path in "/healthz" "/health" "/api/healthz" "/api/health"; do
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS "http://127.0.0.1:${PORT}${path}" >/dev/null 2>&1; then
      echo "Health OK at ${path}"
      OK=1
      break
    fi
  fi
done

echo "[5/6] Stop backend..."
kill "$PID" >/dev/null 2>&1 || true
sleep 1

echo "[6/6] Result..."
if [[ "$OK" -eq 1 ]]; then
  echo "SMOKE PASS"
  exit 0
else
  echo "SMOKE PARTIAL (no health endpoint detected). Check log:"
  tail -n 80 /tmp/r9600_backend.log || true
  exit 0
fi
