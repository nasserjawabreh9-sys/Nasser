#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT_ID="${1:-0}"
MSG="${2:-"station stage"}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "NOT_A_GIT_REPO"
  exit 0
}

git add -A

# Commit only if there are changes
if git diff --cached --quiet; then
  echo ">>> [stage_commit_push] no changes to commit"
else
  git commit -m "[R${ROOT_ID}] ${MSG}" || true
fi

# Push is best-effort unless STRICT_PUSH=1
STRICT_PUSH="${STRICT_PUSH:-0}"

if git remote get-url origin >/dev/null 2>&1; then
  echo ">>> [stage_commit_push] pushing to origin..."
  if git push origin main; then
    echo ">>> [stage_commit_push] push OK"
  else
    echo ">>> [stage_commit_push] push FAILED"
    if [ "$STRICT_PUSH" = "1" ]; then
      exit 9
    fi
    exit 0
  fi
else
  echo ">>> [stage_commit_push] no origin remote; skipping push"
fi

exit 0
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

root_id="${1:-0}"
msg="${2:-stage}"

cd "$(dirname "$0")/../.."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERR: not a git repo"
  exit 2
}

git add -A

if git diff --cached --quiet; then
  echo ">>> [STAGE] Nothing to commit."
else
  git commit -m "[R${root_id}] ${msg}" >/dev/null
  echo ">>> [STAGE] Commit created."
fi

remote_url="$(git remote get-url origin)"

if [ -n "${GITHUB_TOKEN:-}" ]; then
  token_url="$(echo "$remote_url" | sed -E "s#^https://#https://x-access-token:${GITHUB_TOKEN}@#")"
  GIT_ASKPASS=true git push "$token_url" HEAD:main
GIT_ASKPASS=true git push "$token_url" --tags || true
else
  git push origin main
fi

echo ">>> [STAGE] Push done."


