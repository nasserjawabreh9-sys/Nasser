#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[STATION] Unified build starting..."

# Backend bootstrap (idempotent)
if [ -f "$HOME/station_root/scripts/station_bootstrap_backend.sh" ]; then
  "$HOME/station_root/scripts/station_bootstrap_backend.sh"
else
  echo "[STATION] ERROR: station_bootstrap_backend.sh not found."
  exit 1
fi

# Frontend bootstrap (idempotent)
if [ -f "$HOME/station_root/scripts/station_bootstrap_frontend.sh" ]; then
  "$HOME/station_root/scripts/station_bootstrap_frontend.sh"
else
  echo "[STATION] ERROR: station_bootstrap_frontend.sh not found."
  exit 1
fi

# Build frontend for production (optional, but good to have)
cd "$HOME/station_root/frontend"
echo "[STATION] Running npm run build..."
npm run build

echo "[STATION] Unified build completed successfully."
