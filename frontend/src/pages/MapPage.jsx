import React, { useEffect, useState, useMemo } from "react";
import { motion } from "framer-motion";
import { MapPin, Compass, Zap } from "lucide-react";
import { api } from "../lib/api";
import { QuestModal } from "../components/QuestModal";

const typeColor = {
  academic:   "#00E5FF",
  food:       "#FF8A3D",
  fitness:    "#39FF14",
  event:      "#C084FC",
  residence:  "#94A3B8",
  entry:      "#F1F5F9",
  recreation: "#39FF14",
  utility:    "#F59E0B",
};

const typeLabel = {
  academic: "Academic", food: "Food", fitness: "Sports",
  event: "Event", residence: "Hostel", entry: "Gate",
  recreation: "Plaza", utility: "Utility",
};

// --- Static decorations (VIT Bhopal illustrated layout) ---
const ZONES = [
  { label: "ACADEMIC ZONE",    x: 380, y: 90,  w: 500, h: 240, color: "#00E5FF" },
  { label: "RESIDENTIAL",       x: 130, y: 480, w: 220, h: 100, color: "#94A3B8" },
  { label: "SPORTS ZONE",       x: 690, y: 290, w: 200, h: 130, color: "#39FF14" },
  { label: "CENTRAL",           x: 380, y: 400, w: 220, h: 90,  color: "#C084FC" },
];

const TREES = [
  [ 90,  200], [155, 155], [ 70,  380], [ 40,  460], [140, 390],
  [560, 100], [640, 100], [720, 130], [810, 200], [770, 400],
  [255, 470], [305, 520], [460, 530], [590, 520], [660, 550],
  [750, 500], [420, 250], [520, 260], [610, 300], [ 20,  260],
];

