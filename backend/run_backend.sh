#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/station_root/backend"
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8810
