// frontend/src/api/station_api.ts
export interface ChatRequest {
  message: string;
}

export interface ChatResponse {
  reply: string;
  steps?: string[];
}

const STATION_BACKEND_URL =
  import.meta.env.VITE_STATION_BACKEND_URL || "http://127.0.0.1:8800";

export async function stationChat(message: string): Promise<ChatResponse> {
  const res = await fetch(`${STATION_BACKEND_URL}/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });

  if (!res.ok) {
    throw new Error(`Chat API error: ${res.status}`);
  }

  return res.json();
}
x}

