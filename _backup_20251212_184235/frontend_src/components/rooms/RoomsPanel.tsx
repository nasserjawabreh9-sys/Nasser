import { useEffect, useState } from "react";
import { jget, jpost } from "../api";

type Room = { id: string; title: string; created_at: string };
type Msg = { id: number; role: string; text: string; created_at: string };

export default function RoomsPanel() {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [active, setActive] = useState<string>("9001");
  const [title, setTitle] = useState<string>("Room 9001");
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [text, setText] = useState<string>("");

  async function refresh() {
    const r = await jget("/rooms");
    setRooms(r.rooms || []);
  }

  async function load(roomId: string) {
    setActive(roomId);
    const r = await jget(`/rooms/${roomId}/messages?limit=80`);
    setMsgs(r.messages || []);
  }

  useEffect(() => {
    void refresh();
    void load(active);
  }, []);

  async function ensure() {
    await jpost("/rooms/ensure", { room_id: active, title });
    await refresh();
  }

  async function rename() {
    await jpost("/rooms/rename", { room_id: active, title });
    await refresh();
  }

  async function send(role: string) {
    const t = text.trim();
    if (!t) return;
    setText("");
    await jpost(`/rooms/${active}/messages`, { role, text: t });
    await load(active);
  }

  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>Rooms</h3>
        <span>SQLite-backed</span>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "280px 1fr", gap: 10, height: "calc(100% - 40px)" }}>
        <div style={{ border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", overflow: "auto" }}>
          <div style={{ padding: 10, display: "flex", gap: 8 }}>
            <input
              value={active}
              onChange={(e) => setActive(e.target.value)}
              placeholder="room_id"
              style={{ flex: 1, padding: 10, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.15)", color: "rgba(255,255,255,.9)" }}
            />
          </div>
          <div style={{ padding: 10, display: "flex", gap: 8 }}>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="title"
              style={{ flex: 1, padding: 10, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.15)", color: "rgba(255,255,255,.9)" }}
            />
          </div>
          <div style={{ padding: 10, display: "flex", gap: 8, flexWrap: "wrap" }}>
            <button className="btn btnPrimary" onClick={() => void ensure()}>Ensure</button>
            <button className="btn" onClick={() => void rename()}>Rename</button>
            <button className="btn" onClick={() => void refresh()}>Refresh</button>
            <button className="btn" onClick={() => void load(active)}>Load</button>
          </div>

          <div style={{ padding: 10, borderTop: "1px solid rgba(255,255,255,.08)" }}>
            <div style={{ color: "rgba(255,255,255,.65)", fontSize: 12, marginBottom: 6 }}>Known rooms</div>
            {rooms.map((r) => (
              <div
                key={r.id}
                onClick={() => void load(r.id)}
                style={{
                  padding: "10px 10px",
                  borderRadius: 12,
                  cursor: "pointer",
                  marginBottom: 6,
                  border: "1px solid rgba(255,255,255,.08)",
                  background: r.id === active ? "rgba(42,167,255,.14)" : "rgba(0,0,0,.12)",
                }}
              >
                <b style={{ fontSize: 13 }}>{r.title}</b>
                <div style={{ color: "rgba(255,255,255,.55)", fontSize: 11 }}>{r.id}</div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: 10, height: "100%" }}>
          <div style={{ flex: 1, border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", overflow: "auto", padding: 10 }}>
            {msgs.map((m) => (
              <div key={m.id} style={{ marginBottom: 10 }}>
                <div style={{ color: "rgba(255,255,255,.55)", fontSize: 11 }}>{m.role.toUpperCase()} • {new Date(m.created_at).toLocaleString()}</div>
                <div style={{ whiteSpace: "pre-wrap" }}>{m.text}</div>
              </div>
            ))}
          </div>

          <div style={{ display: "flex", gap: 10 }}>
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="Write message to room..."
              style={{ flex: 1, height: 56, padding: 10, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", color: "rgba(255,255,255,.9)" }}
            />
            <button className="btn btnPrimary" onClick={() => void send("user")}>Send</button>
          </div>
        </div>
      </div>
    </div>
  );
}
