import json
import os
from typing import Any, Dict, List

from .engine import WORKSPACE, load_messages

PLAN_PATH = os.path.join(WORKSPACE, "plan.json")


def build_plan_from_messages() -> Dict[str, Any]:
    """
    خطة بسيطة من الرسائل:
    - نعتبر كل رسالة user = خطوة.
    - نحفظ plan.json داخل workspace.
    """
    msgs = load_messages()
    user_msgs: List[str] = [
        m["content"] for m in msgs if m.get("role") == "user"
    ]

    steps = []
    for idx, txt in enumerate(user_msgs, start=1):
        steps.append(
            {
                "id": idx,
                "title": f"خطوة {idx}",
                "description": txt,
                "status": "pending",
            }
        )

    plan: Dict[str, Any] = {
        "summary": {
            "total_messages": len(msgs),
            "user_steps": len(steps),
        },
        "steps": steps,
    }

    os.makedirs(WORKSPACE, exist_ok=True)
    with open(PLAN_PATH, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

    return plan
