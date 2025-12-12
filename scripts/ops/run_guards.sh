#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

echo ">>> [GUARDS] tree_guard"
bash scripts/guards/tree_guard.sh

echo ">>> [GUARDS] binding_guard"
bash scripts/guards/binding_guard.sh

echo ">>> [GUARDS] env_guard"
bash scripts/guards/env_guard.sh

echo ">>> [GUARDS] stage_guard"
bash scripts/guards/stage_guard.sh

echo ">>> [GUARDS] ALL OK"
