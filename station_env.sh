#!/data/data/com.termux/files/usr/bin/bash
set -e

# Keys are OPTIONAL here. Prefer setting them from UI (Station Settings) or export in the shell.
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export STATION_OPENAI_API_KEY="${STATION_OPENAI_API_KEY:-$OPENAI_API_KEY}"
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"
export RENDER_API_KEY="${RENDER_API_KEY:-}"

# Ops/Edit default (change from UI later if needed)
export EDIT_MODE_KEY="${EDIT_MODE_KEY:-1234}"

# Termux-safe encoding
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

echo "[station_env] loaded (keys may be empty)"
