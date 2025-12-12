#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1300"
MODE="${1:-PROD}"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo ">>> [R${ROOT_ID}] Rooms↔Pipelines Map + AutoTags + Status Snapshot (mode=${MODE})"

mkdir -p specs/pipelines station_meta/status scripts/ops scripts/rooms

# --- 1) Room→Pipeline mapping (truth) ---
cat > specs/pipelines/rooms_pipeline_map.json << EOF
{
  "version": "0.1.0",
  "generated_utc": "${TS}",
  "rooms": {
    "R1": { "locks": ["tree","bindings"], "pipelines": ["bootstrap_validate"] },
    "R2": { "locks": ["env"],           "pipelines": ["termux_env_prepare_backend"] },
    "R3": { "locks": ["bindings"],      "pipelines": ["backend_health_check"] },
    "R4": { "locks": ["bindings"],      "pipelines": ["frontend_build_check"] },
    "R5": { "locks": ["stage"],         "pipelines": ["stage_only"] }
  },
  "policy": {
    "stop_the_world_on_guard_fail": true,
    "single_writer_locks": true,
    "stage_every_root": true
  }
}
EOF

# --- 2) Add missing pipeline stubs (Termux-safe) ---
python - << 'PY'
import json, os
cfg_path="station_meta/dynamo/dynamo_config.json"
cfg=json.load(open(cfg_path,"r",encoding="utf-8"))

pipes=cfg.setdefault("pipelines", {})

# frontend build check (no node_modules assumption; just validates file exists)
pipes.setdefault("frontend_build_check", [
  {"name":"frontend_sanity", "cmd":"bash -lc 'test -f frontend/package.json && echo FRONTEND_OK'"},
  {"name":"api_client_sanity","cmd":"bash -lc 'test -f frontend/src/api/station_api.ts && echo API_CLIENT_OK'"}
])

# stage only pipeline
pipes.setdefault("stage_only", [
  {"name":"noop","cmd":"bash -lc \"echo STAGE_ONLY\""}
])

json.dump(cfg, open(cfg_path,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(">>> pipelines ensured: frontend_build_check, stage_only")
PY

# --- 3) AutoTag helper: tag R#### on each stage commit (lightweight) ---
cat > scripts/ops/tag_root.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
root_id="${1:-}"
[ -n "$root_id" ] || { echo "Usage: tag_root.sh <ROOT_ID>"; exit 2; }

tag="R${root_id}"
if git rev-parse "$tag" >/dev/null 2>&1; then
  echo ">>> [tag_root] tag exists: $tag"
  exit 0
fi

git tag -a "$tag" -m "Root tag $tag"
echo ">>> [tag_root] created tag: $tag"
EOF
chmod +x scripts/ops/tag_root.sh

# Patch stage_commit_push.sh: after commit, tag root if not exists; push tags
python - << 'PY'
import re, pathlib
p=pathlib.Path("scripts/ops/stage_commit_push.sh")
s=p.read_text(encoding="utf-8")

if "tag_root.sh" not in s:
    # inject after commit block
    s=re.sub(r'(git commit -m "\[R\$\{root_id\}\] \${msg}"\nfi\n)',
             r'\1\n# --- Auto tag root ---\nbash scripts/ops/tag_root.sh "${root_id}" || true\n', s, flags=re.M)

    # inject push tags after push
    s=re.sub(r'(git push origin main\n\necho ">>> \[stage_commit_push\] push OK")',
             r'git push origin main\n\ngit push origin --tags || true\n\necho ">>> [stage_commit_push] push OK"', s, flags=re.M)

    # token push path: push tags too
    s=re.sub(r'(GIT_ASKPASS=true git push "\$token_url" HEAD:main\n)',
             r'\1GIT_ASKPASS=true git push "$token_url" --tags || true\n', s, flags=re.M)

    p.write_text(s, encoding="utf-8")
    print(">>> stage_commit_push.sh patched: autotag + push tags")
else:
    print(">>> stage_commit_push.sh already patched")
PY

# --- 4) Status Snapshot generator (events.jsonl → status.json) ---
cat > scripts/ops/status_snapshot.py << 'PY'
import json, os
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
EV=os.path.join(ROOT,"station_meta/dynamo/events.jsonl")
OUT=os.path.join(ROOT,"station_meta/status/status.json")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def read_events():
    if not os.path.exists(EV): return []
    ev=[]
    with open(EV,"r",encoding="utf-8") as f:
        for line in f:
            line=line.strip()
            if not line: continue
            try: ev.append(json.loads(line))
            except: pass
    return ev

def build_status(events):
    # last status per (mode, root, pipeline, step)
    last={}
    for e in events:
        key=(e.get("mode"), e.get("root_id"), e.get("pipeline"), e.get("step_index"))
        last[key]=e

    # summarize per pipeline
    pipelines={}
    for (mode,rid,pipe,_), e in last.items():
        pk=f"{mode}::R{rid}::{pipe}"
        pipelines.setdefault(pk, {"mode":mode,"root_id":rid,"pipeline":pipe,"last_ts":None,"failed":0,"succeeded":0})
        pipelines[pk]["last_ts"]=max(pipelines[pk]["last_ts"] or "", e.get("ts") or "")
        if e.get("status")=="failed": pipelines[pk]["failed"]+=1
        if e.get("status")=="succeeded": pipelines[pk]["succeeded"]+=1

    # recent tails
    tail=events[-30:] if len(events)>30 else events

    return {
        "generated_utc": utc(),
        "events_total": len(events),
        "pipelines": sorted(pipelines.values(), key=lambda x:(x["mode"],x["root_id"],x["pipeline"])),
        "tail": tail
    }

def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    ev=read_events()
    st=build_status(ev)
    json.dump(st, open(OUT,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
    print(">>> [status_snapshot] wrote station_meta/status/status.json")
    print(f">>> events_total={st['events_total']} pipelines={len(st['pipelines'])}")

if __name__=="__main__":
    main()
PY
chmod +x scripts/ops/status_snapshot.py

# --- 5) Add Dynamo pipeline: status_snapshot ---
python - << 'PY'
import json
cfg_path="station_meta/dynamo/dynamo_config.json"
cfg=json.load(open(cfg_path,"r",encoding="utf-8"))
pipes=cfg.setdefault("pipelines",{})
pipes.setdefault("status_snapshot",[
  {"name":"snapshot","cmd":"python scripts/ops/status_snapshot.py"}
])
json.dump(cfg, open(cfg_path,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(">>> added pipeline: status_snapshot")
PY

# --- 6) Run snapshot once (no services) ---
python scripts/ops/status_snapshot.py >/dev/null 2>&1 || true

# --- 7) Stage/commit/push with tag ---
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} Rooms↔Pipelines map + AutoTag + Status snapshot"

echo ">>> [R${ROOT_ID}] DONE"
echo "Check:"
echo "  - specs/pipelines/rooms_pipeline_map.json"
echo "  - station_meta/status/status.json"
echo "  - git tag | tail"
