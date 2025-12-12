from typing import Any, Dict
from fastapi import APIRouter
from .engine import list_rooms, ensure_room, rename_room, add_message, get_messages

router = APIRouter(prefix="/rooms", tags=["rooms"])

@router.get("")
def rooms_list():
    return {"ok": True, "rooms": list_rooms()}

@router.post("/ensure")
def rooms_ensure(payload: Dict[str, Any]):
    room_id = str(payload.get("room_id") or "9001")
    title = payload.get("title")
    return ensure_room(room_id, str(title) if title else None)

@router.post("/rename")
def rooms_rename(payload: Dict[str, Any]):
    room_id = str(payload.get("room_id") or "9001")
    title = str(payload.get("title") or f"Room {room_id}")
    return rename_room(room_id, title)

@router.get("/{room_id}/messages")
def rooms_messages(room_id: str, limit: int = 50):
    return {"ok": True, "messages": get_messages(room_id, limit=limit)}

@router.post("/{room_id}/messages")
def rooms_add_message(room_id: str, payload: Dict[str, Any]):
    role = str(payload.get("role") or "user")
    text = str(payload.get("text") or "")
    return add_message(room_id, role, text)
