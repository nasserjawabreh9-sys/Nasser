from fastapi import APIRouter, HTTPException
from ..schemas import ChatRequest, ChatResponse
from ..config import get_openai_key
import httpx
import os

router = APIRouter(prefix="/chat", tags=["chat"])

OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
MODEL_NAME = os.getenv("STATION_MODEL_NAME", "gpt-4.1-mini")

@router.post("", response_model=ChatResponse)
async def chat(req: ChatRequest):
    api_key = get_openai_key()
    if not api_key:
        raise HTTPException(status_code=500, detail="OpenAI API key not configured on STATION.")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": MODEL_NAME,
        "messages": [
            {"role": "system", "content": "You are STATION assistant for Nasser."},
            {"role": "user", "content": req.message},
        ],
    }

    async with httpx.AsyncClient(timeout=40.0) as client:
        r = await client.post(OPENAI_API_URL, headers=headers, json=payload)
        if r.status_code != 200:
            raise HTTPException(status_code=500, detail=f"OpenAI error: {r.text}")

        data = r.json()
        reply = data["choices"][0]["message"]["content"]
        return ChatResponse(reply=reply)
