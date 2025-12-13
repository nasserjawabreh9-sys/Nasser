#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"
echo "==[GITHUB PUSH]=="
git status -sb || true
echo
echo "Run:"
echo "  git add -A"
echo "  git commit -m \"station: uul-extra digital factory v2\""
echo "  git push -u origin main"
