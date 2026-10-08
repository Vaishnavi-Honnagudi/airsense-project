// Automatically prioritizes deployed cloud URL, local FastAPI backend, and fallback tunnels
export const ENV_API_BASE = import.meta.env.VITE_API_BASE || "";
export const LOCAL_API_BASE = "http://127.0.0.1:8000";
export const NGROK_API_BASE = "https://material-rhyme-friend.ngrok-free.dev";

export const CANDIDATE_BASES = [
  ...(ENV_API_BASE ? [ENV_API_BASE] : []),
  LOCAL_API_BASE,
  "http://localhost:8000",
  NGROK_API_BASE,
];

export const API_BASE = ENV_API_BASE || LOCAL_API_BASE;
