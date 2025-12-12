#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="1100"
MODE="${1:-PROD}"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cd "$(dirname "$0")"

echo ">>> [R${ROOT_ID}] Bootstrap Architecture + Rooms + Guards (mode=${MODE})"

# --- Core dirs ---
mkdir -p \
  specs/rooms_contracts \
  specs/pipelines \
  scripts/guards \
  scripts/rooms \
  scripts/tree_authority \
  scripts/ops \
  station_meta/rooms \
  station_meta/tree \
  station_meta/bindings \
  station_meta/env \
  station_meta/locks \
  station_meta/queue \
  station_meta/dynamo \
  station_meta/stage_reports \
  station_logs

# --- Ensure task queue + event log exist ---
[ -f station_meta/queue/tasks.jsonl ] || : > station_meta/queue/tasks.jsonl
[ -f station_meta/dynamo/events.jsonl ] || : > station_meta/dynamo/events.jsonl

# --- Tree Authority: update + broadcast (create if missing) ---
if [ ! -f scripts/tree_authority/tree_update.sh ]; then
  cat > scripts/tree_authority/tree_update.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

mkdir -p station_meta/tree station_meta/bindings

# deterministic file list (skip venv/node_modules/.git)
find . -type f \
  ! -path "./.git/*" \
  ! -path "./backend/.venv/*" \
  ! -path "./frontend/node_modules/*" \
  ! -path "./station_meta/*" \
  -print | sed 's|^\./||' | sort > station_meta/tree/tree_paths.txt

# bindings.json: minimal mapping file->root_id inference (stub for now)
python - << 'PY'
import json, os, re
root_id = 1000
paths = open("station_meta/tree/tree_paths.txt","r",encoding="utf-8").read().splitlines()
bindings = {
  "version":"0.1.0",
  "generated_utc": __import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
  "default_root_id": root_id,
  "rules": [
    {"match":"specs/**", "root_id": 1100},
    {"match":"scripts/guards/**", "root_id": 1100},
    {"match":"scripts/rooms/**", "root_id": 1100},
    {"match":"station_meta/rooms/**", "root_id": 1100}
  ],
  "paths_count": len(paths)
}
json.dump(bindings, open("station_meta/bindings/bindings.json","w",encoding="utf-8"), ensure_ascii=False, indent=2)
print(f">>> [tree_update] wrote station_meta/tree/tree_paths.txt and station_meta/bindings/bindings.json")
PY
EOF
  chmod +x scripts/tree_authority/tree_update.sh
fi

if [ ! -f scripts/tree_authority/tree_broadcast.sh ]; then
  cat > scripts/tree_authority/tree_broadcast.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p station_meta/tree
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cnt="$(wc -l < station_meta/tree/tree_paths.txt 2>/dev/null || echo 0)"
{
  echo "STATION TREE BROADCAST"
  echo "ts=${ts}"
  echo "paths_count=${cnt}"
  echo "head:"
  head -n 20 station_meta/tree/tree_paths.txt 2>/dev/null || true
} > station_meta/tree/broadcast.txt
echo ">>> [tree_broadcast] wrote station_meta/tree/broadcast.txt"
EOF
  chmod +x scripts/tree_authority/tree_broadcast.sh
fi

# --- Stage/Commit/Push script (ensure exists; token-aware) ---
if [ ! -f scripts/ops/stage_commit_push.sh ]; then
  cat > scripts/ops/stage_commit_push.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

root_id="${1:-0}"
msg="${2:-stage}"

cd "$(dirname "$0")/../.."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERR: not a git repo"; exit 2; }

git add -A

if git diff --cached --quiet; then
  echo ">>> [stage_commit_push] no changes to commit"
else
  git commit -m "[R${root_id}] ${msg}"
fi

remote_url="$(git remote get-url origin)"
echo ">>> [stage_commit_push] pushing to origin..."

if [ -n "${GITHUB_TOKEN:-}" ]; then
  token_url="$(echo "$remote_url" | sed -E "s#^https://#https://x-access-token:${GITHUB_TOKEN}@#")"
  GIT_ASKPASS=true git push "$token_url" HEAD:main
