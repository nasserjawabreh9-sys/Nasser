import json
import os
from typing import List, Dict, Any

ROOT = os.path.expanduser("~/station_root")
WORKSPACE = os.path.join(ROOT, "workspace")
MESSAGES_PATH = os.path.join(WORKSPACE, "loop_messages.json")
TASKS_PATH = os.path.join(WORKSPACE, "loop_tasks.json")


def _ensure_workspace() -> None:
    os.makedirs(WORKSPACE, exist_ok=True)


def _read_json(path: str, default):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            try:
                return json.load(f)
            except Exception:
                return default
    return default


def _write_json(path: str, data) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def save_message(role: str, content: str) -> None:
    """
    يحفظ أي رسالة في ملف loop_messages.json
    """
    _ensure_workspace()
    data: List[Dict[str, Any]] = _read_json(MESSAGES_PATH, [])
    data.append({"role": role, "content": content})
    _write_json(MESSAGES_PATH, data)


def process_user_message(msg: str) -> str:
    """
    LOOP بسيط:
    1) يحفظ رسالة المستخدم.
    2) يولّد رد بسيط (placeholder).
    3) يحفظ رد STATION.
    """
    save_message("user", msg)
    reply = f"تم استلام رسالتك في STATION: {msg}"
    save_message("station", reply)
    return reply


def list_tasks():
    """
    يرجع جميع المهام في loop_tasks.json
    """
    _ensure_workspace()
    tasks = _read_json(TASKS_PATH, [])
    return tasks


def create_task(kind: str, payload: dict):
    """
    ينشئ مهمة جديدة (هيكل فقط، بدون تنفيذ حقيقي).
    """
    _ensure_workspace()
    tasks = _read_json(TASKS_PATH, [])
    next_id = 1
    if tasks:
        try:
            next_id = max(t.get("id", 0) for t in tasks) + 1
        except Exception:
            next_id = len(tasks) + 1

    task = {
        "id": next_id,
        "kind": kind,
        "payload": payload,
        "status": "pending",  # later: running / done / failed
    }
    tasks.append(task)
    _write_json(TASKS_PATH, tasks)
    return task
