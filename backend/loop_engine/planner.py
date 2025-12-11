import json
import os
from typing import Dict, Any

from .engine import WORKSPACE, ensure_workspace, load_messages

PLAN_PATH = os.path.join(WORKSPACE, "plan.json")


def build_plan_from_log() -> Dict[str, Any]:
    """
    يقرأ آخر رسالة user من السجل ويبني خطة أولية بسيطة.
    النتيجة تُكتب في workspace/plan.json.
    """
    ensure_workspace()
    msgs = load_messages()

    latest_user = None
    for m in reversed(msgs):
        if m.get("role") == "user":
            latest_user = m
            break

    if latest_user is None:
        plan = {
            "status": "no_user_message",
            "summary": "لا يوجد رسالة مستخدم في السجل بعد.",
        }
    else:
        text = latest_user.get("content") or ""
        plan = {
            "status": "ok",
            "summary": "خطة أولية مبسّطة مبنية على آخر رسالة.",
            "latest_user_message": text,
            # لاحقاً ممكن نطوّر هذه الحقول (نوع الملف، المسار، إلخ)
            "suggested_target_type": "text",
            "suggested_filename": "note_001.txt",
        }

    with open(PLAN_PATH, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

    return plan
