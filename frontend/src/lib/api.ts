export async function apiGet(path: string) {
  const res = await fetch(path, { method: "GET" });
  if (!res.ok) throw new Error(`GET ${path} failed`);
  return res.json();
}

export async function apiPost(path: string, body: any, editKey?: string) {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (editKey) headers["X-Edit-Key"] = editKey;
  const res = await fetch(path, { method: "POST", headers, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`POST ${path} failed`);
  return res.json();
}
