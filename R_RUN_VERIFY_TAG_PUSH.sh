#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

PORT="${PORT:-8000}"
EDIT_KEY="${STATION_EDIT_KEY:-1234}"

# Usage:
#   ./R_RUN_VERIFY_TAG_PUSH.sh                  -> tags r9800 + r9900
#   ./R_RUN_VERIFY_TAG_PUSH.sh 9700             -> tag r9700
#   ./R_RUN_VERIFY_TAG_PUSH.sh 9800 9900        -> tags r9800 + r9900
#   ./R_RUN_VERIFY_TAG_PUSH.sh 9800 9900 "msg"  -> with commit msg

TAG1="${1:-9800}"
TAG2="${2:-9900}"
MSG="${3:-feat: run+verify+tag+push}"

# normalize to rXXXX
norm_tag() {
  local x="$1"
  x="${x#r}"
  echo "r${x}"
}

T1="$(norm_tag "$TAG1")"
T2="$(norm_tag "$TAG2")"

# If user passed only one arg and it looks like a message, keep defaults
if [[ "${1:-}" =~ ^[A-Za-z] ]]; then
  T1="r9800"
  T2="r9900"
  MSG="$1"
fi

echo "=================================================="
echo "RUN + VERIFY + TAG + PUSH"
echo "ROOT=$ROOT"
echo "PORT=$PORT"
echo "EDIT_KEY=set"
echo "TAGS=$T1 $T2"
echo "MSG=$MSG"
echo "=================================================="

if [ ! -d ".git" ]; then
  echo "[ERR] Not a git repo."
  exit 1
fi

# -----------------------------
# 1) Ignore runtime sensitive files
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

git rm --cached station_meta/settings/runtime_keys.json >/dev/null 2>&1 || true
git rm --cached station_meta/queue/dynamo_worker.pid >/dev/null 2>&1 || true

# -----------------------------
# 2) HARD restart
# -----------------------------
echo
echo ">>> [STEP 2] HARD restart Station"
if [ -f "R9500_HARD_RESTART_FIX_NOTFOUND.sh" ]; then
  bash R9500_HARD_RESTART_FIX_NOTFOUND.sh
else
  echo "[WARN] R9500_HARD_RESTART_FIX_NOTFOUND.sh not found. Skipping restart."
fi

# -----------------------------
# 3) Start Dynamo worker (optional)
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

check "health" "curl -fsS http://127.0.0.1:${PORT}/health >/dev/null"
check "api/settings" "curl -fsS http://127.0.0.1:${PORT}/api/settings | head -c 200 >/dev/null"
check "loop task + run_once" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/loop/task \
    -H 'Content-Type: application/json' \
    -d '{\"kind\":\"echo\",\"payload\":{\"msg\":\"verify\"}}' >/dev/null \
  && curl -fsS -X POST http://127.0.0.1:${PORT}/api/loop/run_once >/dev/null \
"
check "ops/run_cmd git_status" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/ops/run_cmd \
    -H 'Content-Type: application/json' \
    -H \"X-Edit-Key: ${EDIT_KEY}\" \
    -d '{\"cmd\":\"git_status\"}' | head -c 200 >/dev/null \
"
check "console git status" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/console \
    -H 'Content-Type: application/json' \
    -H \"X-Edit-Key: ${EDIT_KEY}\" \
    -d '{\"line\":\"git status\"}' | head -c 200 >/dev/null \
" || true
check "ocr stub" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/ocr \
    -H 'Content-Type: application/json' \
    -d '{\"text_hint\":\"ocr_stub_ok\"}' | head -c 200 >/dev/null \
" || true
check "stt stub" " \
  curl -fsS -X POST http://127.0.0.1:${PORT}/api/stt \
    -H 'Content-Type: application/json' \
    -d '{\"text_hint\":\"stt_stub_ok\"}' | head -c 200 >/dev/null \
" || true

echo ">>> VERIFY SUMMARY: fail=$fail"
echo

# -----------------------------
# 5) Commit
# -----------------------------
echo ">>> [STEP 5] Stage + Commit"
git add -A
git commit -m "$MSG" || echo "[NOTE] Nothing to commit."

# -----------------------------
# 6) Tag + Push
# -----------------------------
echo ">>> [STEP 6] Tagging"
git tag -f "$T1" >/dev/null 2>&1 || true
# tag2 optional: if user passes same tag, skip
if [ "$T2" != "$T1" ]; then
  git tag -f "$T2" >/dev/null 2>&1 || true
fi

echo ">>> [STEP 6] Push branch + tags"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$BRANCH"
git push -f origin "$T1"
if [ "$T2" != "$T1" ]; then
  git push -f origin "$T2"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "DONE: RUN+VERIFY+TAG+PUSH OK. tags: $T1 $T2"
else
  echo "DONE: PUSH OK, but some VERIFY checks failed. tags: $T1 $T2"
fi
