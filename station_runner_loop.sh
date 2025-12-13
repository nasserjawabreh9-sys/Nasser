#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
LOG_DIR="$ROOT/station_logs"
ENV="$ROOT/station_env.sh"
BE="$ROOT/backend"

mkdir -p "$LOG_DIR"

# shellcheck disable=SC1091
source "$ROOT/scripts/global_guard.sh"

ensure_file "$ENV" "create station_env.sh" || exit 1
# shellcheck disable=SC1090
source "$ENV" || true

ensure_dir "$BE" || exit 1
ensure_venv "$BE" || true

while true; do
  port_kill 8000

  run_with_repair "backend_run" "$BE" bash -lc "./run_backend_official.sh" || true

  # If backend is up, monitor health; if down, loop restarts.
  health_wait "http://127.0.0.1:8000/health" 10 || true
  sleep 2
done
