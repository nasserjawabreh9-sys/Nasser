#!/data/data/com.termux/files/usr/bin/bash
set -e

echo ">>> [LOOP-V2] Station loop v2 setup (backend + frontend)..."

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
WORK="$ROOT/workspace"

echo ">>> [LOOP-V2] ROOT  : $ROOT"
echo ">>> [LOOP-V2] BACK  : $BACK"
echo ">>> [LOOP-V2] FRONT : $FRONT"
echo ">>> [LOOP-V2] WORK  : $WORK"

mkdir -p "$WORK"
mkdir -p "$FRONT/src/api"

########################################
# 1) backend/app/main.py (تحديث كامل)
########################################
cd "$BACK"

echo ">>> [LOOP-V2] Writing backend app/main.py ..."

cat > app/main.py << 'PY'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Any
from pathlib import Path
import os
import json
from datetime import datetime

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None  # سيتم التعامل معها لاحقاً إذا لم تكن مثبتة


app = FastAPI(
    title="Station Backend",
    version="0.4.0",
    description="Station backend for Termux: health, echo, chat, loop logging & listing.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


class LoopCommand(BaseModel):
    command: str
    source: Optional[str] = "station_ui"
    intent: Optional[str] = "auto"


class LoopEntry(BaseModel):
    ts: str
    command: str
    source: Optional[str] = None
    status: Optional[str] = None
    idx: Optional[int] = None


class LoopListResponse(BaseModel):
    items: List[LoopEntry]


def get_openai_client() -> Optional["OpenAI"]:
    """
    نحاول أخذ المفتاح من:
    1) STATION_OPENAI_API_KEY
    2) OPENAI_API_KEY
    بالترتيب.
    (التشغيل الفعلي نأجّله لمرحلة لاحقة مع حل مشكلة openai على تيرمكس.)
    """
    api_key = os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not api_key or OpenAI is None:
        return None
    return OpenAI(api_key=api_key)


def get_workspace_dir() -> Path:
    """
    يحدد مجلد workspace الخاص بالمحطة ويضمن وجوده.
    """
    root_env = os.getenv("STATION_ROOT")
    if root_env:
        root = Path(root_env)
    else:
        # backend/app/main.py → backend/app → backend → station_root
        root = Path(__file__).resolve().parents[2]
    work = root / "workspace"
    work.mkdir(parents=True, exist_ok=True)
    return work


def get_loop_log_path() -> Path:
    work = get_workspace_dir()
    return work / "loop_log.jsonl"


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "station_backend",
        "port": 8810,
        "features": ["health", "echo", "chat", "loop_command", "loop_list"],
    }


@app.get("/")
def root():
    return {
        "message": "Station backend running",
        "hint": "Use /health, /api/echo, /api/chat, /api/loop/command, /api/loop/list",
    }


@app.get("/api/echo")
def echo(msg: str = "hello"):
    return {"echo": msg}


@app.post("/api/chat", response_model=ChatResponse)
def chat(body: ChatRequest):
    """
    نقطة بسيطة للذكاء الاصطناعي (مؤجلة):
    - إذا لم يوجد مفتاح → نرمي خطأ 400 برسالة واضحة.
    - إذا حدث خطأ من مزود الـ API → نرمي 500 برسالة.
    """
    client = get_openai_client()
    if client is None:
        raise HTTPException(
            status_code=400,
            detail=(
                "OpenAI API key not configured or 'openai' package not installed. "
                "Set STATION_OPENAI_API_KEY or OPENAI_API_KEY and install openai."
            ),
        )

    try:
        completion = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "أنت مساعد صغير داخل محطة ناصر (STATION) على تيرمكس. "
                        "جاوب باختصار ووضوح وبأسلوب عملي."
                    ),
                },
                {
                    "role": "user",
                    "content": body.message,
                },
            ],
        )
        reply_text = completion.choices[0].message.content or ""
        return ChatResponse(reply=reply_text.strip())
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Chat backend error: {type(e).__name__}: {e}",
        )


