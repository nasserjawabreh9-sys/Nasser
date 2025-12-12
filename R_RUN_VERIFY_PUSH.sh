#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

PORT="${PORT:-8000}"
EDIT_KEY="${STATION_EDIT_KEY:-1234}"

echo "=================================================="
echo "RUN + VERIFY + PUSH"
echo "ROOT=$ROOT"
echo "PORT=$PORT"
echo "=================================================="

# -----------------------------
# 0) Ensure git repo
# -----------------------------
if [ ! -d ".git" ]; then
  echo "[ERR] Not a git repo. Run git init / set origin first."
  exit 1
fi

# -----------------------------
# 1) Make sure runtime-sensitive files are ignored
# -----------------------------
touch .gitignore
grep -q "station_meta/settings/runtime_keys.json" .gitignore || cat >> .gitignore <<'EOF'

# --- Station runtime sensitive / volatile ---
station_meta/settings/runtime_keys.json
station_meta/queue/*.pid
station_meta/queue/locks/
station_meta/logs/
backend.log
frontend.log
EOF

# If previously tracked, untrack (keep file locally)
git rm --cached station_meta/settings/runtime_keys.json >/dev/null 2>&1 || true
git rm --cached station_meta/queue/dynamo_worker.pid >/dev/null 2>&1 || true

# -----------------------------
# 2) HARD restart (uses your existing script)
# -----------------------------
echo
echo ">>> [STEP 2] HARD restart Station"
if [ -f "R9500_HARD_RESTART_FIX_NOTFOUND.sh" ]; then
  bash R9500_HARD_RESTART_FIX_NOTFOUND.sh
else
  echo "[WARN] R9500_HARD_RESTART_FIX_NOTFOUND.sh not found. Skipping restart."
fi

# -----------------------------
# 3) Ensure worker loop running (optional)
# -----------------------------
echo
echo ">>> [STEP 3] Start Dynamo worker (optional)"
if [ -f "scripts/ops/loop_start.sh" ]; then
  bash scripts/ops/loop_start.sh || true
fi

# -----------------------------
# 4) Verify endpoints
# -----------------------------
echo
echo ">>> [STEP 4] VERIFY endpoints"

fail=0

check() {
  local name="$1"
  local cmd="$2"
  echo "---- $name ----"
  if eval "$cmd" ; then
    echo "[OK] $name"
  else
    echo "[FAIL] $name"
    fail=1
  fi
  echo
}

# Health
check "health" "curl -fsS http://127.0.0.1:${PORT}/health >/dev/null"

# Settings
check "api/settings" "curl -fsS http://127.0.0.1:${PORT}/api/settings | head -c 200 >/dev/null"

# Loop submit + run_once (if exists)
check "loop task + run_once" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/loop/task \
    -H 'Content-Type: application/json' \
    -d '{\"kind\":\"echo\",\"payload\":{\"msg\":\"verify\"}}' >/dev/null \
  && curl -fsS -X POST http://127.0.0.1:${PORT}/api/loop/run_once >/dev/null \
"

# Ops run_cmd (if exists)
check "ops/run_cmd git_status" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/ops/run_cmd \
    -H 'Content-Type: application/json' \
    -H \"X-Edit-Key: ${EDIT_KEY}\" \
    -d '{\"cmd\":\"git_status\"}' | head -c 200 >/dev/null \
"

# Console (if exists: r9800)
check "console git status" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/console \
    -H 'Content-Type: application/json' \
    -H \"X-Edit-Key: ${EDIT_KEY}\" \
    -d '{\"line\":\"git status\"}' | head -c 200 >/dev/null \
"

# OCR stub (if exists: r9900)
check "ocr stub" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/ocr \
    -H 'Content-Type: application/json' \
    -d '{\"text_hint\":\"ocr_stub_ok\"}' | head -c 200 >/dev/null \
"

# STT stub (if exists: r9900)
check "stt stub" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/stt \
    -H 'Content-Type: application/json' \
    -d '{\"text_hint\":\"stt_stub_ok\"}' | head -c 200 >/dev/null \
"

echo ">>> VERIFY SUMMARY: fail=$fail"
echo

# -----------------------------
# 5) Commit + push (even if partial verify; you decide by fail flag)
# -----------------------------
MSG="${1:-chore: run+verify+push}"

echo ">>> [STEP 5] Git status"
git status --porcelain || true

echo ">>> [STEP 5] Stage + Commit"
git add -A
git commit -m "$MSG" || echo "[NOTE] Nothing to commit."

echo ">>> [STEP 5] Push"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$BRANCH"

echo
if [ "$fail" -eq 0 ]; then
  echo "DONE: RUN+VERIFY+PUSH completed successfully."
else
  echo "DONE: PUSH completed, but some VERIFY checks failed (see logs above)."
fi
