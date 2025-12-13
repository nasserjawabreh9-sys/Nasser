from __future__ import annotations
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any

def now_ts() -> int:
    return int(time.time())

@dataclass
class RoomState:
    name: str
    status: str = "idle"  # idle|running|done|error
    updated_at: int = field(default_factory=now_ts)
    last_error: str = ""

@dataclass
class Task:
    id: int
    created_at: int
    status: str          # queued|running|done|error
    task_type: str       # shell|python|noop
    payload: Dict[str, Any]
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    runner_id: Optional[str] = None

@dataclass
class UULState:
    running: bool = False
    started_at: Optional[int] = None
    rooms: Dict[str, RoomState] = field(default_factory=dict)
    logs: List[str] = field(default_factory=list)
    tasks: List[Task] = field(default_factory=list)
    next_task_id: int = 1

    def log(self, msg: str) -> None:
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        line = f"{ts} {msg}"
        self.logs.append(line)
        if len(self.logs) > 4000:
            self.logs = self.logs[-2000:]

STATE = UULState()