@app.post("/api/loop/command", response_model=LoopEntry)
def loop_command(body: LoopCommand):
    """
    قلب الـ LOOP:
    - يستقبل أمر نصّي من الواجهة (أو أي عميل).
    - يخزّنه كسطر JSON في loop_log.jsonl داخل workspace.
    - يرجع نفس المدخل مع رقم idx.
    """
    log_path = get_loop_log_path()

    entry = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "command": body.command,
        "source": body.source,
        "status": "queued",
    }

    # نحاول حساب idx بسيط (عدد الأسطر الحالي + 1)
    idx = 1
    if log_path.exists():
        try:
            with log_path.open("r", encoding="utf-8") as f:
                idx = sum(1 for _ in f) + 1
        except Exception:
            idx = 1

    entry["idx"] = idx

    with log_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    return LoopEntry(**entry)


@app.get("/api/loop/list", response_model=LoopListResponse)
def loop_list(limit: int = 20):
    """
    تعرض آخر الأوامر المخزّنة في loop_log.jsonl (مقلوبة: الأحدث أولاً).
    """
    log_path = get_loop_log_path()
    items: list[LoopEntry] = []

    if not log_path.exists():
        return LoopListResponse(items=[])

    try:
        with log_path.open("r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Could not read loop log: {type(e).__name__}: {e}",
        )

    # نقرأ من الأخير للأول، ثم نكتفي بعدد limit
    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            data: Any = json.loads(line)
            items.append(LoopEntry(**data))
            if len(items) >= limit:
                break
        except Exception:
            continue

    return LoopListResponse(items=items)
PY

echo ">>> [LOOP-V2] backend app/main.py ready."


########################################
# 2) frontend/src/api/station_api.ts
########################################
cd "$FRONT"

echo ">>> [LOOP-V2] Writing frontend src/api/station_api.ts ..."

cat > src/api/station_api.ts << 'TS'
const BASE = "http://127.0.0.1:8810";

export type HealthResponse = {
  status: string;
  service: string;
  port: number;
  features?: string[];
};

export type LoopEntry = {
  ts: string;
  command: string;
  source?: string;
  status?: string;
  idx?: number;
};

export type LoopListResponse = {
  items: LoopEntry[];
};

export async function getHealth(): Promise<HealthResponse> {
  const res = await fetch(`${BASE}/health`);
  if (!res.ok) {
    throw new Error(`Health error: ${res.status}`);
  }
  return res.json();
}

export async function sendEcho(msg: string): Promise<{ echo: string }> {
  const res = await fetch(`${BASE}/api/echo?msg=${encodeURIComponent(msg)}`);
  if (!res.ok) {
    throw new Error(`Echo error: ${res.status}`);
  }
  return res.json();
}

export async function sendLoopCommand(
  command: string,
  source: string = "station_ui"
): Promise<LoopEntry> {
  const res = await fetch(`${BASE}/api/loop/command`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ command, source }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Loop command error: ${res.status} – ${text}`);
  }
  return res.json();
}

export async function listLoop(limit: number = 20): Promise<LoopListResponse> {
  const res = await fetch(`${BASE}/api/loop/list?limit=${limit}`);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Loop list error: ${res.status} – ${text}`);
  }
  return res.json();
}
TS

echo ">>> [LOOP-V2] frontend src/api/station_api.ts ready."


########################################
# 3) frontend/src/App.tsx (واجهة Health + Echo + Loop)
########################################
echo ">>> [LOOP-V2] Writing frontend src/App.tsx ..."

cat > src/App.tsx << 'TSX'
import { useEffect, useState } from "react";
import {
  getHealth,
  sendEcho,
  sendLoopCommand,
  listLoop,
  type HealthResponse,
  type LoopEntry,
} from "./api/station_api";

type Tab = "health" | "echo" | "loop";

