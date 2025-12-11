from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from starlette.middleware.cors import CORSMiddleware
import os

async def health(request):
    return JSONResponse({
        "status": "ok",
        "runtime": "station",
        "env": os.environ.get("STATION_ENV", "termux"),
        "engine": "starlette-core"
    })

routes = [
    Route("/health", health),
]

app = Starlette(debug=True, routes=routes)

# CORS for frontend (Vite on 4173)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
