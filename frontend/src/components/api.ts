export const API_BASE =
  (import.meta as any).env?.VITE_BACKEND_URL || "http://127.0.0.1:8000";

export async function jget(path: string) {
  const r = await fetch(`${API_BASE}${path}`, { method: "GET" });
  if (!r.ok) throw new Error(`${path} -> ${r.status}`);
  return await r.json();
}

export async function jpost(path: string, body: any) {
  const r = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body ?? {}),
  });
  if (!r.ok) throw new Error(`${path} -> ${r.status}`);
  return await r.json();
}
