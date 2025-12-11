#!/data/data/com.termux/files/usr/bin/bash
set -e

echo ">>> [LOOP] Upgrading STATION to LOOP v1 (structure only, no keys)..."

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
WORK="$ROOT/workspace"

echo ">>> [LOOP] ROOT: $ROOT"
mkdir -p "$BACK" "$FRONT" "$WORK"
mkdir -p "$WORK/snippets" "$WORK/scripts" "$WORK/out"

# =========================
# 1) Backend: app/main.py
# =========================
echo ">>> [LOOP] Writing backend app/main.py (loop engine stub)..."

cat > "$BACK/app/main.py" << 'PY'
# -*- coding: utf-8 -*-
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent  # backend/
WORKSPACE_DIR = BASE_DIR.parent / "workspace"      # station_root/workspace


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


class PlanRequest(BaseModel):
    goal: str


class PlanStep(BaseModel):
    id: int
    text: str


class PlanResponse(BaseModel):
    goal: str
    steps: List[PlanStep]


class FileWriteRequest(BaseModel):
    path: str
    content: str


class WorkspaceFile(BaseModel):
    path: str
    size: int


class WorkspaceListResponse(BaseModel):
    files: List[WorkspaceFile]


app = FastAPI(
    title="Station Backend – LOOP v1",
    version="0.3.0",
    description="STATION minimal loop: health, echo, chat-stub, loop-plan, workspace I/O.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    """
    حالة الباك-إند + ميزات اللوب الحالية.
    """
    return {
        "status": "ok",
        "service": "station_backend",
        "port": 8810,
        "features": [
            "health",
            "echo",
            "chat_stub",
            "loop_plan",
            "workspace_list",
            "workspace_write",
        ],
        "workspace": str(WORKSPACE_DIR),
    }


@app.get("/")
def root():
    return {
        "message": "Station backend (LOOP v1) running.",
        "hint": "Use /health, /api/echo, /api/chat, /api/loop/plan, /api/workspace/*",
    }


@app.get("/api/echo")
def echo(msg: str = "hello"):
    """
    إيكو بسيط لاختبار الاتصال.
    """
    return {"echo": msg}


@app.post("/api/chat", response_model=ChatResponse)
def chat(body: ChatRequest):
    """
    شات STUB (بدون LLM خارجي):
    - يستقبل الرسالة.
    - يرجع رد منسّق يوضح أن هذا مجرد لوب داخلي.
    """
    reply = (
        "LOOP-STUB REPLY:\n"
        "-----------------\n"
        f"استلمت رسالتك:\n{body.message}\n\n"
        "⚙ حاليًا اللوب يعمل بدون LLM خارجي.\n"
        "سيتم ربطه لاحقًا بالمفاتيح عندما نقرر تشغيل الذكاء الحقيقي."
    )
    return ChatResponse(reply=reply)


@app.post("/api/loop/plan", response_model=PlanResponse)
def loop_plan(req: PlanRequest):
    """
    يولّد خطة بسيطة (Stub) على شكل خطوات نصية.
    لاحقًا يمكن تعويضه بمنطق حقيقي مرتبط بـ LLM.
    """
    base_steps = [
        "تحليل الهدف وكتابة ملاحظات أولية في workspace/snippets/loop_notes.txt.",
        "اقتراح ملفات/سكربتات أولية داخل workspace/scripts/ حسب الهدف.",
        "تجهيز ملف جاهز للرفع إلى Git لاحقًا (بدون تنفيذ push الآن).",
    ]
    steps = [
        PlanStep(id=i + 1, text=base_steps[i])
        for i in range(len(base_steps))
    ]
    return PlanResponse(goal=req.goal, steps=steps)


@app.get("/api/workspace/list", response_model=WorkspaceListResponse)
def workspace_list():
    """
    يعرض جميع الملفات داخل workspace/ (نسبيًا).
    """
    files: List[WorkspaceFile] = []

    if WORKSPACE_DIR.exists():
        for p in WORKSPACE_DIR.rglob("*"):
            if p.is_file():
                rel_path = p.relative_to(WORKSPACE_DIR).as_posix()
                try:
                    size = p.stat().st_size
                except OSError:
                    size = 0
                files.append(WorkspaceFile(path=rel_path, size=size))

    return WorkspaceListResponse(files=files)


@app.post("/api/workspace/write")
def workspace_write(req: FileWriteRequest):
    """
    يكتب محتوى داخل ملف تحت workspace/ بالترميز UTF-8.
    - يمنع استخدام .. أو مسارات خارج workspace.
    """
    raw_path = req.path.strip().lstrip("/")
    parts = raw_path.split("/")
    if any(part == ".." for part in parts) or raw_path == "":
        raise HTTPException(status_code=400, detail="Invalid path")

    target = WORKSPACE_DIR / raw_path
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(req.content, encoding="utf-8")
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Write failed: {type(e).__name__}: {e}",
        )

    return {"ok": True, "path": raw_path}
PY

# =========================
# 2) Backend: requirements.txt (تأكيد الأساسيات)
# =========================
echo ">>> [LOOP] Ensuring backend requirements (fastapi, uvicorn, pydantic)..."

REQ="$BACK/requirements.txt"
if [ ! -f "$REQ" ]; then
  cat > "$REQ" << 'R'
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
pydantic>=2.9.0
R
else
  grep -q "^fastapi" "$REQ"   || echo "fastapi>=0.115.0" >> "$REQ"
  grep -q "^uvicorn" "$REQ"   || echo "uvicorn[standard]>=0.32.0" >> "$REQ"
  grep -q "^pydantic" "$REQ"  || echo "pydantic>=2.9.0" >> "$REQ"
fi

# =========================
# 3) Frontend: API wrapper
# =========================
echo ">>> [LOOP] Writing frontend src/api/station_api.ts ..."

mkdir -p "$FRONT/src/api"

cat > "$FRONT/src/api/station_api.ts" << 'TS'
export interface ChatResponse {
  reply: string;
}

export interface PlanStep {
  id: number;
  text: string;
}

export interface PlanResponse {
  goal: string;
  steps: PlanStep[];
}

export interface WorkspaceFile {
  path: string;
  size: number;
}

export interface WorkspaceListResponse {
  files: WorkspaceFile[];
}

export interface HealthPayload {
  status: string;
  service: string;
  port: number;
  features: string[];
  workspace: string;
}

const BASE = "http://127.0.0.1:8810";

async function api<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(BASE + path, {
    headers: {
      "Content-Type": "application/json",
      ...(options && options.headers ? options.headers : {}),
    },
    ...options,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`API ${path} failed: ${res.status} ${text}`);
  }

  return (await res.json()) as T;
}

export const StationAPI = {
  health: () => api<HealthPayload>("/health"),

  echo: (msg: string) =>
    api<{ echo: string }>(`/api/echo?msg=${encodeURIComponent(msg)}`),

  chat: (message: string) =>
    api<ChatResponse>("/api/chat", {
      method: "POST",
      body: JSON.stringify({ message }),
    }),

  plan: (goal: string) =>
    api<PlanResponse>("/api/loop/plan", {
      method: "POST",
      body: JSON.stringify({ goal }),
    }),

  listWorkspace: () =>
    api<WorkspaceListResponse>("/api/workspace/list"),

  writeWorkspace: (path: string, content: string) =>
    api<{ ok: boolean; path: string }>("/api/workspace/write", {
      method: "POST",
      body: JSON.stringify({ path, content }),
    }),
};
TS

# =========================
# 4) Frontend: App.tsx
# =========================
echo ">>> [LOOP] Writing frontend src/App.tsx ..."

cat > "$FRONT/src/App.tsx" << 'TSX'
import { useState } from "react";
import {
  StationAPI,
  ChatResponse,
  PlanResponse,
  WorkspaceFile,
  HealthPayload,
} from "./api/station_api";

type Tab = "health" | "chat" | "loop" | "workspace";

function App() {
  const [tab, setTab] = useState<Tab>("health");

  // Health
  const [health, setHealth] = useState<HealthPayload | null>(null);
  const [healthError, setHealthError] = useState<string | null>(null);

  // Chat
  const [chatInput, setChatInput] = useState<string>("");
  const [chatReply, setChatReply] = useState<string>("");

  // Loop plan
  const [goal, setGoal] = useState<string>("");
  const [plan, setPlan] = useState<PlanResponse | null>(null);
  const [planError, setPlanError] = useState<string | null>(null);

  // Workspace
  const [workspaceFiles, setWorkspaceFiles] = useState<WorkspaceFile[]>([]);
  const [filePath, setFilePath] = useState<string>("notes/loop_notes.txt");
  const [fileContent, setFileContent] = useState<string>("");
  const [workspaceStatus, setWorkspaceStatus] = useState<string>("");

  const [busy, setBusy] = useState<boolean>(false);

  const runHealth = async () => {
    setBusy(true);
    setHealthError(null);
    try {
      const h = await StationAPI.health();
      setHealth(h);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setHealthError(msg);
      setHealth(null);
    } finally {
      setBusy(false);
    }
  };

  const sendChat = async () => {
    if (!chatInput.trim()) return;
    setBusy(true);
    setChatReply("");
    try {
      const res: ChatResponse = await StationAPI.chat(chatInput.trim());
      setChatReply(res.reply);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setChatReply("❌ Chat error: " + msg);
    } finally {
      setBusy(false);
    }
  };

  const generatePlan = async () => {
    if (!goal.trim()) return;
    setBusy(true);
    setPlan(null);
    setPlanError(null);
    try {
      const p = await StationAPI.plan(goal.trim());
      setPlan(p);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setPlanError(msg);
    } finally {
      setBusy(false);
    }
  };

  const refreshWorkspace = async () => {
    setBusy(true);
    try {
      const res = await StationAPI.listWorkspace();
      setWorkspaceFiles(res.files);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setWorkspaceStatus("❌ " + msg);
    } finally {
      setBusy(false);
    }
  };

  const saveFile = async () => {
    if (!filePath.trim()) return;
    setBusy(true);
    setWorkspaceStatus("");
    try {
      const res = await StationAPI.writeWorkspace(
        filePath.trim(),
        fileContent
      );
      setWorkspaceStatus("✅ Saved: " + res.path);
      await refreshWorkspace();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setWorkspaceStatus("❌ " + msg);
    } finally {
      setBusy(false);
    }
  };

  const TabButton = (props: { id: Tab; label: string }) => (
    <button
      onClick={() => setTab(props.id)}
      style={{
        padding: "0.5rem 1rem",
        marginInlineEnd: "0.5rem",
        borderRadius: "999px",
        border: "1px solid #ccc",
        background: tab === props.id ? "#2563eb" : "#f3f4f6",
        color: tab === props.id ? "#ffffff" : "#111827",
        cursor: "pointer",
        fontSize: "0.9rem",
      }}
    >
      {props.label}
    </button>
  );

  return (
    <div
      style={{
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
        padding: "1.5rem",
        maxWidth: "960px",
        margin: "0 auto",
        direction: "rtl",
        textAlign: "right",
      }}
    >
      <h1 style={{ fontSize: "1.6rem", marginBottom: "0.5rem" }}>
        STATION – LOOP v1
      </h1>
      <p style={{ color: "#4b5563", marginBottom: "1rem" }}>
        لوب صغير يربط الواجهة بالباك-إند والـ workspace (بدون LLM حاليًا).
      </p>

      <div style={{ marginBottom: "1rem" }}>
        <TabButton id="health" label="Health" />
        <TabButton id="chat" label="Chat Stub" />
        <TabButton id="loop" label="Loop Plan" />
        <TabButton id="workspace" label="Workspace" />
      </div>

      {busy && (
        <div
          style={{
            marginBottom: "0.75rem",
            padding: "0.5rem 0.75rem",
            background: "#fef3c7",
            borderRadius: "0.5rem",
            fontSize: "0.85rem",
          }}
        >
          ⏳ يجري تنفيذ طلب...
        </div>
      )}

      {/* HEALTH TAB */}
      {tab === "health" && (
        <div
          style={{
            borderRadius: "0.75rem",
            border: "1px solid #e5e7eb",
            padding: "1rem",
          }}
        >
          <h2 style={{ fontSize: "1.1rem", marginBottom: "0.75rem" }}>
            Health & Echo
          </h2>
          <button
            onClick={runHealth}
            style={{
              padding: "0.4rem 0.9rem",
              borderRadius: "0.5rem",
              border: "none",
              background: "#10b981",
              color: "#ffffff",
              cursor: "pointer",
              fontSize: "0.9rem",
              marginBottom: "0.75rem",
            }}
          >
            تشغيل Health الآن
          </button>

          {healthError && (
            <pre
              style={{
                background: "#fee2e2",
                padding: "0.75rem",
                borderRadius: "0.5rem",
                fontSize: "0.8rem",
                marginTop: "0.5rem",
                whiteSpace: "pre-wrap",
              }}
            >
              ❌ {healthError}
            </pre>
          )}

          {health && (
            <pre
              style={{
                background: "#f3f4f6",
                padding: "0.75rem",
                borderRadius: "0.5rem",
                fontSize: "0.8rem",
                marginTop: "0.5rem",
                whiteSpace: "pre-wrap",
              }}
            >
{JSON.stringify(health, null, 2)}
            </pre>
          )}
        </div>
      )}

      {/* CHAT TAB */}
      {tab === "chat" && (
        <div
          style={{
            borderRadius: "0.75rem",
            border: "1px solid #e5e7eb",
            padding: "1rem",
          }}
        >
          <h2 style={{ fontSize: "1.1rem", marginBottom: "0.75rem" }}>
            Chat (LOOP Stub)
          </h2>
          <textarea
            value={chatInput}
            onChange={(e) => setChatInput(e.target.value)}
            placeholder="اكتب رسالة للـ LOOP (بدون LLM حاليًا)..."
            style={{
              width: "100%",
              minHeight: "80px",
              borderRadius: "0.5rem",
              border: "1px solid #d1d5db",
              padding: "0.6rem",
              marginBottom: "0.5rem",
              fontSize: "0.9rem",
            }}
          />
          <div style={{ marginBottom: "0.5rem" }}>
            <button
              onClick={sendChat}
              style={{
                padding: "0.4rem 0.9rem",
                borderRadius: "0.5rem",
                border: "none",
                background: "#2563eb",
                color: "#ffffff",
                cursor: "pointer",
                fontSize: "0.9rem",
              }}
            >
              إرسال
            </button>
          </div>
          {chatReply && (
            <pre
              style={{
                background: "#f9fafb",
                padding: "0.75rem",
                borderRadius: "0.5rem",
                fontSize: "0.85rem",
                whiteSpace: "pre-wrap",
              }}
            >
              {chatReply}
            </pre>
          )}
        </div>
      )}

      {/* LOOP PLAN TAB */}
      {tab === "loop" && (
        <div
          style={{
            borderRadius: "0.75rem",
            border: "1px solid #e5f0ff",
            padding: "1rem",
          }}
        >
          <h2 style={{ fontSize: "1.1rem", marginBottom: "0.75rem" }}>
            Loop Plan (Stub)
          </h2>
          <input
            type="text"
            value={goal}
            onChange={(e) => setGoal(e.target.value)}
            placeholder="اكتب الهدف (مثلاً: توليد سكربت لتحديث مشروع X)..."
            style={{
              width: "100%",
              borderRadius: "0.5rem",
              border: "1px solid #d1d5db",
              padding: "0.5rem",
              marginBottom: "0.5rem",
              fontSize: "0.9rem",
            }}
          />
          <button
            onClick={generatePlan}
            style={{
              padding: "0.4rem 0.9rem",
              borderRadius: "0.5rem",
              border: "none",
              background: "#7c3aed",
              color: "#ffffff",
              cursor: "pointer",
              fontSize: "0.9rem",
              marginBottom: "0.75rem",
            }}
          >
            توليد خطة Stub
          </button>

          {planError && (
            <pre
              style={{
                background: "#fee2e2",
                padding: "0.75rem",
                borderRadius: "0.5rem",
                fontSize: "0.8rem",
                whiteSpace: "pre-wrap",
              }}
            >
              ❌ {planError}
            </pre>
          )}

          {plan && (
            <div>
              <p style={{ fontSize: "0.9rem", marginBottom: "0.5rem" }}>
                الهدف: <strong>{plan.goal}</strong>
              </p>
              <ol style={{ paddingRight: "1.25rem", fontSize: "0.9rem" }}>
                {plan.steps.map((s) => (
                  <li key={s.id} style={{ marginBottom: "0.25rem" }}>
                    {s.id}. {s.text}
                  </li>
                ))}
              </ol>
            </div>
          )}
        </div>
      )}

      {/* WORKSPACE TAB */}
      {tab === "workspace" && (
        <div
          style={{
            borderRadius: "0.75rem",
            border: "1px solid #e5e7eb",
            padding: "1rem",
          }}
        >
          <h2 style={{ fontSize: "1.1rem", marginBottom: "0.75rem" }}>
            Workspace I/O
          </h2>

          <div style={{ marginBottom: "0.75rem" }}>
            <button
              onClick={refreshWorkspace}
              style={{
                padding: "0.4rem 0.9rem",
                borderRadius: "0.5rem",
                border: "none",
                background: "#0ea5e9",
                color: "#ffffff",
                cursor: "pointer",
                fontSize: "0.9rem",
              }}
            >
              تحديث قائمة الملفات
            </button>
          </div>

          {workspaceFiles.length > 0 && (
            <div
              style={{
                maxHeight: "160px",
                overflow: "auto",
                marginBottom: "0.75rem",
                border: "1px solid #e5e7eb",
                borderRadius: "0.5rem",
              }}
            >
              <table
                style={{
                  width: "100%",
                  borderCollapse: "collapse",
                  fontSize: "0.8rem",
                }}
              >
                <thead>
                  <tr>
                    <th
                      style={{
                        borderBottom: "1px solid #e5e7eb",
                        padding: "0.3rem",
                      }}
                    >
                      المسار
                    </th>
                    <th
                      style={{
                        borderBottom: "1px solid #e5e7eb",
                        padding: "0.3rem",
                        width: "60px",
                      }}
                    >
                      الحجم
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {workspaceFiles.map((f) => (
                    <tr key={f.path}>
                      <td
                        style={{
                          borderBottom: "1px solid #f3f4f6",
                          padding: "0.3rem",
                        }}
                      >
                        {f.path}
                      </td>
                      <td
                        style={{
                          borderBottom: "1px solid #f3f4f6",
                          padding: "0.3rem",
                        }}
                      >
                        {f.size}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <div style={{ marginBottom: "0.5rem" }}>
            <label
              style={{ display: "block", fontSize: "0.85rem", marginBottom: "0.25rem" }}
            >
              المسار داخل workspace/:
            </label>
            <input
              type="text"
              value={filePath}
              onChange={(e) => setFilePath(e.target.value)}
              style={{
                width: "100%",
                borderRadius: "0.5rem",
                border: "1px solid #d1d5db",
                padding: "0.5rem",
                fontSize: "0.9rem",
              }}
            />
          </div>

          <div style={{ marginBottom: "0.5rem" }}>
            <label
              style={{ display: "block", fontSize: "0.85rem", marginBottom: "0.25rem" }}
            >
              محتوى الملف (UTF-8):
            </label>
            <textarea
              value={fileContent}
              onChange={(e) => setFileContent(e.target.value)}
              placeholder="أكتب نصًا أو سكربتًا ليتم حفظه داخل workspace/..."
              style={{
                width: "100%",
                minHeight: "100px",
                borderRadius: "0.5rem",
                border: "1px solid #d1d5db",
                padding: "0.6rem",
                fontSize: "0.9rem",
              }}
            />
          </div>

          <button
            onClick={saveFile}
            style={{
              padding: "0.4rem 0.9rem",
              borderRadius: "0.5rem",
              border: "none",
              background: "#22c55e",
              color: "#ffffff",
              cursor: "pointer",
              fontSize: "0.9rem",
              marginBottom: "0.5rem",
            }}
          >
            حفظ إلى workspace
          </button>

          {workspaceStatus && (
            <div
              style={{
                marginTop: "0.5rem",
                fontSize: "0.85rem",
                color: workspaceStatus.startsWith("✅")
                  ? "#15803d"
                  : "#b91c1c",
              }}
            >
              {workspaceStatus}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default App;
TSX

echo ">>> [LOOP] Upgrade finished. (لا تشغيل تلقائي، فقط بناء اللوب)"
echo ">>> عندما تريد الاختبار لاحقًا: bash run_station.sh ثم افتح الواجهة."
