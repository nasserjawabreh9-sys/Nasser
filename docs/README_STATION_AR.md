# Station (UUL Standard)

## Run Local (Termux)
- Backend:
  - cd ~/station_root/backend
  - source .venv/bin/activate
  - python -m uvicorn app:app --host 0.0.0.0 --port 8000
- Frontend:
  - cd ~/station_root/frontend
  - export VITE_BACKEND_URL=http://127.0.0.1:8000
  - npm run dev -- --host 0.0.0.0 --port 5173

## APIs
- GET /health
- Rooms: /rooms
- Private AI stub: POST /ai/route
- Ops stubs: /ops/*