else
  git push origin main
fi

echo ">>> [stage_commit_push] push OK"
EOF
  chmod +x scripts/ops/stage_commit_push.sh
fi

# --- Specs: Architecture document ---
cat > specs/station_architecture.md << EOF
# Station Architecture (Future) — R${ROOT_ID}

Generated: ${TS}
Mode: ${MODE}

## Purpose
Establish a non-breakable workflow with:
- Truth layer (tree/bindings/env/ledger)
- Guards (stop-the-world if rules violated)
- Rooms (parallel work streams)
- Orchestrator (Dynamo) enforcing locks + stage/push

## Truth Layer
- station_meta/tree/tree_paths.txt
- station_meta/tree/broadcast.txt
- station_meta/bindings/bindings.json
- station_meta/env/*
- station_meta/dynamo/events.jsonl
- station_meta/queue/tasks.jsonl
- station_meta/stage_reports/*

## Locks (single-writer)
- tree.lock
- bindings.lock
- env.lock
- stage.lock

## Rooms (initial 5)
R1 Tree & Bindings Authority
R2 Env & Deps
R3 Backend
R4 Frontend
R5 Ops & GitHub

## Hard Rules
- No work proceeds if Tree Guard fails.
- No work proceeds if Binding Guard fails.
- No pipeline proceeds if Env Guard fails.
- No output is accepted without Stage Guard (commit+push with [R####]).
EOF

# --- Rooms contracts (JSON) ---
cat > specs/rooms_contracts/R1_tree_authority.json << 'EOF'
{
  "room": "R1",
  "name": "Tree & Bindings Authority",
  "writes": ["station_meta/tree/*", "station_meta/bindings/*"],
  "locks_required": ["tree", "bindings"],
  "inputs": ["repo_fs_snapshot"],
  "outputs": ["tree_paths.txt", "bindings.json", "broadcast.txt"],
  "stop_the_world_on_fail": true
}
EOF

cat > specs/rooms_contracts/R2_env_deps.json << 'EOF'
{
  "room": "R2",
  "name": "Env & Deps",
  "writes": ["station_meta/env/*", "backend/.venv/**"],
  "locks_required": ["env"],
  "inputs": ["requirements.txt", "termux_constraints"],
  "outputs": ["env_report.json"],
  "stop_the_world_on_fail": true
}
EOF

cat > specs/rooms_contracts/R3_backend.json << 'EOF'
{
  "room": "R3",
  "name": "Backend Room",
  "writes": ["backend/**"],
  "locks_required": ["bindings"],
  "inputs": ["api_spec", "bindings.json"],
  "outputs": ["api_endpoints", "backend_report.json"],
  "stop_the_world_on_fail": true
}
EOF

cat > specs/rooms_contracts/R4_frontend.json << 'EOF'
{
  "room": "R4",
  "name": "Frontend Room",
  "writes": ["frontend/**"],
  "locks_required": ["bindings"],
  "inputs": ["uui_spec", "bindings.json"],
  "outputs": ["ui_routes", "frontend_report.json"],
  "stop_the_world_on_fail": true
}
EOF

cat > specs/rooms_contracts/R5_ops_github.json << 'EOF'
{
  "room": "R5",
  "name": "Ops & GitHub",
  "writes": ["scripts/ops/**", ".git/**"],
  "locks_required": ["stage"],
  "inputs": ["root_id", "commit_policy"],
  "outputs": ["commit", "push", "optional_tag"],
  "stop_the_world_on_fail": true
}
EOF

# --- Rooms registry (truth file) ---
cat > station_meta/rooms/rooms.json << EOF
{
  "version": "0.1.0",
  "generated_utc": "${TS}",
  "rooms": [
    {"id":"R1","name":"Tree & Bindings Authority","contract":"specs/rooms_contracts/R1_tree_authority.json","locks":["tree","bindings"]},
    {"id":"R2","name":"Env & Deps","contract":"specs/rooms_contracts/R2_env_deps.json","locks":["env"]},
    {"id":"R3","name":"Backend","contract":"specs/rooms_contracts/R3_backend.json","locks":["bindings"]},
    {"id":"R4","name":"Frontend","contract":"specs/rooms_contracts/R4_frontend.json","locks":["bindings"]},
    {"id":"R5","name":"Ops & GitHub","contract":"specs/rooms_contracts/R5_ops_github.json","locks":["stage"]}
  ]
}
EOF

# --- Guards (skeletons; return non-zero to stop) ---
cat > scripts/guards/tree_guard.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

# Guard policy (skeleton): require tree_paths exists and non-empty
if [ ! -s station_meta/tree/tree_paths.txt ]; then
  echo "GUARD_FAIL: TREE_NOT_BUILT"
  exit 10
fi

# Future: compare repo mtime vs tree build time and stop if stale
echo "GUARD_OK: TREE"
EOF
chmod +x scripts/guards/tree_guard.sh

cat > scripts/guards/binding_guard.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

if [ ! -s station_meta/bindings/bindings.json ]; then
  echo "GUARD_FAIL: BINDINGS_MISSING"
  exit 11
fi

# Future: validate every changed path is mapped to a root_id rule
echo "GUARD_OK: BINDINGS"
EOF
chmod +x scripts/guards/binding_guard.sh

cat > scripts/guards/env_guard.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

# skeleton: requirements must exist; forbid uvicorn[standard] for Termux
if [ ! -f backend/requirements.txt ]; then
  echo "GUARD_FAIL: REQUIREMENTS_MISSING"
  exit 12
fi

if grep -qE 'uvicorn\[standard\]' backend/requirements.txt; then
  echo "GUARD_FAIL: UVICORN_STANDARD_FORBIDDEN_TERMUX"
  exit 13
fi

echo "GUARD_OK: ENV_POLICY"
EOF
chmod +x scripts/guards/env_guard.sh

cat > scripts/guards/stage_guard.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
# skeleton: stage guard enforced by stage_commit_push.sh policy
echo "GUARD_OK: STAGE_POLICY"
EOF
chmod +x scripts/guards/stage_guard.sh

# --- Rooms worker + dispatcher (skeletons) ---
cat > scripts/rooms/room_worker.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
# Skeleton: future worker reads tasks.jsonl and executes room-specific steps with locks.
echo "ROOM_WORKER_STUB"
EOF
chmod +x scripts/rooms/room_worker.sh

cat > scripts/rooms/dispatch.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
# Skeleton: future dispatcher assigns tasks to rooms; ensures guards + locks + merge.
echo "DISPATCH_STUB"
EOF
chmod +x scripts/rooms/dispatch.sh

# --- Pipelines stubs (for future orchestration) ---
cat > specs/pipelines/P1100_architecture.json << EOF
{
  "pipeline": "P1100_architecture",
  "root_id": ${ROOT_ID},
  "generated_utc": "${TS}",
  "steps": [
    {"name":"tree_update","cmd":"bash scripts/tree_authority/tree_update.sh"},
    {"name":"tree_broadcast","cmd":"bash scripts/tree_authority/tree_broadcast.sh"},
    {"name":"guards_tree","cmd":"bash scripts/guards/tree_guard.sh"},
    {"name":"guards_bindings","cmd":"bash scripts/guards/binding_guard.sh"}
  ]
}
EOF

# --- Refresh tree + broadcast now ---
bash scripts/tree_authority/tree_update.sh
bash scripts/tree_authority/tree_broadcast.sh

# --- Stage/Commit/Push to GitHub with Root ID ---
bash scripts/ops/stage_commit_push.sh "${ROOT_ID}" "[${MODE}] R${ROOT_ID} Architecture+Rooms+Guards bootstrap"

echo ">>> [R${ROOT_ID}] DONE"
echo "Next: specs/rooms_contracts/* , scripts/guards/* , station_meta/rooms/rooms.json"
