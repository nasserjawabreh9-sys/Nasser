#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
FE="$ROOT/frontend"
LOG="$ROOT/station_logs"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$LOG" "$ROOT/scripts/ops"

echo ">>> [PATCH v2.1 FIX] 1) Ensure zip installed (skip if missing dpkg)"
if ! command -v zip >/dev/null 2>&1; then
  echo "!!! zip not installed yet. Run:"
  echo "    dpkg --configure -a && pkg install -y zip"
  # do not hard-fail; continue wiring fixes
fi

echo ">>> [PATCH v2.1 FIX] 2) Fix SideBar safely (only if file exists)"
SIDEBAR="$FE/src/components/SideBar.tsx"
if [ -f "$SIDEBAR" ]; then
  if grep -q 'type NavKey = "landing"' "$SIDEBAR"; then
    sed -i 's/type NavKey = "landing" | "dashboard" | "ops" | "about";/type NavKey = "landing" | "dashboard" | "rooms" | "termux" | "ops" | "about";/g' "$SIDEBAR" || true
  fi

  if ! grep -q 'k="rooms"' "$SIDEBAR"; then
    sed -i 's|Item k="ops"|Item k="rooms" label="Rooms" sub="SQLite rooms & messages" active={p.active} onNav={p.onNav} />\n      <Item k="termux" label="Termux-like" sub="Console UI stub" active={p.active} onNav={p.onNav} />\n      <Item k="ops"|g' "$SIDEBAR" || true
  fi
else
  echo "!!! SideBar not found at: $SIDEBAR"
  echo "    Confirm your frontend path is: $FE"
fi

echo ">>> [PATCH v2.1 FIX] 3) Write smoke script"
cat > "$ROOT/scripts/ops/station_runtime_smoke_v2_1.sh" <<'SMOKE'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="${1:-http://127.0.0.1:8000}"

echo "== SMOKE: health =="
curl -s "$BASE/health" | cat
echo
echo "== SMOKE: rooms list =="
curl -s "$BASE/rooms" | cat
echo
echo "== SMOKE: ai route =="
curl -s -X POST "$BASE/ai/route" -H "Content-Type: application/json" -d '{"room_id":"9001","text":"smoke v2.1"}' | cat
echo
SMOKE
chmod +x "$ROOT/scripts/ops/station_runtime_smoke_v2_1.sh"

echo ">>> [PATCH v2.1 FIX] 4) Frontend build (optional)"
if [ -d "$FE" ]; then
  (cd "$FE" && npm run build >>"$LOG/npm_build_patch_${TS}.log" 2>&1) || {
    echo "!!! Frontend build failed. Check:"
    echo "    $LOG/npm_build_patch_${TS}.log"
  }
fi

echo ">>> [PATCH v2.1 FIX] 5) Baseline zip (only if zip exists)"
if command -v zip >/dev/null 2>&1; then
  cd "$ROOT"
  ZIP="station_baseline_${TS}.zip"
  zip -r "$ZIP" . \
    -x "frontend/node_modules/*" "frontend/dist/*" "backend/.venv/*" "station_logs/*" "_backup_*/*" ".git/*" >/dev/null
  echo "Baseline zip: $ROOT/$ZIP"
else
  echo "!!! zip still missing; baseline zip skipped."
fi

echo "DONE."
