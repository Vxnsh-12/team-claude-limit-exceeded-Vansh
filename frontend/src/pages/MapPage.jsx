import React, { useEffect, useState, useMemo } from "react";
import { motion } from "framer-motion";
import { MapPin, Compass, Zap } from "lucide-react";
import { api } from "../lib/api";
import { QuestModal } from "../components/QuestModal";

const typeColor = {
  academic: "#00E5FF",
  food: "#FF8A3D",
  fitness: "#39FF14",
  event: "#C084FC",
  residence: "#94A3B8",
  entry: "#F1F5F9",
  recreation: "#39FF14",
};

export default function MapPage() {
  const [locations, setLocations] = useState([]);
  const [quests, setQuests] = useState([]);
  const [selected, setSelected] = useState(null);

  useEffect(() => {
    Promise.all([api.get("/locations"), api.get("/quests")]).then(([l, q]) => {
      setLocations(l.data);
      setQuests(q.data);
    });
  }, []);

  const questsByLoc = useMemo(() => {
    const m = {};
    for (const q of quests) {
      if (!m[q.location_id]) m[q.location_id] = [];
      m[q.location_id].push(q);
    }
    return m;
  }, [quests]);

  const openQuestForLocation = (locId) => {
    const list = (questsByLoc[locId] || []).filter((q) => !q.completed);
    if (list[0]) setSelected(list[0]);
  };

  return (
    <div className="px-6 pt-8">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">Campus</div>
          <h1 className="font-display text-2xl font-black tracking-tight mt-1">
            Explore <span className="text-[#39FF14]">Map</span>
          </h1>
        </div>
        <div className="h-10 w-10 rounded-full bg-white/4 border border-white/8 flex items-center justify-center">
          <Compass size={16} className="text-[#00E5FF]" />
        </div>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mt-6 rounded-3xl overflow-hidden border border-white/6 bg-[#0F0F13] relative"
        style={{ aspectRatio: "3/4" }}
      >
        <svg viewBox="0 0 800 600" className="w-full h-full block">
          <defs>
            <linearGradient id="mapBg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#0A0A12" />
              <stop offset="100%" stopColor="#050508" />
            </linearGradient>
            <pattern id="dots" width="24" height="24" patternUnits="userSpaceOnUse">
              <circle cx="1" cy="1" r="0.8" fill="rgba(255,255,255,0.06)" />
            </pattern>
            <radialGradient id="glow" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="rgba(0,229,255,0.15)" />
              <stop offset="100%" stopColor="rgba(0,229,255,0)" />
            </radialGradient>
          </defs>
          <rect width="800" height="600" fill="url(#mapBg)" />
          <rect width="800" height="600" fill="url(#dots)" />
          <circle cx="400" cy="300" r="260" fill="url(#glow)" />

          {/* Stylized campus paths */}
          <g stroke="rgba(0,229,255,0.18)" strokeWidth="2" fill="none" strokeLinecap="round" strokeDasharray="4 6">
            <path d="M 50 380 L 180 300 L 300 220 L 430 160 L 520 260 L 640 200" />
            <path d="M 220 460 L 360 300 L 380 380 L 560 420 L 700 350" />
            <path d="M 100 500 L 220 460" />
          </g>

          {/* Stylized "buildings" as rounded blobs */}
          {locations.map((loc) => (
            <g key={`b-${loc.id}`}>
              <rect
                x={loc.x - 22}
                y={loc.y - 18}
                width="44"
                height="36"
                rx="10"
                fill="#12121A"
                stroke={typeColor[loc.type] || "#00E5FF"}
                strokeOpacity="0.5"
                strokeWidth="1.5"
              />
            </g>
          ))}

          {/* Quest pins */}
          {locations.map((loc) => {
            const hasQuest = (questsByLoc[loc.id] || []).some((q) => !q.completed);
            const color = typeColor[loc.type] || "#00E5FF";
            return (
              <g
                key={loc.id}
                transform={`translate(${loc.x} ${loc.y - 30})`}
                style={{ cursor: hasQuest ? "pointer" : "default" }}
                onClick={() => hasQuest && openQuestForLocation(loc.id)}
                data-testid={`map-pin-${loc.id}`}
              >
                {hasQuest && (
                  <circle r="18" fill={color} fillOpacity="0.35" className="pulse-ring" style={{ transformOrigin: "center" }} />
                )}
                <circle r="8" fill={color} />
                <circle r="8" fill="none" stroke="#050505" strokeWidth="2" />
              </g>
            );
          })}
        </svg>

        {/* Legend */}
        <div className="absolute left-3 bottom-3 right-3 flex items-center gap-2 flex-wrap">
          <LegendChip color="#00E5FF" label="Academic" />
          <LegendChip color="#39FF14" label="Fitness" />
          <LegendChip color="#FF8A3D" label="Food" />
          <LegendChip color="#C084FC" label="Event" />
        </div>
      </motion.div>

      {/* Nearby quests list */}
      <div className="flex items-baseline justify-between mt-6">
        <h2 className="font-display text-lg font-bold tracking-tight">Nearby Quests</h2>
        <span className="text-[10px] uppercase tracking-[0.25em] text-white/40 font-semibold">
          Tap a pin
        </span>
      </div>

      <div className="mt-3 space-y-2">
        {locations.map((loc) => {
          const active = (questsByLoc[loc.id] || []).filter((q) => !q.completed);
          if (active.length === 0) return null;
          return (
            <button
              key={loc.id}
              data-testid={`nearby-quest-${loc.id}`}
              onClick={() => setSelected(active[0])}
              className="w-full flex items-center gap-3 rounded-2xl border border-white/6 bg-[#0F0F13] p-3 hover:border-[#00E5FF]/40 transition-colors text-left"
            >
              <div
                className="h-9 w-9 rounded-xl flex items-center justify-center border"
                style={{
                  borderColor: `${typeColor[loc.type] || "#00E5FF"}55`,
                  background: `${typeColor[loc.type] || "#00E5FF"}12`,
                }}
              >
                <MapPin size={14} style={{ color: typeColor[loc.type] || "#00E5FF" }} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-xs font-bold text-white truncate">{loc.name}</div>
                <div className="text-[10px] text-white/40 truncate">{active[0].title}</div>
              </div>
              <div className="flex items-center gap-1 text-[#39FF14] font-display font-black">
                <Zap size={12} /> {active[0].xp_reward}
              </div>
            </button>
          );
        })}
      </div>

      <QuestModal
        quest={selected}
        open={!!selected}
        onClose={() => setSelected(null)}
        onCompleted={() => {
          api.get("/quests").then(({ data }) => setQuests(data));
        }}
      />
    </div>
  );
}

const LegendChip = ({ color, label }) => (
  <div className="glass rounded-full px-2.5 py-1 flex items-center gap-1.5 text-[10px] font-semibold tracking-wide">
    <span className="h-2 w-2 rounded-full" style={{ background: color, boxShadow: `0 0 8px ${color}` }} />
    {label}
  </div>
);