// A small lake near the boys hostel
const LAKE = { cx: 620, cy: 380, rx: 42, ry: 22 };

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

  const activeCount = quests.filter((q) => !q.completed).length;

  return (
    <div className="px-6 pt-8">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">
            VIT Bhopal
          </div>
          <h1 className="font-display text-2xl font-black tracking-tight mt-1">
            Explore <span className="text-[#39FF14]">Campus</span>
          </h1>
        </div>
        <div className="glass rounded-full px-3 py-2 flex items-center gap-2">
          <Compass size={14} className="text-[#00E5FF]" />
          <span className="font-display text-xs font-black tracking-wide">
            {activeCount}
          </span>
          <span className="text-[10px] uppercase tracking-widest text-white/50 font-semibold">
            active
          </span>
        </div>
      </div>

      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mt-6 rounded-3xl overflow-hidden border border-white/8 bg-[#0A0A12] relative"
        style={{ aspectRatio: "4/5" }}
        data-testid="campus-map"
      >
        <svg viewBox="0 0 800 620" className="w-full h-full block">
          <defs>
            {/* Base gradient */}
            <linearGradient id="mapBg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#0A0A12" />
              <stop offset="60%" stopColor="#070710" />
              <stop offset="100%" stopColor="#050508" />
            </linearGradient>
            {/* Faint dot grid */}
            <pattern id="dots" width="24" height="24" patternUnits="userSpaceOnUse">
              <circle cx="1" cy="1" r="0.8" fill="rgba(255,255,255,0.05)" />
            </pattern>
            {/* Ground / green regions */}
            <linearGradient id="green" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="rgba(57,255,20,0.08)" />
              <stop offset="100%" stopColor="rgba(57,255,20,0.02)" />
            </linearGradient>
            {/* Lake gradient */}
            <radialGradient id="lake" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="rgba(0,229,255,0.55)" />
              <stop offset="100%" stopColor="rgba(0,229,255,0.05)" />
            </radialGradient>
            {/* Building fill */}
            <linearGradient id="bldg" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#171725" />
              <stop offset="100%" stopColor="#0E0E18" />
            </linearGradient>
            {/* Glow filter */}
            <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="3" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>

          {/* Background */}
          <rect width="800" height="620" fill="url(#mapBg)" />
          <rect width="800" height="620" fill="url(#dots)" />

          {/* Green ground blob */}
          <path
            d="M 0 300 Q 200 220, 400 260 T 800 220 L 800 620 L 0 620 Z"
            fill="url(#green)"
          />

          {/* Zones */}
          {ZONES.map((z) => (
            <g key={z.label}>
              <rect
                x={z.x - z.w / 2}
                y={z.y - z.h / 2}
                width={z.w}
                height={z.h}
                rx="26"
                fill={z.color}
                fillOpacity="0.04"
                stroke={z.color}
                strokeOpacity="0.18"
                strokeDasharray="3 5"
                strokeWidth="1"
              />
              <text
                x={z.x - z.w / 2 + 14}
                y={z.y - z.h / 2 + 20}
                fill={z.color}
                fillOpacity="0.55"
                fontSize="9"
                fontWeight="800"
                letterSpacing="2.5"
                fontFamily="Manrope, sans-serif"
              >
                {z.label}
              </text>
            </g>
          ))}

          {/* Curved roads */}
          <g stroke="rgba(255,255,255,0.15)" strokeWidth="10" fill="none" strokeLinecap="round" opacity="0.5">
            <path d="M 60 540 Q 200 500, 350 470 T 690 470" />
            <path d="M 350 470 Q 380 380, 390 300 T 480 180" />
            <path d="M 210 180 Q 300 240, 300 280 T 480 300" />
            <path d="M 560 180 Q 620 220, 680 230 T 720 340" />
            <path d="M 130 470 Q 100 400, 110 320 T 170 260" />
          </g>
          <g stroke="#00E5FF" strokeOpacity="0.35" strokeWidth="1.5" fill="none" strokeDasharray="4 8" strokeLinecap="round">
            <path d="M 60 540 Q 200 500, 350 470 T 690 470" />
            <path d="M 350 470 Q 380 380, 390 300 T 480 180" />
            <path d="M 210 180 Q 300 240, 300 280 T 480 300" />
            <path d="M 560 180 Q 620 220, 680 230 T 720 340" />
            <path d="M 130 470 Q 100 400, 110 320 T 170 260" />
          </g>

          {/* Lake */}
          <g>
            <ellipse cx={LAKE.cx} cy={LAKE.cy} rx={LAKE.rx} ry={LAKE.ry} fill="url(#lake)" />
            <ellipse cx={LAKE.cx} cy={LAKE.cy} rx={LAKE.rx} ry={LAKE.ry} fill="none" stroke="#00E5FF" strokeOpacity="0.5" strokeWidth="1" />
            <ellipse cx={LAKE.cx - 8} cy={LAKE.cy - 4} rx={LAKE.rx * 0.55} ry={LAKE.ry * 0.5} fill="none" stroke="#00E5FF" strokeOpacity="0.35" strokeWidth="1" />
            <text x={LAKE.cx} y={LAKE.cy + 4} textAnchor="middle" fill="#00E5FF" fillOpacity="0.7" fontSize="8" fontWeight="700" letterSpacing="1.5" fontFamily="Manrope, sans-serif">
              CAMPUS LAKE
            </text>
          </g>

          {/* Trees */}
          {TREES.map(([x, y], i) => (
            <g key={i} transform={`translate(${x} ${y})`}>
              <circle r="6" fill="#0F2417" stroke="#39FF14" strokeOpacity="0.4" strokeWidth="1" />
              <circle r="3" fill="#39FF14" fillOpacity="0.35" />
            </g>
          ))}

          {/* Buildings (per location) */}
          {locations.map((loc) => {
            const color = typeColor[loc.type] || "#00E5FF";
            const isBig = ["academic", "residence"].includes(loc.type);
            const w = isBig ? 62 : 44;
            const h = isBig ? 44 : 32;
            return (
              <g key={`b-${loc.id}`} transform={`translate(${loc.x} ${loc.y})`}>
                {/* Base shadow */}
                <ellipse cx="0" cy={h / 2 + 6} rx={w / 2} ry="4" fill="rgba(0,0,0,0.5)" />
                {/* Building body */}
                <rect
                  x={-w / 2}
                  y={-h / 2}
                  width={w}
                  height={h}
                  rx="8"
                  fill="url(#bldg)"
                  stroke={color}
                  strokeOpacity="0.6"
                  strokeWidth="1.5"
                />
                {/* Roof accent */}
                <rect x={-w / 2 + 4} y={-h / 2 + 3} width={w - 8} height="3" rx="1.5" fill={color} fillOpacity="0.5" />
                {/* Windows grid */}
                {[0, 1, 2].map((row) =>
                  [0, 1, 2, 3].slice(0, isBig ? 4 : 3).map((col) => (
                    <rect
                      key={`${row}-${col}`}
                      x={-w / 2 + 8 + col * ((w - 20) / (isBig ? 3 : 2))}
                      y={-h / 2 + 12 + row * 8}
                      width="4"
                      height="5"
                      rx="1"
                      fill={color}
                      fillOpacity={(row + col) % 2 === 0 ? "0.6" : "0.2"}
                    />
                  ))
                )}
              </g>
            );
          })}

          {/* Quest pins */}
          {locations.map((loc) => {
            const hasQuest = (questsByLoc[loc.id] || []).some((q) => !q.completed);
            const color = typeColor[loc.type] || "#00E5FF";
            return (
              <g
                key={loc.id}
                transform={`translate(${loc.x} ${loc.y - 34})`}
                style={{ cursor: hasQuest ? "pointer" : "default" }}
                onClick={() => hasQuest && openQuestForLocation(loc.id)}
                data-testid={`map-pin-${loc.id}`}
              >
                {/* Invisible bigger hit target */}
                <circle r="26" fill="transparent" pointerEvents="all" />
                {hasQuest && (
                  <>
                    <circle
                      r="18"
                      fill={color}
                      fillOpacity="0.35"
                      className="pulse-ring"
                      style={{ transformOrigin: "center" }}
                      pointerEvents="none"
                    />
                    {/* Pin base drop */}
                    <path
                      d="M 0 -14 Q -9 -14 -9 -6 Q -9 2 0 12 Q 9 2 9 -6 Q 9 -14 0 -14 Z"
                      fill={color}
                      pointerEvents="none"
                      filter="url(#glow)"
                    />
                    <circle cx="0" cy="-6" r="3" fill="#050505" pointerEvents="none" />
                  </>
                )}
                {!hasQuest && (
                  <>
                    <circle r="7" fill={color} fillOpacity="0.35" pointerEvents="none" />
                    <circle r="4" fill={color} pointerEvents="none" />
                  </>
                )}
              </g>
            );
          })}

          {/* Location name labels */}
          {locations.map((loc) => (
            <text
              key={`t-${loc.id}`}
              x={loc.x}
              y={loc.y + (["academic", "residence"].includes(loc.type) ? 34 : 28)}
              textAnchor="middle"
              fill="#ffffff"
              fillOpacity="0.75"
              fontSize="8.5"
              fontWeight="700"
              letterSpacing="0.4"
              fontFamily="Manrope, sans-serif"
              pointerEvents="none"
            >
              {loc.name.length > 22 ? loc.name.slice(0, 21) + "…" : loc.name}
            </text>
          ))}

          {/* Compass rose */}
          <g transform="translate(750 70)">
            <circle r="24" fill="#0F0F13" stroke="rgba(255,255,255,0.15)" strokeWidth="1" />
            <path d="M 0 -16 L 4 0 L 0 16 L -4 0 Z" fill="#00E5FF" fillOpacity="0.8" />
            <path d="M -16 0 L 0 4 L 16 0 L 0 -4 Z" fill="rgba(255,255,255,0.2)" />
            <text y="-28" textAnchor="middle" fill="#00E5FF" fontSize="9" fontWeight="900" fontFamily="Unbounded, sans-serif">N</text>
          </g>

          {/* Scale indicator */}
          <g transform="translate(40 590)">
            <line x1="0" y1="0" x2="80" y2="0" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5" />
            <line x1="0" y1="-4" x2="0" y2="4" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5" />
            <line x1="80" y1="-4" x2="80" y2="4" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5" />
            <text x="40" y="-8" textAnchor="middle" fill="rgba(255,255,255,0.55)" fontSize="9" fontWeight="700" letterSpacing="1" fontFamily="Manrope, sans-serif">
              100 M
            </text>
          </g>

          {/* Watermark */}
          <text
            x="400"
            y="605"
            textAnchor="middle"
            fill="rgba(255,255,255,0.15)"
            fontSize="10"
            fontWeight="900"
            letterSpacing="6"
            fontFamily="Unbounded, sans-serif"
          >
            VIT · BHOPAL
          </text>
        </svg>

        {/* Legend overlay */}
        <div className="absolute left-3 top-3 flex items-center gap-2 flex-wrap max-w-[70%]">
          <LegendChip color="#00E5FF" label="Academic" />
          <LegendChip color="#39FF14" label="Sports" />
          <LegendChip color="#FF8A3D" label="Food" />
          <LegendChip color="#C084FC" label="Event" />
          <LegendChip color="#94A3B8" label="Hostel" />
        </div>
      </motion.div>

      {/* Nearby quests list */}
      <div className="flex items-baseline justify-between mt-6">
        <h2 className="font-display text-lg font-bold tracking-tight">Nearby Quests</h2>
        <span className="text-[10px] uppercase tracking-[0.25em] text-white/40 font-semibold">
          Tap a pin or row
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
                <div className="text-[10px] text-white/40 truncate">
                  {typeLabel[loc.type] || loc.type} · {active[0].title}
                </div>
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
    <span
      className="h-2 w-2 rounded-full"
      style={{ background: color, boxShadow: `0 0 8px ${color}` }}
    />
    {label}
  </div>
);
