from typing import Any, Dict
from fastapi import APIRouter
from .guards import require_edit_key, require_repo_and_token

router = APIRouter(prefix="/ops", tags=["ops"])

# Important: No auto-create repo. No git init. No destructive ops.
# These endpoints are "wiring stubs" to match UI buttons.

@router.post("/git_status")
def git_status(payload: Dict[str, Any]):
    require_edit_key(payload)
    keys = payload.get("keys") if isinstance(payload.get("keys"), dict) else {}
    require_repo_and_token(keys)
    return {"ok": True, "mode": "stub", "note": "Implement server-side git status on a Docker-capable host."}

@router.post("/git_push")
def git_push(payload: Dict[str, Any]):
    require_edit_key(payload)
    keys = payload.get("keys") if isinstance(payload.get("keys"), dict) else {}
    require_repo_and_token(keys)
    return {"ok": True, "mode": "stub", "note": "Implement server-side stage/commit/push on host. Guard prevents repo auto-create."}

@router.post("/render_deploy")
def render_deploy(payload: Dict[str, Any]):
    require_edit_key(payload)
    return {"ok": True, "mode": "stub", "note": "Implement Render deploy trigger via Render API on host."}
