from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route

async def health(request):
    return JSONResponse({"ok": True, "service": "station-backend", "engine": "starlette"})

routes = [
    Route("/health", health, methods=["GET"]),
]

app = Starlette(debug=False, routes=routes)
