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
