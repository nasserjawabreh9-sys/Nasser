#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
LOGS="$ROOT/station_logs"
TS="$(date -u +%Y%m%d_%H%M%S)"
OUT="$LOGS/audit_quick_${TS}.md"

mkdir -p "$LOGS"

say(){ echo "$@" | tee -a "$OUT"; }

exists(){ [ -e "$1" ] && echo "yes" || echo "no"; }

dir_size(){
  local d="$1"
  if [ -d "$d" ]; then
    (du -sk "$d" 2>/dev/null || true) | awk '{print $1 " KB"}'
  else
    echo "0 KB"
  fi
}

count_files(){
  local d="$1"
  if [ -d "$d" ]; then
    find "$d" -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

curl_try(){
  local u="$1"
  curl -sS --max-time 2 "$u" 2>/dev/null || echo "no_response"
}

say "# Station Audit Quick Report"
say ""
say "- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
say "- Root: $ROOT"
say ""

say "## System"
say "- whoami: $(whoami || true)"
say "- uname: $(uname -a || true)"
say "- python: $(python -V 2>/dev/null || echo na)"
say "- node: $(node -v 2>/dev/null || echo na)"
say "- npm: $(npm -v 2>/dev/null || echo na)"
say ""

say "## Evidence (Real Build)"
say "### Backend"
say "- backend dir: $(exists "$ROOT/backend")"
say "- backend files: $(count_files "$ROOT/backend")"
say "- requirements.txt: $(exists "$ROOT/backend/requirements.txt")"
say "- venv (.venv): $(exists "$ROOT/backend/.venv")"
say "- run script: $(exists "$ROOT/backend/run_backend_official.sh")"
say ""

say "### Frontend"
say "- frontend dir: $(exists "$ROOT/frontend")"
say "- package.json: $(exists "$ROOT/frontend/package.json")"
say "- lockfile (npm): $(exists "$ROOT/frontend/package-lock.json")"
say "- node_modules: $(exists "$ROOT/frontend/node_modules")  (size: $(dir_size "$ROOT/frontend/node_modules"))"
say "- dist: $(exists "$ROOT/frontend/dist")  (size: $(dir_size "$ROOT/frontend/dist"))"
say ""

say "## Runtime Check"
say "- 8000 /health: $(curl_try "http://127.0.0.1:8000/health")"
say "- 8000 /info:    $(curl_try "http://127.0.0.1:8000/info")"
say "- 8000 /version: $(curl_try "http://127.0.0.1:8000/version")"
say "- 8001 /health: $(curl_try "http://127.0.0.1:8001/health")"
say ""

say "## Git / GitHub Migration Truth"
if [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
  say "- repo: yes"
  say "- branch: $(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo na)"
  say "- head:   $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo na)"
  REM="$(git -C "$ROOT" remote 2>/dev/null | head -n 1 || true)"
  say "- remote: ${REM:-none}"
  if [ -n "${REM:-}" ]; then
    say "- remote url: $(git -C "$ROOT" remote get-url "$REM" 2>/dev/null || echo na)"
  fi
  say ""
  say "### git status -sb"
  say '```'
  git -C "$ROOT" status -sb 2>/dev/null || true
  say '```'
  say ""
  say "### last 5 commits"
  say '```'
  git -C "$ROOT" log -5 --oneline --decorate 2>/dev/null || true
  say '```'
else
  say "- repo: no (missing .git or git not installed)"
fi

say ""
say "## Notes"
say "- If dist=no => frontend production build not generated yet."
say "- If remote url missing => not migrated to GitHub yet."
say "- If /health no_response => backend not running (or blocked)."
say ""
say "OK: wrote $OUT"
	

