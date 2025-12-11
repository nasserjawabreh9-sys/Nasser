#!/data/data/com.termux/files/usr/bin/bash
set -e

cd ~/station_root/backend

if [ -d ".venv" ]; then
  source .venv/bin/activate
else
  echo ">>> [STATION] No .venv found in backend."
  echo "    Create one with:  cd ~/station_root/backend && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
  exit 1
fi

echo ">>> [STATION] Running backend on http://0.0.0.0:8800 ..."
uvicorn app.main:app --host 0.0.0.0 --port 8800
export interface Health {
  status: string;
  loop?: string;
  utf8?: boolean;
  features?: string[];
}

export interface ChatResponse {
  reply: string;
}

export interface Task {
  id: number;
  kind: string;
  status: string;
  payload: Record<string, any>;
}

const BASE = "http://127.0.0.1:8810";

async function handleJson<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text}`);
  }
  return res.json() as Promise<T>;
}

export async function apiHealth(): Promise<Health> {
  const res = await fetch(`${BASE}/health`);
  return handleJson<Health>(res);
}

export async function apiEcho(msg: string): Promise<{ echo: string }> {
  const url = `${BASE}/api/echo?msg=${encodeURIComponent(msg)}`;
  const res = await fetch(url);
  return handleJson<{ echo: string }>(res);
}

export async function apiChat(message: string): Promise<ChatResponse> {
  const res = await fetch(`${BASE}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message }),
  });
  return handleJson<ChatResponse>(res);
}

export async function apiListTasks(): Promise<Task[]> {
  const res = await fetch(`${BASE}/api/loop/tasks`);
  return handleJson<Task[]>(res);
}

export async function apiSubmitTask(kind: string, instruction: string): Promise<Task> {
  const payload = { instruction };
  const res = await fetch(`${BASE}/api/loop/submit`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ kind, payload }),
  });
  return handleJson<Task>(res);
}
