import React, { useState } from "react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "./ui/dialog";
import { MapPin, Clock, Trophy, Loader2, Zap, BookOpen, Utensils, Dumbbell, Search, Map as MapIcon, Users, KeyRound, GraduationCap, Sun, PartyPopper, Timer } from "lucide-react";
import { toast } from "sonner";
import { api, formatApiErrorDetail } from "../lib/api";
import { useAuth } from "../context/AuthContext";

const iconMap = {
  Zap, BookOpen, Utensils, Dumbbell, Search, Map: MapIcon, Users, KeyRound, GraduationCap, Sun, PartyPopper, Timer,
};

export const QuestModal = ({ quest, open, onClose, onCompleted }) => {
  const [loading, setLoading] = useState(false);
  const { setUser } = useAuth();

  if (!quest) return null;
  const Icon = iconMap[quest.icon] || Zap;

  const handleComplete = async () => {
    setLoading(true);
    try {
      const { data } = await api.post("/quests/complete", { quest_id: quest.id });
      setUser(data.user);
      toast.success(`+${data.xp_gained} XP earned!`, {
        description: data.leveled_up ? "You leveled up!" : quest.title,
      });
      if (data.new_badges?.length) {
        toast(`New badge unlocked: ${data.new_badges.join(", ")}`, {
          style: { background: "#0F0F13", border: "1px solid rgba(57,255,20,0.4)" },
        });
      }
      onCompleted?.(data);
      onClose();
    } catch (e) {
      toast.error(formatApiErrorDetail(e.response?.data?.detail) || e.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={(v) => !v && onClose()}>
      <DialogContent
        data-testid="quest-modal"
        className="glass border-white/10 rounded-3xl max-w-sm p-0 overflow-hidden"
      >
        <div className="relative p-6 pb-4">
          <div className="absolute inset-x-0 -top-24 h-40 bg-[#00E5FF]/10 blur-3xl pointer-events-none" />
          <div className="relative flex items-start gap-4">
            <div className="h-14 w-14 rounded-2xl bg-[#1A1A24] border border-[#00E5FF]/30 flex items-center justify-center neon-glow-blue">
              <Icon size={24} strokeWidth={2.5} className="text-[#00E5FF]" />
            </div>
            <div className="flex-1">
              <span className="text-[10px] font-bold uppercase tracking-[0.25em] text-white/50">
                Quest
              </span>
              <DialogTitle className="font-display text-xl font-bold text-white mt-0.5">
                {quest.title}
              </DialogTitle>
            </div>
          </div>
          <p className="text-sm text-white/70 mt-4 leading-relaxed">{quest.description}</p>

          <div className="grid grid-cols-3 gap-2 mt-6">
            <Stat icon={MapPin} label="Location" value={quest.location} />
            <Stat icon={Clock} label="Duration" value={`${quest.duration_min}m`} />
            <Stat icon={Trophy} label="Reward" value={`${quest.xp_reward} XP`} accent />
          </div>
        </div>

        <div className="p-6 pt-2 border-t border-white/6">
          <button
            data-testid="complete-quest-btn"
            onClick={handleComplete}
            disabled={loading || quest.completed}
            className="w-full h-12 rounded-full bg-[#00E5FF] text-black font-bold text-sm tracking-wide hover:shadow-[0_0_28px_rgba(0,229,255,0.55)] transition-[box-shadow,transform] active:scale-[0.98] disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {loading && <Loader2 size={16} className="animate-spin" />}
            {quest.completed ? "Already Completed" : "Complete Quest"}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
};

const Stat = ({ icon: Icon, label, value, accent }) => (
  <div className="rounded-2xl border border-white/6 bg-white/[0.02] px-3 py-3">
    <Icon size={14} className={accent ? "text-[#39FF14]" : "text-white/50"} />
    <div className="text-[10px] uppercase tracking-widest text-white/40 font-semibold mt-2">
      {label}
    </div>
    <div className={`text-xs font-bold mt-0.5 truncate ${accent ? "text-[#39FF14]" : "text-white"}`}>
      {value}
    </div>
  </div>
);
