#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

RID="${1:-}"; shift || true
MSG="${1:-}"; shift || true

bash scripts/guards/guard_root_id_arg.sh "$RID"

if [ -z "$MSG" ]; then
  MSG="[R${RID}] stage"
fi

git add -A

if git diff --cached --quiet; then
  echo ">>> [stage_commit_push] no changes to commit"
else
  git commit -m "$MSG"
fi

echo ">>> [stage_commit_push] pushing to origin..."
git push
echo ">>> [stage_commit_push] push OK"
