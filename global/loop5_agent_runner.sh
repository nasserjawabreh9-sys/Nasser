#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
ENV="$ROOT/station_env.sh"
LOG="$ROOT/global/logs/loop5_agent_runner.log"
API="http://127.0.0.1:8000"
EDIT="${EDIT_MODE_KEY:-1234}"

mkdir -p "$(dirname "$LOG")"

source "$ENV" || true

echo "==== LOOP5 START $(date -Iseconds) ====" | tee -a "$LOG"

while true; do
  JSON=$(curl -s "$API/agent/tasks/recent?limit=10" -H "x-edit-key: $EDIT" || true)

  # Extract queued tasks with python (Termux-safe)
  python - <<'PY' "$JSON" "$ROOT" "$LOG"
import sys, json, base64, os, subprocess, time
data_raw = sys.argv[1]
root = sys.argv[2]
log = sys.argv[3]

def w(msg):
    with open(log, "a", encoding="utf-8") as f:
        f.write(msg + "\n")

try:
    data = json.loads(data_raw) if data_raw else {}
except Exception:
    data = {}

items = data.get("items") or []
queued = [it for it in items if (it.get("status") == "queued") and (it.get("task_type") == "shell")]

if not queued:
    sys.exit(0)

# Best-effort: execute ONLY the newest queued task to reduce concurrency risk
it = queued[0]
tid = it.get("id")
payload = it.get("payload") or {}
cwd = payload.get("cwd") or root
b64 = payload.get("script_b64") or ""
try:
    script = base64.b64decode(b64).decode("utf-8", "ignore")
except Exception:
    script = ""

if not script.strip():
    w(f"[loop5] task {tid} missing script")
    sys.exit(0)

tmp = os.path.join(root, "global", "tmp_task.sh")
os.makedirs(os.path.dirname(tmp), exist_ok=True)
with open(tmp, "w", encoding="utf-8") as f:
    f.write(script + "\n")
os.chmod(tmp, 0o755)

w(f"[loop5] executing task {tid} in {cwd}")
p = subprocess.run([tmp], cwd=cwd, capture_output=True, text=True)
w(f"[loop5] task {tid} rc={p.returncode}")
if p.stdout:
    w("[loop5] stdout:\n" + p.stdout.strip())
if p.stderr:
    w("[loop5] stderr:\n" + p.stderr.strip())
PY

  sleep 2
done
