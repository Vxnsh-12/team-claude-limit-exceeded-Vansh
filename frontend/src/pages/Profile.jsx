import React from "react";
import { motion } from "framer-motion";
import { Flame, Trophy, Sparkles, Zap, ShieldCheck, Compass, MapPin, LogOut } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { LevelRing } from "../components/LevelRing";

const badgeDefs = {
  "first-quest": { label: "First Quest", icon: Sparkles, color: "#00E5FF" },
  "explorer": { label: "Explorer", icon: Compass, color: "#39FF14" },
  "veteran": { label: "Veteran", icon: ShieldCheck, color: "#C084FC" },
  "fit-warrior": { label: "Fit Warrior", icon: Flame, color: "#FF8A3D" },
};

export default function Profile() {
  const { user, logout } = useAuth();
  if (!user) return null;

  return (
    <div className="px-6 pt-8">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">Player</div>
          <h1 className="font-display text-2xl font-black tracking-tight mt-1">Profile</h1>
        </div>
        <button
          data-testid="profile-logout"
          onClick={logout}
          className="h-10 px-4 rounded-full bg-white/4 border border-white/8 flex items-center gap-2 text-[12px] font-semibold text-white/70 hover:border-red-400/40 transition-colors"
        >
          <LogOut size={14} /> Log out
        </button>
      </div>

      {/* Profile card */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="mt-6 rounded-3xl p-6 bg-[#0F0F13] border border-white/6 relative overflow-hidden"
      >
        <div className="absolute -right-16 -top-16 w-56 h-56 rounded-full bg-[#00E5FF]/8 blur-3xl pointer-events-none" />
        <div className="relative flex items-center gap-5">
          <div className="relative">
            <img
              src={user.avatar_url}
              alt={user.name}
              className="h-24 w-24 rounded-full bg-[#1A1A24] object-cover ring-2 ring-[#00E5FF]/60"
              style={{ boxShadow: "0 0 30px rgba(0,229,255,0.35)" }}
            />
            <div className="absolute -bottom-1 -right-1 h-8 w-8 rounded-full bg-[#39FF14] text-black flex items-center justify-center font-display font-black text-xs">
              L{user.level}
            </div>
          </div>
          <div className="flex-1 min-w-0">
            <h2 className="font-display text-2xl font-black tracking-tight truncate">
              {user.name}
            </h2>
            <p className="text-xs text-white/50 truncate">{user.email}</p>
            <div className="mt-3 flex items-center gap-2">
              <span className="glass rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider flex items-center gap-1">
                <MapPin size={10} className="text-[#00E5FF]" /> VIT Vellore
              </span>
              <span className="glass rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider flex items-center gap-1">
                <Flame size={10} className="text-[#FF8A3D]" /> {user.streak_days}d streak
              </span>
            </div>
          </div>
        </div>

        {/* Level ring + XP */}
        <div className="mt-6 flex items-center gap-5">
          <LevelRing xp={user.xp} level={user.level} size={120} stroke={9} />
          <div className="flex-1 grid grid-cols-1 gap-2">
            <StatTile icon={Zap} tint="#39FF14" label="Total XP" value={user.xp.toLocaleString()} />
            <StatTile icon={Trophy} tint="#00E5FF" label="Quests" value={user.completed_quests.length} />
            <StatTile icon={Sparkles} tint="#C084FC" label="Badges" value={user.badges.length} />
          </div>
        </div>
      </motion.div>

      {/* Badges */}
      <h3 className="font-display text-lg font-bold tracking-tight mt-8">Badges</h3>
      <div className="mt-3 grid grid-cols-3 gap-3">
        {Object.entries(badgeDefs).map(([key, def]) => {
          const owned = user.badges.includes(key);
          const Icon = def.icon;
          return (
            <div
              key={key}
              data-testid={`badge-${key}`}
              className={`rounded-3xl p-4 flex flex-col items-center text-center border transition-colors ${
                owned
                  ? "border-white/10 bg-[#0F0F13]"
                  : "border-white/6 bg-white/[0.02] opacity-45"
              }`}
              style={owned ? { boxShadow: `0 0 22px ${def.color}22` } : undefined}
            >
              <div
                className="h-12 w-12 rounded-2xl flex items-center justify-center border"
                style={{
                  borderColor: `${def.color}${owned ? "55" : "22"}`,
                  background: `${def.color}${owned ? "18" : "08"}`,
                }}
              >
                <Icon size={20} strokeWidth={2.4} style={{ color: def.color }} />
              </div>
              <div className="text-[11px] font-bold mt-2">{def.label}</div>
              <div className="text-[9px] uppercase tracking-widest text-white/40 font-semibold mt-0.5">
                {owned ? "Unlocked" : "Locked"}
              </div>
            </div>
          );
        })}
      </div>

      {/* Recent quests */}
      <h3 className="font-display text-lg font-bold tracking-tight mt-8">Quest History</h3>
      <div className="mt-3 space-y-2">
        {user.completed_quests.length === 0 && (
          <div className="rounded-2xl border border-white/6 bg-[#0F0F13] p-6 text-center text-white/50 text-sm">
            No quests completed yet. Start your first one!
          </div>
        )}
        {user.completed_quests.slice(0, 5).map((q, i) => (
          <div
            key={q}
            data-testid={`history-${q}`}
            className="rounded-2xl border border-white/6 bg-[#0F0F13] p-3 flex items-center gap-3"
          >
            <div className="h-9 w-9 rounded-xl bg-[#39FF14]/12 border border-[#39FF14]/40 flex items-center justify-center">
              <Trophy size={14} className="text-[#39FF14]" />
            </div>
            <div className="flex-1 text-xs font-semibold text-white/80">
              Quest {q}
            </div>
            <span className="text-[10px] uppercase tracking-widest text-white/40 font-semibold">
              Completed
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

const StatTile = ({ icon: Icon, tint, label, value }) => (
  <div className="rounded-2xl border border-white/6 bg-white/[0.02] p-3 flex items-center gap-3">
    <div
      className="h-9 w-9 rounded-xl flex items-center justify-center border"
      style={{ borderColor: `${tint}55`, background: `${tint}12` }}
    >
      <Icon size={14} style={{ color: tint }} />
    </div>
    <div className="flex-1">
      <div className="text-[9px] uppercase tracking-widest text-white/40 font-semibold">
        {label}
      </div>
      <div className="font-display text-sm font-black text-white">{value}</div>
    </div>
  </div>
);
