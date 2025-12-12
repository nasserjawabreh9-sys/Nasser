// src/api/station_api.ts

const BASE_URL =
  import.meta.env.VITE_STATION_API_URL || "http://127.0.0.1:8000";

async function getHealth(): Promise<any> {
  const res = await fetch(`${BASE_URL}/health`);
  if (!res.ok) {
    throw new Error(`Health check failed: ${res.status}`);
  }
  return res.json();
}

export interface StationEchoRequest {
  message: string;
  meta?: Record<string, any>;
}

export interface StationEchoResponse {
  received: any;
  note: string;
}

async function sendEcho(
  payload: StationEchoRequest
): Promise<StationEchoResponse> {
  const res = await fetch(`${BASE_URL}/echo`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    throw new Error(`Echo request failed: ${res.status}`);
  }

  return res.json();
}

export const StationAPI = {
  getHealth,
  sendEcho,
};

export default StationAPI;

