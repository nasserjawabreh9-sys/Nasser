from typing import Any, Dict
from fastapi import APIRouter
from station_core.rooms.engine import add_message

router = APIRouter(prefix="/ai", tags=["ai"])

@router.post("/route")
def ai_route(payload: Dict[str, Any]):
    # This is a deterministic local stub:
    # - It records the message into the room
    # - It returns a structured response that UI can render
    room_id = str(payload.get("room_id") or "9001")
    text = str(payload.get("text") or "").strip()
    if not text:
        return {"ok": True, "answer": "[stub] empty", "room_id": room_id}

    add_message(room_id, "user", text)

    # Simple local "private intelligence" policy stub:
    # classify intent
    t = text.lower()
    intent = "general"
    if "deploy" in t or "render" in t:
        intent = "deploy_ops"
    elif "db" in t or "sqlite" in t:
        intent = "data_ops"
    elif "room" in t:
        intent = "rooms"
    elif "termux" in t or "shell" in t or "cmd" in t:
        intent = "termux_like"

    answer = f"[stub-private-ai] intent={intent} | received={text[:200]}"
    add_message(room_id, "system", answer)

    return {
        "ok": True,
        "room_id": room_id,
        "intent": intent,
        "answer": answer,
        "policy": {"external_calls": False, "notes": "Private AI stub only (no network)."},
    }
