from __future__ import annotations
from typing import Any, Dict, Optional
from .state import STATE, Task, now_ts

def submit(task_type: str, payload: Dict[str, Any]) -> int:
    tid = STATE.next_task_id
    STATE.next_task_id += 1
    t = Task(
        id=tid,
        created_at=now_ts(),
        status="queued",
        task_type=task_type,
        payload=payload,
    )
    STATE.tasks.append(t)
    STATE.log(f"[taskbus] submitted id={tid} type={task_type}")
    return tid

def next_task(runner_id: str) -> Optional[Task]:
    # find first queued
    for t in STATE.tasks:
        if t.status == "queued":
            t.status = "running"
            t.runner_id = runner_id
            STATE.log(f"[taskbus] dispatch id={t.id} runner={runner_id}")
            return t
    return None

def report(task_id: int, ok: bool, result: Dict[str, Any] | None = None, error: str | None = None) -> bool:
    for t in STATE.tasks:
        if t.id == task_id:
            t.status = "done" if ok else "error"
            t.result = result
            t.error = error
            STATE.log(f"[taskbus] report id={task_id} status={t.status}")
            return True
    return False

def recent(limit: int = 20):
    return list(reversed(STATE.tasks))[:max(1, min(200, limit))]
