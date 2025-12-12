#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
FE="$ROOT/frontend"
BE="$ROOT/backend"
LOG="$ROOT/station_logs"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$LOG"

echo ">>> [PATCH v2.1] 1) Install zip (if missing)"
if ! command -v zip >/dev/null 2>&1; then
  pkg update -y >/dev/null 2>&1 || true
  pkg install -y zip >/dev/null 2>&1
fi

echo ">>> [PATCH v2.1] 2) Fix SideBar insertion safely (idempotent)"
SIDEBAR="$FE/src/components/SideBar.tsx"
if [ -f "$SIDEBAR" ]; then
  # Ensure NavKey includes rooms + termux
  if grep -q 'type NavKey = "landing"' "$SIDEBAR"; then
    sed -i 's/type NavKey = "landing" | "dashboard" | "ops" | "about";/type NavKey = "landing" | "dashboard" | "rooms" | "termux" | "ops" | "about";/g' "$SIDEBAR" || true
  fi

  # Insert menu items only if missing
  if ! grep -q 'k="rooms"' "$SIDEBAR"; then
    sed -i 's|Item k="ops"|Item k="rooms" label="Rooms" sub="SQLite rooms & messages" active={p.active} onNav={p.onNav} />\n      <Item k="termux" label="Termux-like" sub="Console UI stub" active={p.active} onNav={p.onNav} />\n      <Item k="ops"|g' "$SIDEBAR" || true
  fi
fi

echo ">>> [PATCH v2.1] 3) Create smoke test script"
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

echo ">>> [PATCH v2.1] 4) Build frontend production (log)"
cd "$FE"
npm run build >>"$LOG/npm_build_patch_${TS}.log" 2>&1 || {
  echo "!!! Frontend build failed. Check: $LOG/npm_build_patch_${TS}.log"
  exit 1
}

echo ">>> [PATCH v2.1] 5) Make clean baseline zip (no node_modules/dist/venv/logs/backup)"
cd "$ROOT"
ZIP="station_baseline_${TS}.zip"
zip -r "$ZIP" . \
  -x "frontend/node_modules/*" "frontend/dist/*" "backend/.venv/*" "station_logs/*" "_backup_*/*" ".git/*" >/dev/null

echo ">>> [PATCH v2.1] DONE"
echo "Smoke test:"
echo "  $ROOT/scripts/ops/station_runtime_smoke_v2_1.sh"
echo "Baseline zip:"
echo "  $ROOT/$ZIP"
