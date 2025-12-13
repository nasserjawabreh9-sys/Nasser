#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
RUNNER_ID="${RUNNER_ID:-termux}"
RUNNER_KEY="${STATION_RUNNER_KEY:-runner-1234}"

WORKDIR="${WORKDIR:-$HOME/station_root}"
LOGDIR="$HOME/station_root/station_logs/runner"
mkdir -p "$LOGDIR"

echo ">>> [runner] BASE_URL=$BASE_URL RUNNER_ID=$RUNNER_ID WORKDIR=$WORKDIR"

run_task_shell() {
  local tid="$1"
  local script_b64="$2"
  local cwd="$3"

  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local out="$LOGDIR/task_${tid}_${ts}.out.log"
  local err="$LOGDIR/task_${tid}_${ts}.err.log"

  mkdir -p "$cwd"

  python - <<PY
import base64,sys
s = base64.b64decode("$script_b64".encode("utf-8")).decode("utf-8","ignore")
open("$LOGDIR/task_${tid}_${ts}.sh","w",encoding="utf-8").write(s+"\n")
PY

  chmod +x "$LOGDIR/task_${tid}_${ts}.sh"

  set +e
  ( cd "$cwd" && bash "$LOGDIR/task_${tid}_${ts}.sh" ) >"$out" 2>"$err"
  local rc=$?
  set -e

  local out_tail err_tail
  out_tail="$(tail -n 120 "$out" 2>/dev/null || true)"
  err_tail="$(tail -n 120 "$err" 2>/dev/null || true)"

  if [ $rc -eq 0 ]; then
    curl -s -X POST "$BASE_URL/agent/tasks/result" \
      -H "x-runner-key: $RUNNER_KEY" -H "Content-Type: application/json" \
      -d "$(python - <<PY
import json
print(json.dumps({
  "task_id": int("$tid"),
  "ok": True,
  "result": {"rc": $rc, "stdout_tail": """$out_tail""", "stderr_tail": """$err_tail""", "out_log": "$out", "err_log": "$err"}
}))
PY
)" >/dev/null
  else
    curl -s -X POST "$BASE_URL/agent/tasks/result" \
      -H "x-runner-key: $RUNNER_KEY" -H "Content-Type: application/json" \
      -d "$(python - <<PY
import json
print(json.dumps({
  "task_id": int("$tid"),
  "ok": False,
  "error": "command_failed",
  "result": {"rc": $rc, "stdout_tail": """$out_tail""", "stderr_tail": """$err_tail""", "out_log": "$out", "err_log": "$err"}
}))
PY
)" >/dev/null
  fi
}

while true; do
  j="$(curl -s "$BASE_URL/agent/tasks/next?runner_id=$RUNNER_ID" -H "x-runner-key: $RUNNER_KEY" || true)"
  if [ -z "$j" ]; then
    sleep 1
    continue
  fi

  python - <<PY
import json,sys
obj=json.loads("""$j""")
t=obj.get("task")
if not t:
    sys.exit(10)
print(t["id"])
PY
  rc=$?

  if [ $rc -eq 10 ]; then
    sleep 1
    continue
  fi

  tid="$(python - <<PY
import json
obj=json.loads("""$j""")
print(obj["task"]["id"])
PY
)"
  ttype="$(python - <<PY
import json
obj=json.loads("""$j""")
print(obj["task"]["task_type"])
PY
)"

  if [ "$ttype" != "shell" ]; then
    # unsupported task type
    curl -s -X POST "$BASE_URL/agent/tasks/result" \
      -H "x-runner-key: $RUNNER_KEY" -H "Content-Type: application/json" \
      -d "{\"task_id\":$tid,\"ok\":false,\"error\":\"unsupported_task_type\"}" >/dev/null || true
    continue
  fi

  script_b64="$(python - <<PY
import json
obj=json.loads("""$j""")
print(obj["task"]["payload"].get("script_b64",""))
PY
)"
  cwd="$(python - <<PY
import json,os
obj=json.loads("""$j""")
print(obj["task"]["payload"].get("cwd", os.getenv("HOME") + "/station_root"))
PY
)"

  echo ">>> [runner] got task=$tid type=$ttype cwd=$cwd"
  run_task_shell "$tid" "$script_b64" "$cwd"
done