function App() {
  const [activeTab, setActiveTab] = useState<Tab>("loop");

  // Health
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [healthError, setHealthError] = useState<string | null>(null);

  // Echo
  const [echoInput, setEchoInput] = useState("هلا");
  const [echoResult, setEchoResult] = useState<string | null>(null);
  const [echoError, setEchoError] = useState<string | null>(null);

  // Loop
  const [loopCommand, setLoopCommand] = useState("ls -la ~/station_root");
  const [loopSource, setLoopSource] = useState("station_ui");
  const [loopItems, setLoopItems] = useState<LoopEntry[]>([]);
  const [loopStatus, setLoopStatus] = useState<string | null>(null);
  const [loopError, setLoopError] = useState<string | null>(null);

  // Load health on first render
  useEffect(() => {
    (async () => {
      try {
        const h = await getHealth();
        setHealth(h);
      } catch (err: any) {
        setHealthError(err?.message ?? String(err));
      }
    })();
  }, []);

  async function handleEchoSend() {
    setEchoError(null);
    setEchoResult(null);
    try {
      const res = await sendEcho(echoInput);
      setEchoResult(res.echo);
    } catch (err: any) {
      setEchoError(err?.message ?? String(err));
    }
  }

  async function handleLoopSend() {
    setLoopError(null);
    setLoopStatus("جاري الإرسال...");
    try {
      const entry = await sendLoopCommand(loopCommand, loopSource || "station_ui");
      setLoopStatus(`تم التخزين كأمر رقم #${entry.idx ?? "?"}`);
      // بعد الإرسال، نحدّث القائمة
      await handleLoopRefresh();
    } catch (err: any) {
      setLoopError(err?.message ?? String(err));
      setLoopStatus(null);
    }
  }

  async function handleLoopRefresh() {
    setLoopError(null);
    try {
      const res = await listLoop(20);
      setLoopItems(res.items);
    } catch (err: any) {
      setLoopError(err?.message ?? String(err));
    }
  }

  const tabClass = (tab: Tab) =>
    "px-3 py-1 border-b-2 cursor-pointer text-sm " +
    (activeTab === tab ? "border-blue-500 font-semibold" : "border-transparent text-gray-500");

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex items-center justify-center p-4">
      <div className="w-full max-w-3xl bg-slate-800 rounded-xl shadow-xl border border-slate-700">
        <header className="px-4 py-3 border-b border-slate-700 flex items-center justify-between">
          <div>
            <h1 className="text-lg font-bold">STATION</h1>
            <p className="text-xs text-slate-400">
              Minimal bridge between backend &amp; frontend (Termux edition).
            </p>
          </div>
          <div className="text-xs text-right text-slate-400">
            <div>ROOT: ~/station_root</div>
            <div>Backend: 127.0.0.1:8810</div>
            <div>Frontend: 127.0.0.1:5173</div>
          </div>
        </header>

        <nav className="px-4 pt-2 flex gap-4 border-b border-slate-700">
          <button className={tabClass("health")} onClick={() => setActiveTab("health")}>
            Health
          </button>
          <button className={tabClass("echo")} onClick={() => setActiveTab("echo")}>
            Echo
          </button>
          <button className={tabClass("loop")} onClick={() => setActiveTab("loop")}>
            Loop
          </button>
        </nav>

        <main className="p-4 space-y-4">
          {activeTab === "health" && (
            <section className="space-y-2">
              <h2 className="text-base font-semibold mb-2">Health</h2>
              {health && (
                <pre className="bg-slate-900/70 rounded p-3 text-xs overflow-x-auto">
                  {JSON.stringify(health, null, 2)}
                </pre>
              )}
              {healthError && (
                <div className="text-xs text-red-400">Health error: {healthError}</div>
              )}
              {!health && !healthError && (
                <div className="text-xs text-slate-400">Loading health...</div>
              )}
            </section>
          )}

          {activeTab === "echo" && (
            <section className="space-y-2">
              <h2 className="text-base font-semibold mb-2">Echo</h2>
              <div className="flex gap-2">
                <input
                  className="flex-1 rounded bg-slate-900/70 border border-slate-600 px-2 py-1 text-sm"
                  value={echoInput}
                  onChange={(e) => setEchoInput(e.target.value)}
                  placeholder="اكتب أي نص..."
                />
                <button
                  className="px-3 py-1 text-sm rounded bg-blue-600 hover:bg-blue-500"
                  onClick={handleEchoSend}
                >
                  Send
                </button>
              </div>
              {echoResult && (
                <pre className="bg-slate-900/70 rounded p-3 text-xs mt-2">
                  {JSON.stringify({ echo: echoResult }, null, 2)}
                </pre>
              )}
              {echoError && (
                <div className="text-xs text-red-400 mt-1">Echo error: {echoError}</div>
              )}
            </section>
          )}

          {activeTab === "loop" && (
            <section className="space-y-3">
              <h2 className="text-base font-semibold mb-2">Loop – Command Logger v2</h2>

              <div className="space-y-2">
                <label className="block text-xs text-slate-300 mb-1">
                  Command
                  <textarea
                    className="mt-1 w-full rounded bg-slate-900/70 border border-slate-600 px-2 py-1 text-sm min-h-[60px]"
                    value={loopCommand}
                    onChange={(e) => setLoopCommand(e.target.value)}
                  />
                </label>

                <label className="block text-xs text-slate-300 mb-1">
                  Source (اختياري)
                  <input
                    className="mt-1 w-full rounded bg-slate-900/70 border border-slate-600 px-2 py-1 text-sm"
                    value={loopSource}
                    onChange={(e) => setLoopSource(e.target.value)}
                    placeholder="station_ui / dwarf / render / github / termux_shell ..."
                  />
                </label>

                <div className="flex gap-2">
                  <button
                    className="px-3 py-1 text-sm rounded bg-emerald-600 hover:bg-emerald-500"
                    onClick={handleLoopSend}
                  >
                    Send to Loop
                  </button>
                  <button
                    className="px-3 py-1 text-sm rounded bg-slate-600 hover:bg-slate-500"
                    onClick={handleLoopRefresh}
                  >
                    Refresh list
                  </button>
                </div>

                {loopStatus && (
                  <div className="text-xs text-emerald-400 mt-1">{loopStatus}</div>
                )}
                {loopError && (
                  <div className="text-xs text-red-400 mt-1">Loop error: {loopError}</div>
                )}
              </div>

              <div className="border-t border-slate-700 pt-2">
                <h3 className="text-xs font-semibold mb-1 text-slate-300">
                  Last loop entries (from workspace/loop_log.jsonl)
                </h3>
                {loopItems.length === 0 && (
                  <div className="text-xs text-slate-500">لا يوجد أوامر بعد.</div>
                )}
                {loopItems.length > 0 && (
                  <div className="max-h-64 overflow-y-auto space-y-1 text-xs">
                    {loopItems.map((item) => (
                      <div
                        key={`${item.idx}-${item.ts}`}
                        className="border border-slate-700 rounded p-2 bg-slate-900/60"
                      >
                        <div className="flex justify-between mb-1">
                          <span className="font-semibold">
                            #{item.idx ?? "?"} – {item.status ?? "queued"}
                          </span>
                          <span className="text-[10px] text-slate-400">
                            {item.ts}
                          </span>
                        </div>
                        <div className="text-[11px] text-slate-300 mb-1">
                          source: {item.source ?? "unknown"}
                        </div>
                        <pre className="bg-slate-900/70 rounded p-1 text-[11px] whitespace-pre-wrap">
                          {item.command}
                        </pre>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </section>
          )}
        </main>
      </div>
    </div>
  );
}

export default App;
TSX

echo ">>> [LOOP-V2] frontend src/App.tsx ready."

echo ">>> [LOOP-V2] Done. (backend + frontend loop v2 structure built)"
