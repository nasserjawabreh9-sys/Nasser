#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
ENVF="$ROOT/station_env.sh"
LOG="$ROOT/station_logs/loop4_runner.log"
RUNNER_ID="termux-loop4"

mkdir -p "$ROOT/station_logs"

echo "==============================" | tee -a "$LOG"
echo "[LOOP4] START $(date -Iseconds)" | tee -a "$LOG"
echo "runner_id=$RUNNER_ID" | tee -a "$LOG"
echo "==============================" | tee -a "$LOG"

# Load ENV (safe)
if [ -f "$ENVF" ]; then
  source "$ENVF" >> "$LOG" 2>&1 || true
else
  echo "[LOOP4] ERROR: station_env.sh missing" | tee -a "$LOG"
  exit 1
fi

# Backend must be running separately (your existing runner loop for uvicorn is fine)
while true; do
  # fetch next task
  RESP="$(curl -s "http://127.0.0.1:8000/uul/tasks/next?runner_id=$RUNNER_ID" || true)"
  echo "[LOOP4] next: $RESP" | tee -a "$LOG"

  HAS_TASK="$(echo "$RESP" | grep -q '"task":null' && echo no || echo yes)"
  if [ "$HAS_TASK" = "no" ]; then
    sleep 2
    continue
  fi

  TASK_ID="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["id"])' 2>/dev/null || echo 0)"
  TASK_TYPE="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["task_type"])' 2>/dev/null || echo shell)"

  if [ "$TASK_ID" = "0" ]; then
    sleep 2
    continue
  fi

  echo "[LOOP4] executing task_id=$TASK_ID type=$TASK_TYPE" | tee -a "$LOG"

  OK=true
  OUT=""
  ERR=""

  if [ "$TASK_TYPE" = "shell" ]; then
    # payload: {"cwd":"...","script_b64":"..."}
    CWD="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["payload"].get("cwd",""))' 2>/dev/null || echo "")"
    B64="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["payload"].get("script_b64",""))' 2>/dev/null || echo "")"

    if [ -z "$B64" ]; then
      OK=false
      ERR="missing script_b64"
    else
      TMP="$ROOT/station_logs/_loop4_task_${TASK_ID}.sh"
      echo "$B64" | python -c 'import sys,base64; print(base64.b64decode(sys.stdin.read()).decode("utf-8","ignore"))' > "$TMP"
      chmod +x "$TMP"
      if [ -n "$CWD" ]; then
        OUT="$(cd "$CWD" && bash "$TMP" 2>&1 || true)"
      else
        OUT="$(bash "$TMP" 2>&1 || true)"
      fi
      # naive success heuristic
      echo "$OUT" | grep -qi "error\|not found\|traceback" && OK=false || OK=true
      [ "$OK" = "false" ] && ERR="shell task reported errors"
    fi
  else
    OK=false
    ERR="unsupported task_type"
  fi

  # report
  python - <<PY
import json,subprocess,sys
task_id=int("$TASK_ID")
ok=("$OK"=="true")
payload={
  "task_id": task_id,
  "ok": ok,
  "result": {"output": """$OUT"""[:8000]},
  "error": "$ERR"
}
import urllib.request
req=urllib.request.Request("http://127.0.0.1:8000/uul/tasks/report", data=json.dumps(payload).encode("utf-8"), headers={"Content-Type":"application/json"}, method="POST")
try:
  with urllib.request.urlopen(req, timeout=10) as r:
    print(r.read().decode("utf-8","ignore"))
except Exception as e:
  print("REPORT_FAILED", e)
PY

  sleep 1
done
