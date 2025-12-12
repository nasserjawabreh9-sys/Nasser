import os
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from starlette.middleware.cors import CORSMiddleware

async def health(request):
    return JSONResponse({"ok": True, "service": "station-backend", "framework": "starlette"})

async def chat(request):
    """
    Minimal safe stub for now.
    Frontend can call /api/chat and get a deterministic response.
    (We will wire external LLM cleanly in the next step.)
    """
    try:
        payload = await request.json()
    except Exception:
        payload = {}
    msg = (payload.get("message") or payload.get("prompt") or "").strip()
    return JSONResponse({
        "ok": True,
        "reply": f"[STATION] chat stub OK. You said: {msg[:500]}",
        "note": "LLM wiring will be added via a separate room/pipeline (no FastAPI dependency)."
    })

routes = [
    Route("/health", health, methods=["GET"]),
    Route("/api/chat", chat, methods=["POST"]),
]

app = Starlette(debug=True, routes=routes)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
