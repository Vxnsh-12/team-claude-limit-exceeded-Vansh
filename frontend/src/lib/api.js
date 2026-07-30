import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
export const API = `${BACKEND_URL}/api`;

export const api = axios.create({
  baseURL: API,
  withCredentials: true,
});

// Also attach Bearer token as fallback for envs where 3rd-party cookies get blocked.
export const setAuthToken = (token) => {
  if (token) {
    api.defaults.headers.common["Authorization"] = `Bearer ${token}`;
    localStorage.setItem("vq_token", token);
  } else {
    delete api.defaults.headers.common["Authorization"];
    localStorage.removeItem("vq_token");
  }
};

const stored = typeof window !== "undefined" ? localStorage.getItem("vq_token") : null;
if (stored) {
  api.defaults.headers.common["Authorization"] = `Bearer ${stored}`;
}

export function formatApiErrorDetail(detail) {
  if (detail == null) return "Something went wrong. Please try again.";
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail))
    return detail
      .map((e) => (e && typeof e.msg === "string" ? e.msg : JSON.stringify(e)))
      .filter(Boolean)
      .join(" ");
  if (detail && typeof detail.msg === "string") return detail.msg;
  return String(detail);
}
