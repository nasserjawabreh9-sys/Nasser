#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
ENV="$ROOT/station_env.sh"
LOG="$ROOT/global/logs/loop6_publish.log"

source "$ENV" || true

echo "==== LOOP6 START $(date -Iseconds) ====" | tee -a "$LOG"

cd "$ROOT"
git status --porcelain -b | tee -a "$LOG" || true

git add -A | tee -a "$LOG" || true
git commit -m "GLOBAL: publish" | tee -a "$LOG" || true
git push -u origin main | tee -a "$LOG"

if [ -n "${RENDER_DEPLOY_HOOK_URL:-}" ]; then
  curl -sS -X POST "$RENDER_DEPLOY_HOOK_URL" | tee -a "$LOG" || true
fi

echo "==== LOOP6 DONE ====" | tee -a "$LOG"
