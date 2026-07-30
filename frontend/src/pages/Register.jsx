import React, { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { motion } from "framer-motion";
import { useAuth } from "../context/AuthContext";
import { Loader2, Sparkles } from "lucide-react";

export default function Register() {
  const { register } = useAuth();
  const nav = useNavigate();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [err, setErr] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErr("");
    setLoading(true);
    const res = await register(name, email, password);
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
          <div className="h-10 w-10 rounded-2xl bg-[#39FF14]/12 border border-[#39FF14]/40 flex items-center justify-center neon-glow-green">
            <Sparkles size={20} strokeWidth={2.5} className="text-[#39FF14]" />
          </div>
          <div>
            <div className="text-[10px] tracking-[0.3em] uppercase text-white/50 font-semibold">Join the</div>
            <div className="font-display text-lg font-black tracking-tight">VIT QUEST</div>
          </div>
        </div>

        <h1 className="font-display text-4xl sm:text-5xl font-black tracking-tighter">
          Begin your<br />
          <span className="text-[#39FF14]" style={{ textShadow: "0 0 22px rgba(57,255,20,0.4)" }}>
            first quest.
          </span>
        </h1>
        <p className="text-white/50 mt-3 text-sm leading-relaxed max-w-sm">
          Sign up in seconds. Earn XP, unlock badges, and race friends up the ranks.
        </p>

        <form onSubmit={handleSubmit} className="mt-10 space-y-4">
          <Field label="Player Name">
            <input
              data-testid="register-name"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Rhea"
              className="w-full bg-transparent outline-none text-white placeholder:text-white/30 font-medium"
            />
          </Field>
          <Field label="Email">
            <input
              data-testid="register-email"
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
              data-testid="register-password"
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="at least 6 chars"
              className="w-full bg-transparent outline-none text-white placeholder:text-white/30 font-medium"
            />
          </Field>

          {err && (
            <div data-testid="register-error" className="text-xs text-red-400 border border-red-500/30 bg-red-500/6 rounded-2xl px-4 py-3">
              {err}
            </div>
          )}

          <button
            type="submit"
            data-testid="register-submit"
            disabled={loading}
            className="w-full h-12 mt-2 rounded-full bg-[#39FF14] text-black font-bold text-sm tracking-wide hover:shadow-[0_0_28px_rgba(57,255,20,0.55)] transition-[box-shadow,transform] active:scale-[0.98] disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {loading && <Loader2 size={16} className="animate-spin" />} Create Account
          </button>
        </form>

        <p className="text-center text-sm text-white/50 mt-8">
          Already playing?{" "}
          <Link to="/login" data-testid="link-login" className="text-[#00E5FF] font-semibold hover:underline">
            Sign in
          </Link>
        </p>
      </motion.div>
    </div>
  );
}

const Field = ({ label, children }) => (
  <label className="block rounded-2xl border border-white/8 bg-white/[0.02] px-4 py-3 focus-within:border-[#39FF14]/50 transition-colors">
    <div className="text-[10px] uppercase tracking-[0.25em] text-white/40 font-semibold mb-1">{label}</div>
    {children}
  </label>
);
