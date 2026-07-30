import React, { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import { useAuth } from "../context/AuthContext";
import { Loader2, Compass } from "lucide-react";

export default function Login() {
  const { login } = useAuth();
  const nav = useNavigate();
  const [email, setEmail] = useState("player@vitquest.com");
  const [password, setPassword] = useState("player123");
  const [err, setErr] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErr("");
    setLoading(true);
    const res = await login(email, password);
    setLoading(false);
    if (res.ok) nav("/");
    else setErr(res.error);
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-[#050505] grid-bg px-6">
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="w-full max-w-md"
      >
        <div className="flex items-center gap-2 mb-8">
          <div className="h-10 w-10 rounded-2xl bg-[#00E5FF]/12 border border-[#00E5FF]/40 flex items-center justify-center neon-glow-blue">
            <Compass size={20} strokeWidth={2.5} className="text-[#00E5FF]" />
          </div>
          <div>
            <div className="text-[10px] tracking-[0.3em] uppercase text-white/50 font-semibold">Enter the</div>
            <div className="font-display text-lg font-black tracking-tight">VIT QUEST</div>
          </div>
        </div>

        <h1 className="font-display text-4xl sm:text-5xl font-black tracking-tighter">
          Welcome<br />
          <span className="text-[#00E5FF]" style={{ textShadow: "0 0 22px rgba(0,229,255,0.35)" }}>
            back, player.
          </span>
        </h1>
        <p className="text-white/50 mt-3 text-sm leading-relaxed max-w-sm">
          Log in to resume your campus quests, keep your streak alive and climb the leaderboard.
        </p>

        <form onSubmit={handleSubmit} className="mt-10 space-y-4">
          <Field label="Email">
            <input
              data-testid="login-email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@campus.edu"
              className="w-full bg-transparent outline-none text-white placeholder:text-white/30 font-medium"
            />
          </Field>
          <Field label="Password">
            <input
              data-testid="login-password"
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full bg-transparent outline-none text-white placeholder:text-white/30 font-medium"
            />
          </Field>

          {err && (
            <div data-testid="login-error" className="text-xs text-red-400 border border-red-500/30 bg-red-500/6 rounded-2xl px-4 py-3">
              {err}
            </div>
          )}

          <button
            type="submit"
            data-testid="login-submit"
            disabled={loading}
            className="w-full h-12 mt-2 rounded-full bg-[#00E5FF] text-black font-bold text-sm tracking-wide hover:shadow-[0_0_28px_rgba(0,229,255,0.55)] transition-[box-shadow,transform] active:scale-[0.98] disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {loading && <Loader2 size={16} className="animate-spin" />} Sign In
          </button>
        </form>

        <p className="text-center text-sm text-white/50 mt-8">
          New here?{" "}
          <Link to="/register" data-testid="link-register" className="text-[#39FF14] font-semibold hover:underline">
            Create an account
          </Link>
        </p>
      </motion.div>
    </div>
  );
}

const Field = ({ label, children }) => (
  <label className="block rounded-2xl border border-white/8 bg-white/[0.02] px-4 py-3 focus-within:border-[#00E5FF]/50 transition-colors">
    <div className="text-[10px] uppercase tracking-[0.25em] text-white/40 font-semibold mb-1">{label}</div>
    {children}
  </label>
);
