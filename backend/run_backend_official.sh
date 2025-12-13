#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
[ -f .venv/bin/activate ] && source .venv/bin/activate
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"
export ENV="${ENV:-local}"
export RUNTIME="${RUNTIME:-termux}"
export ENGINE="${ENGINE:-starlette-core}"
export STATION_EDIT_KEY="${STATION_EDIT_KEY:-1234}"
export STATION_RUNNER_KEY="${STATION_RUNNER_KEY:-runner-1234}"
echo ">>> [station] backend main:app @ $HOST:$PORT"
python -m uvicorn main:app --host "$HOST" --port "$PORT"
