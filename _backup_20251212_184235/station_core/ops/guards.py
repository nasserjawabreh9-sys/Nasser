from typing import Dict, Any

def require_edit_key(payload: Dict[str, Any]) -> None:
    # This is a guard stub: backend should validate edit_key strictly.
    # For now, we only require presence to avoid accidental ops.
    k = str(payload.get("edit_key") or "").strip()
    if not k:
        raise ValueError("edit_key missing")

def require_repo_and_token(keys: Dict[str, Any]) -> None:
    token = str(keys.get("githubToken") or "").strip()
    repo = str(keys.get("githubRepo") or "").strip()
    if not token:
        raise ValueError("githubToken missing")
    if not repo or "/" not in repo:
        raise ValueError("githubRepo missing/invalid (owner/repo)")
