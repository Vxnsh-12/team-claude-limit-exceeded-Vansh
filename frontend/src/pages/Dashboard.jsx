import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Flame, Trophy, Award, LogOut, Bell } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { api } from "../lib/api";
import { LevelRing } from "../components/LevelRing";
import { QuestCard } from "../components/QuestCard";
import { QuestModal } from "../components/QuestModal";

export default function Dashboard() {
  const { user: rawUser, logout } = useAuth();
  const [quests, setQuests] = useState([]);
  const [selected, setSelected] = useState(null);

  const loadQuests = async () => {
    try {
      const { data } = await api.get("/quests/active");
      // If the backend returns { data: [...] } or something nested, this next line protects it:
      setQuests(data); 
    } catch (e) {}
  };

  useEffect(() => {
    loadQuests();
  }, []);

  if (!rawUser) return null;

  const safeUser = {
    name: "Student",
    xp: 0,
    level: 1,
    streak_days: 0,
    completed_quests: [],
    badges: [],
    ...rawUser 
  };

  // THE NEW FIX: Force quests to ALWAYS be an array before we .map() or check .length
  const safeQuests = Array.isArray(quests) ? quests : [];

  const firstName = safeUser.name.split(" ")[0];

  return (
    <div className="px-6 pt-8">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">
            Welcome back
          </div>
          <h1 className="font-display text-2xl font-black tracking-tight mt-1">
            Hey, <span className="text-[#00E5FF]">{firstName}</span>
          </h1>
        </div>
        <div className="flex items-center gap-2">
          <button
            data-testid="header-notifications"
            className="h-10 w-10 rounded-full bg-white/4 border border-white/8 flex items-center justify-center hover:border-[#00E5FF]/40 transition-colors"
            aria-label="Notifications"
          >
            <Bell size={16} className="text-white/70" />
          </button>
          <button
            data-testid="header-logout"
            onClick={logout}
            className="h-10 w-10 rounded-full bg-white/4 border border-white/8 flex items-center justify-center hover:border-red-400/40 transition-colors"
            aria-label="Logout"
          >
            <LogOut size={16} className="text-white/70" />
          </button>
        </div>
      </div>

      {/* Stats hero */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="mt-6 rounded-3xl p-5 bg-[#0F0F13] border border-white/6 relative overflow-hidden"
      >
        <div className="absolute -right-10 -top-10 w-40 h-40 rounded-full bg-[#00E5FF]/8 blur-3xl pointer-events-none" />
        <div className="absolute -left-6 bottom-0 w-32 h-32 rounded-full bg-[#39FF14]/6 blur-3xl pointer-events-none" />
        <div className="relative flex items-center gap-5">
          <LevelRing xp={safeUser.xp} level={safeUser.level} />
          <div className="flex-1 space-y-3">
            <MetricRow
              icon={Flame}
              tint="#FF8A3D"
              label="Streak"
              value={`${safeUser.streak_days} days`}
              testid="stat-streak"
            />
            <MetricRow
              icon={Trophy}
              tint="#39FF14"
              label="Quests"
              value={`${safeUser.completed_quests.length} done`}
              testid="stat-quests-done"
            />
            <MetricRow
              icon={Award}
              tint="#00E5FF"
              label="Badges"
              value={`${safeUser.badges.length} earned`}
              testid="stat-badges"
            />
          </div>
        </div>
      </motion.div>

      {/* Section header */}
      <div className="flex items-baseline justify-between mt-8">
        <h2 className="font-display text-xl font-bold tracking-tight">Active Quests</h2>
        {/* Replaced quests with safeQuests */}
        <span data-testid="active-quests-count" className="text-[11px] uppercase tracking-[0.25em] text-white/40 font-semibold">
          {safeQuests.length} available
        </span>
      </div>

      {/* Quests list */}
      <div className="mt-4 space-y-3">
        {/* Replaced quests with safeQuests */}
        {safeQuests.length === 0 && (
          <div className="rounded-3xl border border-white/6 bg-[#0F0F13] p-8 text-center text-white/50 text-sm">
            All quests completed. New ones incoming.
          </div>
        )}
        {/* Replaced quests with safeQuests */}
        {safeQuests.map((q, i) => (
          <motion.div
            key={q.id || i}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.05, duration: 0.35 }}
          >
            <QuestCard quest={q} onClick={setSelected} />
          </motion.div>
        ))}
      </div>

      <QuestModal
        quest={selected}
        open={!!selected}
        onClose={() => setSelected(null)}
        onCompleted={loadQuests}
      />
    </div>
  );
}

const MetricRow = ({ icon: Icon, label, value, tint, testid }) => (
  <div className="flex items-center gap-3" data-testid={testid}>
    <div
      className="h-9 w-9 rounded-xl flex items-center justify-center border"
      style={{ borderColor: `${tint}55`, background: `${tint}12` }}
    >
      <Icon size={16} strokeWidth={2.4} style={{ color: tint }} />
    </div>
    <div className="flex-1">
      <div className="text-[10px] uppercase tracking-[0.25em] text-white/40 font-semibold">{label}</div>
      <div className="font-display text-sm font-bold text-white">{value}</div>
    </div>
  </div>
);
