import json
import os
from datetime import datetime
from typing import Any, Dict, List

from .engine import WORKSPACE
from .plan_builder import PLAN_PATH, build_plan_from_messages


OUT_DIR = os.path.join(WORKSPACE, "out")


def ensure_out_dir() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)


def load_plan() -> Dict[str, Any]:
    if not os.path.exists(PLAN_PATH):
        # إذا لا يوجد plan، نبنيه من الرسائل أولاً
        return build_plan_from_messages()
    with open(PLAN_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def run_actions_from_plan() -> Dict[str, Any]:
    """
    تنفيذ بسيط:
    - نقرأ plan.json
    - ننشئ ملف في workspace/out يحتوي ملخّص الخطة
    """
    ensure_out_dir()
    plan = load_plan()
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_name = f"station_plan_snapshot_{ts}.txt"
    file_path = os.path.join(OUT_DIR, file_name)

    lines: List[str] = []
    lines.append("STATION – PLAN SNAPSHOT")
    lines.append(f"Generated at: {ts}")
    lines.append("")
    lines.append("--- Summary ---")
    for k, v in plan.get("summary", {}).items():
        lines.append(f"{k}: {v}")

    lines.append("")
    lines.append("--- Steps ---")
    for step in plan.get("steps", []):
        lines.append(f"- [{step.get('status')}] ({step.get('id')}) {step.get('description')}")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    return {
        "created_path": file_path,
        "file_name": file_name,
        "plan_status": "snapshot_created",
    }


def list_out_files() -> Dict[str, Any]:
    ensure_out_dir()
    files_info: List[Dict[str, Any]] = []
    for name in sorted(os.listdir(OUT_DIR)):
        full = os.path.join(OUT_DIR, name)
        if os.path.isfile(full):
            size = os.path.getsize(full)
            files_info.append({"name": name, "size": size})
    return {"files": files_info}
