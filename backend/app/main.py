from fastapi import FastAPI
from .routes import config as config_routes
from .routes import chat as chat_routes

app = FastAPI(title="STATION Backend", version="1.0.0")

@app.get("/health")
async def health():
    return {"status": "ok", "service": "station-backend"}

app.include_router(config_routes.router)
app.include_router(chat_routes.router)
