export type KeysState = {
  openaiKey: string;
  githubToken: string;
  ttsKey: string;
  webhooksUrl: string;
  ocrKey: string;
  webIntegrationKey: string;
  whatsappKey: string;
  emailSmtp: string;
  githubRepo: string;
  renderApiKey: string;
  editModeKey: string;
};

export const DEFAULT_KEYS: KeysState = {
  openaiKey: "",
  githubToken: "",
  ttsKey: "",
  webhooksUrl: "",
  ocrKey: "",
  webIntegrationKey: "",
  whatsappKey: "",
  emailSmtp: "",
  githubRepo: "",
  renderApiKey: "",
  editModeKey: "1234",
};

const K = "station.keys.v1";

export function loadKeysSafe(): KeysState {
  try {
    if (typeof window === "undefined") return { ...DEFAULT_KEYS };
    const raw = window.localStorage.getItem(K);
    if (!raw) return { ...DEFAULT_KEYS };
    return { ...DEFAULT_KEYS, ...(JSON.parse(raw) as Partial<KeysState>) };
  } catch {
    return { ...DEFAULT_KEYS };
  }
}

export function saveKeysSafe(s: KeysState) {
  try {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(K, JSON.stringify({ ...DEFAULT_KEYS, ...s }));
  } catch {}
}
