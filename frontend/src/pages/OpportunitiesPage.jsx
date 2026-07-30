import React, { useMemo, useState } from "react";
import { Send, Trophy, Zap, GraduationCap, Users, Rocket } from "lucide-react";
import { toast } from "sonner";

const FILTERS = ["All", "Python", "React", "ML", "Competitions"];

const POSTS = [
  {
    id: "sih-team",
    title: "Smart India Hackathon Team",
    description: "Looking for two teammates to build a computer-vision solution for the SIH shortlist. Prototype due in 3 weeks.",
    skills: ["React", "ML", "Python"],
    poster: "Rhea Kapoor · 3rd year",
    accent: "#00E5FF",
    icon: Trophy,
    tag: "Hackathon",
  },
  {
    id: "advitya",
    title: "AdVITya Coding Contest",
    description: "3-hour algorithms sprint · ₹15,000 prize pool · beginners and pros both welcome. Team of 2 max.",
    skills: ["Python", "Competitions"],
    poster: "Coding Club · Official",
    accent: "#DC2626",
    icon: Zap,
    tag: "Competition",
  },
  {
    id: "ai-research",
    title: "AI Research Study Group",
    description: "Weekly reading group on foundation models. Great fit for anyone eyeing MS applications.",
    skills: ["ML"],
    poster: "Dr. Anand Iyer · Faculty",
    accent: "#C084FC",
    icon: GraduationCap,
    tag: "Research",
  },
  {
    id: "react-meetup",
    title: "React Design Systems Meetup",
    description: "Study group for building production-grade design systems in React + Tailwind. Meets Wed 7 PM at AB-2.",
    skills: ["React"],
    poster: "ARON J. · 2nd year",
    accent: "#39FF14",
    icon: Users,
    tag: "Study Group",
  },
  {
    id: "kaggle",
    title: "Kaggle Intramural Challenge",
    description: "Beat the campus baseline model — top 3 win Bluetooth headphones + certificates.",
    skills: ["Python", "ML", "Competitions"],
    poster: "Data Club · Official",
    accent: "#0EA5E9",
    icon: Rocket,
    tag: "Competition",
  },
];

export default function OpportunitiesPage() {
  const [filter, setFilter] = useState("All");

  const filtered = useMemo(() => {
    if (filter === "All") return POSTS;
    return POSTS.filter((p) => p.skills.includes(filter) || p.tag === filter);
  }, [filter]);

  const onApply = (p) => {
    toast(`🚀 Applied to "${p.title}" — poster will be notified.`, {
      style: {
        background: "#0F0F13",
        border: "1px solid rgba(57,255,20,0.5)",
        color: "#fff",
        fontWeight: 700,
      },
    });
  };

  return (
    <div className="px-6 pt-8" data-testid="opportunities-page">
      <div>
        <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">Marketplace</div>
        <h1 className="font-display text-2xl font-black tracking-tight mt-1">
          Opportunities <span className="text-[#00E5FF]">for you</span>
        </h1>
      </div>

      {/* Filter chips */}
      <div className="mt-5 -mx-6 overflow-x-auto no-scrollbar">
        <div className="px-6 flex items-center gap-2 min-w-max">
          {FILTERS.map((f) => {
            const active = filter === f;
            return (
              <button
                key={f}
                type="button"
                data-testid={`filter-${f}`}
                onClick={() => setFilter(f)}
                className={`px-3.5 py-1.5 rounded-full text-[11px] font-bold uppercase tracking-wider border transition-all whitespace-nowrap ${
                  active
                    ? "bg-[#00E5FF] text-black border-[#00E5FF] shadow-[0_0_18px_rgba(0,229,255,0.35)]"
                    : "bg-white/[0.03] text-white/60 border-white/10 hover:text-white/90"
                }`}
              >
                {f}
              </button>
            );
          })}
        </div>
      </div>

      <div className="mt-5 space-y-3 pb-8">
        {filtered.map((p) => {
          const Icon = p.icon;
          return (
            <div
              key={p.id}
              data-testid={`opp-${p.id}`}
              className="rounded-3xl bg-[#0F0F13] border border-white/6 p-4"
            >
              <div className="flex items-start gap-3">
                <div
                  className="h-11 w-11 rounded-2xl flex items-center justify-center border"
                  style={{
                    background: `${p.accent}1F`,
                    borderColor: `${p.accent}66`,
                  }}
                >
                  <Icon size={18} style={{ color: p.accent }} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <h3 className="font-display text-[15px] font-bold text-white truncate">{p.title}</h3>
                  </div>
                  <p className="text-[11px] text-white/45 mt-0.5">{p.poster}</p>
                </div>
                <span
                  className="px-2 py-1 rounded-full text-[9px] font-black uppercase tracking-wider"
                  style={{ background: `${p.accent}1F`, color: p.accent }}
                >
                  {p.tag}
                </span>
              </div>
              <p className="text-xs text-white/65 mt-3 leading-relaxed">{p.description}</p>
              <div className="mt-3 flex flex-wrap gap-1.5">
                {p.skills.map((s) => (
                  <span
                    key={s}
                    className="px-2 py-1 rounded-full text-[9px] font-black uppercase tracking-wider bg-white/[0.04] border border-white/8 text-white/70"
                  >
                    {s}
                  </span>
                ))}
              </div>
              <button
                type="button"
                data-testid={`apply-${p.id}`}
                onClick={() => onApply(p)}
                className="mt-4 w-full h-10 rounded-full font-bold text-sm flex items-center justify-center gap-2 active:scale-[0.98] transition-transform"
                style={{
                  background: p.accent,
                  color: "#050505",
                  boxShadow: `0 0 22px ${p.accent}55`,
                }}
              >
                <Send size={14} /> Apply / Connect
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
