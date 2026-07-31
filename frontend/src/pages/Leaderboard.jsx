import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Crown, Medal, Trophy, UserPlus, Check, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { api, resolveMediaUrl } from "../lib/api";

export default function Leaderboard() {
  const [rows, setRows] = useState([]);
  const [scope, setScope] = useState("all");
  const [friendIds, setFriendIds] = useState(new Set());
  const [sending, setSending] = useState(null);

  const safeRows = Array.isArray(rows) ? rows : [];
  const safeFriendIds = Array.isArray(friendIds) ? friendIds : [];

  useEffect(() => {
    api.get(`/leaderboard?scope=${scope}`).then(({ data }) => setRows(Array.isArray(data) ? data : []));
  }, [scope]);
  useEffect(() => {
    api.get("/friends").then(({ data }) => {
      const ids = Array.isArray(data) ? data.map((u) => u?.id).filter(Boolean) : [];
      setFriendIds(new Set(ids));
    }).catch(() => {});
  }, []);

  const addFriend = async (r) => {
    setSending(r.id);
    try {
      const { data } = await api.post("/friends/requests", { to_user_id: r.id });
      if (data.status === "accepted") {
        setFriendIds((s) => new Set([...s, r.id]));
        toast(`🎉 You're now friends with ${r.name}`);
      } else {
        toast(`✅ Friend request sent to ${r.name}`);
      }
    } catch (e) {
      toast.error(e.response?.data?.detail || "Failed");
    } finally { setSending(null); }
  };

  const top3 = safeRows.slice(0, 3);
  const rest = safeRows.slice(3);

  return (
    <div className="px-6 pt-8">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">Ranks</div>
          <h1 className="font-display text-2xl font-black tracking-tight mt-1">
            Global <span className="text-[#00E5FF]">Leaders</span>
          </h1>
        </div>
        <div className="glass rounded-full p-1 flex text-[11px] font-semibold">
          {[{ k: "all", l: "All-Time" }, { k: "week", l: "Weekly" }].map((t) => (
            <button
              key={t.k}
              data-testid={`scope-${t.k}`}
              onClick={() => setScope(t.k)}
              className={`px-3 py-1.5 rounded-full transition-colors ${
                scope === t.k ? "bg-[#00E5FF] text-black" : "text-white/60"
              }`}
            >
              {t.l}
            </button>
          ))}
        </div>
      </div>

      {/* Podium */}
      <div className="mt-8 grid grid-cols-3 gap-3 items-end">
        <Podium place={2} row={top3[1]} height={110} />
        <Podium place={1} row={top3[0]} height={140} highlight />
        <Podium place={3} row={top3[2]} height={90} />
      </div>

      {/* List */}
      <div className="mt-8 space-y-2">
        {rest.map((r, i) => (
          <motion.div
            key={r.id}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.03, duration: 0.3 }}
            data-testid={`leaderboard-row-${r.rank}`}
            className={`rounded-2xl border p-3 flex items-center gap-3 ${
              r.is_you
                ? "border-[#00E5FF]/50 bg-[#00E5FF]/6"
                : "border-white/6 bg-[#0F0F13]"
            }`}
          >
            <div className="w-8 text-center font-display font-black text-white/70">
              #{r.rank}
            </div>
            <img
              src={resolveMediaUrl(r.avatar_url)}
              alt={r.name}
              className="h-11 w-11 rounded-full bg-[#1A1A24] object-cover ring-1 ring-white/10"
            />
            <div className="flex-1 min-w-0">
              <div className="text-sm font-bold truncate flex items-center gap-2">
                {r.name}
                {r.is_you && (
                  <span className="text-[9px] uppercase tracking-widest text-[#00E5FF] font-black">
                    You
                  </span>
                )}
              </div>
              <div className="text-[10px] text-white/40 font-semibold uppercase tracking-wider">
                Level {r.level}
              </div>
            </div>
            <div className="text-right">
              <div className="font-display text-base font-black text-[#39FF14]">
                {r.xp.toLocaleString()}
              </div>
              <div className="text-[9px] text-white/40 uppercase tracking-widest font-semibold">XP</div>
            </div>
            {!r.is_you && (
              friendIds.has(r.id) ? (
                <span data-testid={`friend-status-${r.id}`} className="ml-2 h-8 px-2.5 rounded-full text-[9px] font-black uppercase tracking-wider bg-[#39FF14]/15 border border-[#39FF14]/50 text-[#39FF14] flex items-center gap-1">
                  <Check size={10} /> Friends
                </span>
              ) : (
                <button
                  type="button"
                  data-testid={`lb-add-friend-${r.id}`}
                  disabled={sending === r.id}
                  onClick={() => addFriend(r)}
                  className="ml-2 h-8 w-8 rounded-full bg-[#00E5FF]/12 border border-[#00E5FF]/40 text-[#00E5FF] hover:bg-[#00E5FF]/25 disabled:opacity-50 flex items-center justify-center"
                  aria-label={`Add ${r.name}`}
                  title={`Add ${r.name}`}
                >
                  {sending === r.id ? <Loader2 size={12} className="animate-spin" /> : <UserPlus size={12} />}
                </button>
              )
            )}
          </motion.div>
        ))}
      </div>
    </div>
  );
}

const Podium = ({ place, row, height, highlight }) => {
  if (!row || typeof row !== "object") return <div />;
  const Icon = place === 1 ? Crown : place === 2 ? Medal : Trophy;
  const accent = place === 1 ? "#39FF14" : place === 2 ? "#00E5FF" : "#C084FC";
  return (
    <div className="flex flex-col items-center" data-testid={`podium-${place}`}>
      <div className="relative">
        <img
          src={resolveMediaUrl(row.avatar_url)}
          alt={row.name}
          className={`rounded-full object-cover ring-2 ${
            place === 1 ? "h-16 w-16" : "h-12 w-12"
          }`}
          style={{ boxShadow: `0 0 22px ${accent}55`, borderColor: accent }}
        />
        <div
          className="absolute -top-3 left-1/2 -translate-x-1/2 h-6 w-6 rounded-full flex items-center justify-center"
          style={{ background: accent }}
        >
          <Icon size={12} className="text-black" strokeWidth={3} />
        </div>
      </div>
      <div className="mt-2 text-[11px] font-bold text-white text-center max-w-full truncate w-full">
        {row.name}
      </div>
      <div className="font-display font-black text-sm mt-0.5" style={{ color: accent }}>
        {(row.xp ?? 0).toLocaleString()}
      </div>
      <div
        className={`w-full mt-2 rounded-t-2xl border-t border-l border-r ${
          highlight ? "bg-[#00E5FF]/10 border-[#00E5FF]/30" : "bg-white/[0.03] border-white/8"
        } flex items-start justify-center pt-2`}
        style={{ height }}
      >
        <span className="font-display font-black text-white/70 text-lg">#{place}</span>
      </div>
    </div>
  );
};
