from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from app.routes import ops_git
from app.routes import uui_config
from starlette.requests import Request


async def health(request: Request):
    return JSONResponse(
        {
            "status": "ok",
            "runtime": "termux",
            "service": "station-backend",
        }
    )


async def config(request: Request):
    return JSONResponse(
        {
            "message": "Station backend (Starlette) is alive.",
            "frontend_hint": "Use /echo to test POST.",
        }
    )


async def echo(request: Request):
    try:
        data = await request.json()
    except Exception:
        data = {"error": "invalid_json"}

    return JSONResponse(
        {
            "received": data,
            "note": "This is a minimal Starlette echo endpoint.",
        }
    )


routes = [
    Route('/api/ops/git/status', ops_git.git_status, methods=['GET']),
    Route('/api/ops/git/push', ops_git.git_push, methods=['POST']),
    Route('/api/config/uui', uui_config.get_config, methods=['GET']),
    Route('/api/config/uui', uui_config.set_config, methods=['POST']),
    Route("/health", health, methods=["GET"]),
    Route("/config", config, methods=["GET"]),
    Route("/echo", echo, methods=["POST"]),
]

app = Starlette(debug=True, routes=routes)
