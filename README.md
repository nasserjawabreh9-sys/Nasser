# Station Root

Unified Station project with:

- **Backend**: FastAPI app under `backend/app/main.py`
  - Loop engine in `backend/loop_engine/`
  - Loop actions in `backend/loop_actions/`
  - Virtual env in `backend/.venv/`
  - Requirements in `backend/requirements.txt`

- **Frontend**: React + Vite under `frontend/`
  - API calls in `frontend/src/api/station_api.ts`
  - Vite config in `frontend/vite.config.ts`

- **Workspace**:
  - `workspace/loop_messages.json` and related snippets/scripts.

## Local development (Termux)

Backend:

```bash
cd ~/station_root/backend
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8800
cd ~/station_root/frontend
npm install   # first time only
npm run dev -- --host 0.0.0.0 --port 417o

