from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="station-backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"ok": True, "service": "station-backend"}

# --- STATION_DB_ENDPOINTS_V1 ---
from typing import Any, Dict
from db import init_db, load_keys, save_keys, list_events, push_event

@app.on_event("startup")
def _startup():
    init_db()

@app.get("/keys")
def get_keys():
    return load_keys()

@app.post("/keys")
def post_keys(payload: Dict[str, Any]):
    # Accept {keys:{...}} or direct {openaiKey:...}
    data = payload.get("keys") if isinstance(payload.get("keys"), dict) else payload
    return save_keys(data)

@app.get("/events")
def get_events(limit: int = 50, after_id: int = 0):
    return list_events(limit=limit, after_id=after_id)

@app.post("/events")
def post_event(payload: Dict[str, Any]):
    ev_type = str(payload.get("type") or "generic")
    ev_payload = payload.get("payload") if isinstance(payload.get("payload"), dict) else payload
    return push_event(ev_type, ev_payload)

@app.post("/chat")
def chat(payload: Dict[str, Any]):
    # Safe stub so UI never breaks
    text = str(payload.get("text", "")).strip()
    if not text:
        return {"answer": "[stub] empty message"}
    # Optional: write event
    try:
        push_event("chat", {"text": text[:500]})
    except Exception:
        pass
    return {"answer": f"[stub] received: {text[:200]}"}

# --- UUL_ROOMS_OPS_AI_ROUTERS_V1 ---
from station_core.rooms.api import router as rooms_router
from station_core.ops.api import router as ops_router
from station_core.ai.api import router as ai_router

app.include_router(rooms_router)
app.include_router(ops_router)
app.include_router(ai_router)
