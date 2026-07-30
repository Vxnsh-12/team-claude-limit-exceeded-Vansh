import React from "react";
import { MapPin, Zap, BookOpen, Utensils, Dumbbell, Search, Map as MapIcon, Users, KeyRound, GraduationCap, Sun, PartyPopper, Timer, CheckCircle2 } from "lucide-react";

const iconMap = {
  Zap, BookOpen, Utensils, Dumbbell, Search, Map: MapIcon, Users, KeyRound, GraduationCap, Sun, PartyPopper, Timer,
};

const difficultyColor = {
  easy: "text-[#39FF14] border-[#39FF14]/40 bg-[#39FF14]/6",
  medium: "text-[#00E5FF] border-[#00E5FF]/40 bg-[#00E5FF]/6",
  hard: "text-[#FF6B9D] border-[#FF6B9D]/40 bg-[#FF6B9D]/6",
};

export const QuestCard = ({ quest, onClick }) => {
  const Icon = iconMap[quest.icon] || Zap;
  const done = quest.completed;
  return (
    <button
      type="button"
      onClick={() => onClick?.(quest)}
      data-testid={`quest-card-${quest.id}`}
      className={`w-full text-left rounded-3xl p-5 bg-[#0F0F13] border border-white/6 hover:border-[#00E5FF]/40 transition-[border-color,transform,box-shadow] duration-300 hover:-translate-y-0.5 hover:shadow-[0_12px_30px_rgba(0,229,255,0.10)] active:scale-[0.99] ${
        done ? "opacity-60" : ""
      }`}
    >
      <div className="flex items-start gap-4">
        <div className="h-12 w-12 flex-shrink-0 rounded-2xl bg-[#1A1A24] border border-white/8 flex items-center justify-center">
          <Icon size={22} strokeWidth={2.4} className="text-[#00E5FF]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <h3 className="font-display text-[15px] font-bold text-white truncate">
              {quest.title}
            </h3>
            {done && <CheckCircle2 size={16} className="text-[#39FF14]" />}
          </div>
          <p className="text-xs text-white/55 mt-1 line-clamp-2 leading-relaxed">
            {quest.description}
          </p>
          <div className="flex items-center gap-2 mt-3 flex-wrap">
            <span
              className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border ${
                difficultyColor[quest.difficulty] || difficultyColor.easy
              }`}
            >
              {quest.difficulty}
            </span>
            <span className="flex items-center gap-1 text-[11px] text-white/50">
              <MapPin size={12} /> {quest.location}
            </span>
          </div>
        </div>
        <div className="flex flex-col items-end">
          <span className="font-display text-lg font-black text-[#39FF14]" style={{ textShadow: "0 0 12px rgba(57,255,20,0.5)" }}>
            +{quest.xp_reward}
          </span>
          <span className="text-[9px] uppercase tracking-widest text-white/40 font-semibold mt-0.5">XP</span>
        </div>
      </div>
    </button>
  );
};
