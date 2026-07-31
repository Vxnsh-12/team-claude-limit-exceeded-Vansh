import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "https://team-claude-limit-exceeded-vansh-10.onrender.com";
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

/**
 * Resolve any avatar / media URL for use in <img src>.
 * - Absolute URL (http/https) → returned as-is
 * - Relative `/api/uploads/...` → prepend backend URL and append `?auth=<token>`
 *   so private uploads can be viewed (public ones ignore the query param)
 */
export const resolveMediaUrl = (url) => {
  if (!url) return "";
  if (/^https?:\/\//i.test(url)) return url;
  const token = localStorage.getItem("vq_token");
  const sep = url.includes("?") ? "&" : "?";
  return `${BACKEND_URL}${url}${token ? `${sep}auth=${encodeURIComponent(token)}` : ""}`;
};

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
