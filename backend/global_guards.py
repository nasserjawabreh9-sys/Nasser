import os
import time
from pathlib import Path
from typing import Optional

LOCK_DIR = Path(os.environ.get("STATION_LOCK_DIR", str(Path.home() / "station_root" / "global" / "locks")))
LOCK_DIR.mkdir(parents=True, exist_ok=True)

def require_edit_key(headers) -> Optional[str]:
    key = os.environ.get("EDIT_MODE_KEY", "1234")
    got = headers.get("x-edit-key") or headers.get("X-Edit-Key")
    if not got or got != key:
        return "unauthorized"
    return None

def lock_path(name: str) -> Path:
    return LOCK_DIR / f"{name}.lock"

def try_lock(name: str, ttl_sec: int = 120) -> bool:
    p = lock_path(name)
    now = int(time.time())
    if p.exists():
        try:
            ts = int(p.read_text().strip() or "0")
        except Exception:
            ts = 0
        if now - ts < ttl_sec:
            return False
    p.write_text(str(now))
    return True

def unlock(name: str) -> None:
    p = lock_path(name)
    try:
        p.unlink(missing_ok=True)
    except Exception:
        pass
