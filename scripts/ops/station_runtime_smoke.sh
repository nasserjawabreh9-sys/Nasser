#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="${1:-$HOME/station_root}"
cd "$ROOT"

echo "=== STATION RUNTIME SMOKE TEST (FIXED) ==="
echo "Time: $(date)"
echo "Root: $ROOT"
echo

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! need_cmd curl; then
  echo ">>> Installing curl..."
  pkg install -y curl >/dev/null 2>&1 || apt install -y curl
fi

PORT=""
for f in run_station.sh backend/run_backend.sh backend/station_loop_v3_backend.sh station_full_run.sh; do
  if [ -f "$f" ]; then
    p="$(grep -oE -- '--port[[:space:]]+[0-9]+' "$f" 2>/dev/null | head -n 1 | awk '{print $2}' || true)"
    if [ -n "${p:-}" ]; then PORT="$p"; break; fi
  fi
done
[ -z "${PORT:-}" ] && PORT="8080"

BASE="http://127.0.0.1:$PORT"
echo ">>> Backend target: $BASE"
echo

mkdir -p station_logs

BACK_PID=""
if [ -x "./backend/run_backend.sh" ]; then
  echo ">>> Starting backend using ./backend/run_backend.sh"
  ( cd backend && ./run_backend.sh ) > station_logs/smoke_backend.log 2>&1 &
  BACK_PID="$!"
else
  echo ">>> ERROR: backend/run_backend.sh not executable/missing."
  exit 2
fi

echo ">>> Backend PID: $BACK_PID"
echo

echo ">>> Waiting for backend (accept any HTTP response)..."
ok=0
last_code="000"
for i in $(seq 1 30); do
  last_code="$(curl -s -o /dev/null -w "%{http_code}" "$BASE/" || true)"
  if [ "$last_code" != "000" ]; then ok=1; break; fi
  sleep 0.4
done

if [ "$ok" -ne 1 ]; then
  echo ">>> BACKEND DID NOT RESPOND on $BASE (code=$last_code)"
  echo "---- backend log (last 120 lines) ----"
  tail -n 120 station_logs/smoke_backend.log || true
  echo "-------------------------------------"
  exit 3
fi

echo ">>> Backend is up (GET / => $last_code)."
echo

echo ">>> Probing endpoints:"
endpoints=(
  "/openapi.json"
  "/docs"
  "/healthz"
  "/health"
  "/api/uui/config"
  "/api/settings"
  "/api/console/ping"
  "/api/ops/git/status"
  "/api/ops/openai/test"
)
for ep in "${endpoints[@]}"; do
  code="$(curl -s -o /dev/null -w "%{http_code}" "$BASE$ep" || true)"
  printf "  %-26s => %s\n" "$ep" "$code"
done
echo

echo ">>> Listing first 60 OpenAPI paths (if available):"
curl -s "$BASE/openapi.json" | grep -oE '"\/[^"]+"' | sort -u | head -n 60 || echo "  (openapi.json not accessible)"
echo

# Frontend build sanity
if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
  echo ">>> Frontend build check (npm run build)"
  cd frontend
  if [ ! -d "node_modules" ]; then
    echo ">>> node_modules missing -> npm install"
    npm install >/dev/null 2>&1 || true
  fi
  npm run build >/dev/null 2>&1 && echo ">>> Frontend build: OK" || echo ">>> Frontend build: FAIL"
  cd "$ROOT"
else
  echo ">>> Frontend folder not found or missing package.json -> SKIP"
fi

echo
echo ">>> Stopping backend PID: $BACK_PID"
kill "$BACK_PID" >/dev/null 2>&1 || true
sleep 0.5
echo "=== SMOKE DONE ==="
echo "Backend log: $ROOT/station_logs/smoke_backend.log"
