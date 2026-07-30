import React, { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Search, X, Navigation, MapPin, Compass, Plus, Minus,
  ArrowRight, Building2, LocateFixed,
} from "lucide-react";
import {
  BUILDINGS, BUILDINGS_BY_ID, CATEGORIES, MAP_VIEWBOX,
  MAIN_ENTRY, ROADS, TREES,
} from "../data/campusMap";

// -----------------------------------------------------------------------------
// Helper — build an SVG points string for the route polyline
// -----------------------------------------------------------------------------
const pointsFromRoute = (pts) => pts.map((p) => `${p.x},${p.y}`).join(" ");

// -----------------------------------------------------------------------------
// Main screen
// -----------------------------------------------------------------------------
export default function MapPage() {
  const [selected, setSelected] = useState(null);
  const [destination, setDestination] = useState(null);
  const [query, setQuery] = useState("");
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });

  const filtered = useMemo(() => {
    if (!query.trim()) return [];
    const q = query.trim().toLowerCase();
    return BUILDINGS.filter(
      (b) => b.name.toLowerCase().includes(q) || b.full.toLowerCase().includes(q)
    ).slice(0, 6);
  }, [query]);

  const route = destination ? BUILDINGS_BY_ID[destination]?.route : null;

  const centerOn = (b) => {
    if (!b) return;
    const cx = b.x !== undefined ? b.x + (b.w || 60) / 2 : b.labelX ?? MAP_VIEWBOX.w / 2;
    const cy = b.y !== undefined ? b.y + (b.h || 60) / 2 : b.labelY ?? MAP_VIEWBOX.h / 2;
    setZoom(1.6);
    // Convert into pan offset (SVG uses viewBox, so we translate the wrapper).
    // The wrapper is transformed via CSS: translate(pan)% then scale(zoom).
    setPan({
      x: 50 - (cx / MAP_VIEWBOX.w) * 100,
      y: 50 - (cy / MAP_VIEWBOX.h) * 100,
    });
  };

  const handlePick = (b) => {
    setSelected(b);
    setQuery("");
    centerOn(b);
  };

  const startDirections = (b) => {
    setDestination(b.id);
    setSelected(null);
    centerOn(b);
  };

  const resetView = () => {
    setZoom(1);
    setPan({ x: 0, y: 0 });
    setDestination(null);
    setSelected(null);
  };

  return (
    <div className="relative min-h-screen w-full bg-[#FBF7F0]" data-testid="campus-nav-map">
      {/* Search bar */}
      <div className="absolute top-4 inset-x-4 z-30">
        <div
          className="bg-white rounded-2xl shadow-[0_10px_30px_rgba(31,42,68,0.18)] border border-black/5 flex items-center px-3 h-11"
          data-testid="map-search"
        >
          <Search size={16} className="text-[#1F2A44]/60" />
          <input
            data-testid="map-search-input"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search buildings (e.g. A.B. 1, Mayuri, Cricket)"
            className="flex-1 bg-transparent outline-none px-2 text-sm text-[#1F2A44] placeholder:text-[#1F2A44]/40 font-medium"
          />
          {query && (
            <button
              onClick={() => setQuery("")}
              className="p-1 rounded-full hover:bg-black/5"
              aria-label="Clear search"
            >
              <X size={14} className="text-[#1F2A44]/60" />
            </button>
          )}
        </div>
        {filtered.length > 0 && (
          <div
            data-testid="search-results"
            className="mt-1 bg-white rounded-2xl shadow-[0_10px_30px_rgba(31,42,68,0.15)] border border-black/5 overflow-hidden"
          >
            {filtered.map((b) => (
              <button
                key={b.id}
                data-testid={`search-result-${b.id}`}
                onClick={() => handlePick(b)}
                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-black/[0.03] text-left"
              >
                <span
                  className="h-8 w-8 rounded-lg flex items-center justify-center border"
                  style={{
                    background: CATEGORIES[b.category].color,
                    borderColor: CATEGORIES[b.category].stroke + "55",
                  }}
                >
                  <Building2 size={14} className="text-[#1F2A44]" />
                </span>
                <div className="flex-1 min-w-0">
                  <div className="text-[13px] font-bold text-[#1F2A44] truncate">{b.name}</div>
                  <div className="text-[11px] text-[#1F2A44]/50 truncate">
                    {CATEGORIES[b.category].label} · {b.full}
                  </div>
                </div>
                <ArrowRight size={14} className="text-[#1F2A44]/40" />
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Zoom / reset controls */}
      <div className="absolute right-4 top-24 z-20 flex flex-col gap-2">
        <ControlBtn onClick={() => setZoom((z) => Math.min(2.5, z + 0.25))} testid="zoom-in">
          <Plus size={16} />
        </ControlBtn>
        <ControlBtn onClick={() => setZoom((z) => Math.max(1, z - 0.25))} testid="zoom-out">
          <Minus size={16} />
        </ControlBtn>
        <ControlBtn onClick={resetView} testid="reset-view">
          <LocateFixed size={16} />
        </ControlBtn>
      </div>

      {/* Legend */}
      <MapLegend />

      {/* SVG map area */}
      <div className="absolute inset-0 top-0 bg-[#FBF7F0] overflow-hidden">
        <div
          className="w-full h-full"
          style={{
            transform: `translate(${pan.x}%, ${pan.y}%) scale(${zoom})`,
            transformOrigin: "50% 50%",
            transition: "transform 0.5s cubic-bezier(0.22, 1, 0.36, 1)",
          }}
        >
          <CampusSVG
            selected={selected}
            destination={destination}
            route={route}
            onBuildingTap={handlePick}
          />
        </div>
      </div>

      {/* Bottom sheet */}
      <AnimatePresence>
        {selected && (
          <BuildingSheet
            building={selected}
            onClose={() => setSelected(null)}
            onDirections={() => startDirections(selected)}
          />
        )}
        {!selected && destination && (
          <DirectionsSheet
            building={BUILDINGS_BY_ID[destination]}
            onClose={() => setDestination(null)}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

// -----------------------------------------------------------------------------
// SVG map
// -----------------------------------------------------------------------------
const CampusSVG = ({ selected, destination, route, onBuildingTap }) => {
  return (
    <svg
      viewBox={`0 0 ${MAP_VIEWBOX.w} ${MAP_VIEWBOX.h}`}
      className="w-full h-full block"
      preserveAspectRatio="xMidYMid meet"
    >
      <defs>
        <pattern id="paper" width="240" height="240" patternUnits="userSpaceOnUse">
          <rect width="240" height="240" fill="#FBF7F0" />
          <circle cx="30" cy="60" r="0.6" fill="rgba(31,42,68,0.05)" />
          <circle cx="120" cy="130" r="0.6" fill="rgba(31,42,68,0.04)" />
          <circle cx="200" cy="200" r="0.6" fill="rgba(31,42,68,0.05)" />
        </pattern>
        <linearGradient id="cricketGrass" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#B8D992" />
          <stop offset="100%" stopColor="#9EC474" />
        </linearGradient>
        <linearGradient id="porcellGrass" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#C7E4A4" />
          <stop offset="100%" stopColor="#AAD07F" />
        </linearGradient>
        <filter id="softShadow" x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="3" />
        </filter>
      </defs>

      {/* Paper base */}
      <rect width={MAP_VIEWBOX.w} height={MAP_VIEWBOX.h} fill="url(#paper)" />

      {/* Roads — outer stroke */}
      <g fill="none" strokeLinecap="round" strokeLinejoin="round">
        {ROADS.map((r, i) => (
          <path key={`ro-${i}`} d={r.d} stroke="#BFBFBF" strokeWidth={r.w} />
        ))}
        {ROADS.map((r, i) => (
          <path key={`ri-${i}`} d={r.d} stroke="#E8E8E8" strokeWidth={r.w - 12} />
        ))}
        {/* Dashed centreline */}
        {ROADS.map((r, i) => (
          <path
            key={`rc-${i}`}
            d={r.d}
            stroke="#FFFFFF"
            strokeWidth="2"
            strokeDasharray="10 12"
          />
        ))}
      </g>

      {/* Route polyline (drawn above the roads but below the buildings) */}
      {route && (
        <g>
          <polyline
            points={pointsFromRoute(route)}
            fill="none"
            stroke="#1A73E8"
            strokeOpacity="0.25"
            strokeWidth="14"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <polyline
            points={pointsFromRoute(route)}
            fill="none"
            stroke="#1A73E8"
            strokeWidth="6"
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeDasharray="14 10"
            data-testid="route-polyline"
          >
            <animate
              attributeName="stroke-dashoffset"
              from="0"
              to="-72"
              dur="1.4s"
              repeatCount="indefinite"
            />
          </polyline>
        </g>
      )}

      {/* Green ground shapes for sports/open zones (rendered before rectangles) */}
      {BUILDINGS.filter((b) => b.category === "sports" && b.shape === "blob").map((b) => (
        <g key={`grass-${b.id}`}>
          <path d={b.d} fill="url(#porcellGrass)" stroke="#7BAF52" strokeWidth="2" />
        </g>
      ))}

      {/* Trees */}
      {TREES.map(([x, y], i) => (
        <g key={`t-${i}`} transform={`translate(${x} ${y})`}>
          <ellipse cx="0" cy="4" rx="8" ry="3" fill="rgba(0,0,0,0.08)" />
          <circle cx="0" cy="0" r="7" fill="#7BAF52" />
          <circle cx="-2" cy="-2" r="4" fill="#96C46A" />
        </g>
      ))}

      {/* Buildings */}
      {BUILDINGS.map((b) => (
        <BuildingNode
          key={b.id}
          b={b}
          selected={selected?.id === b.id || destination === b.id}
          onTap={() => onBuildingTap(b)}
        />
      ))}

      {/* Main entry marker */}
      <g transform={`translate(${MAIN_ENTRY.x + 30} ${MAIN_ENTRY.y - 25})`}>
        <rect x="-40" y="-14" width="80" height="20" rx="10" fill="#FFFFFF" stroke="#1F2A44" strokeWidth="1" />
        <text textAnchor="middle" y="0" fill="#1F2A44" fontSize="11" fontWeight="800" letterSpacing="0.5" fontFamily="Manrope, sans-serif">
          Main entry
        </text>
      </g>

      {/* Highway label */}
      <text x="440" y="90" fill="#1F2A44" fillOpacity="0.6" fontSize="16" fontWeight="700" letterSpacing="1" fontFamily="Manrope, sans-serif">
        Highway
      </text>

      {/* Title band */}
      <g>
        <text
          x={MAP_VIEWBOX.w / 2}
          y="42"
          textAnchor="middle"
          fill="#1F2A44"
          fillOpacity="0.15"
          fontSize="30"
          fontWeight="900"
          letterSpacing="8"
          fontFamily="Unbounded, sans-serif"
        >
          VIT BHOPAL
        </text>
      </g>

      {/* Compass */}
      <g transform="translate(80 940)">
        <circle r="28" fill="#FFFFFF" stroke="#1F2A44" strokeOpacity="0.25" strokeWidth="1.5" />
        <path d="M 0 -20 L 5 0 L 0 20 L -5 0 Z" fill="#1F2A44" />
        <path d="M -18 0 L 0 4 L 18 0 L 0 -4 Z" fill="#1F2A44" fillOpacity="0.25" />
        <text y="-34" textAnchor="middle" fill="#1F2A44" fontSize="14" fontWeight="900" fontFamily="Unbounded, sans-serif">N</text>
      </g>
    </svg>
  );
};

// -----------------------------------------------------------------------------
// Building rendered on the SVG
// -----------------------------------------------------------------------------
const BuildingNode = ({ b, selected, onTap }) => {
  const cat = CATEGORIES[b.category];
  const strokeW = selected ? 3.5 : 1.6;
  const strokeCol = selected ? "#1A73E8" : cat.stroke;

  if (b.shape === "blob") {
    return (
      <g
        onClick={onTap}
        style={{ cursor: "pointer" }}
        data-testid={`building-${b.id}`}
      >
        <path d={b.d} fill={cat.color} stroke={strokeCol} strokeWidth={strokeW} />
        <text
          x={b.labelX}
          y={b.labelY}
          textAnchor="middle"
          fill="#1F2A44"
          fontSize={b.labelSize}
          fontWeight="800"
          fontFamily="Manrope, sans-serif"
        >
          {b.name}
        </text>
      </g>
    );
  }

  const cx = b.x + b.w / 2;
  const cy = b.y + b.h / 2;
  const lines = b.full.split(/\s(?=Ground|VIT|·|Block)/).length > 1
    ? [b.name.split(" ")[0], b.name.split(" ").slice(1).join(" ")]
    : b.name.split(" ").length > 2
    ? [b.name.split(" ").slice(0, 2).join(" "), b.name.split(" ").slice(2).join(" ")]
    : [b.name];

  return (
    <g
      onClick={onTap}
      style={{ cursor: "pointer" }}
      data-testid={`building-${b.id}`}
    >
      {/* Soft ground shadow */}
      <rect
        x={b.x + 3}
        y={b.y + 5}
        width={b.w}
        height={b.h}
        rx={b.rounded ?? 8}
        fill="rgba(0,0,0,0.10)"
        filter="url(#softShadow)"
      />
      <rect
        x={b.x}
        y={b.y}
        width={b.w}
        height={b.h}
        rx={b.rounded ?? 8}
        fill={cat.color}
        stroke={strokeCol}
        strokeWidth={strokeW}
      />
      {b.extras === "cricket" && (
        <g>
          {/* Cricket pitch strip */}
          <rect
            x={b.x + b.w * 0.62}
            y={b.y + b.h * 0.30}
            width={b.w * 0.18}
            height={b.h * 0.42}
            fill="#F1D9A6"
            stroke="#B39160"
            strokeWidth="1"
            strokeDasharray="4 4"
          />
        </g>
      )}
      {/* Multi-line label */}
      {lines.map((ln, i) => (
        <text
          key={i}
          x={cx}
          y={cy - (lines.length - 1) * (b.labelSize / 2) + i * (b.labelSize + 2)}
          textAnchor="middle"
          dominantBaseline="middle"
          fill="#1F2A44"
          fontSize={b.labelSize}
          fontWeight="800"
          fontFamily="Manrope, sans-serif"
        >
          {ln}
        </text>
      ))}
    </g>
  );
};

// -----------------------------------------------------------------------------
// Legend (top-left overlay, collapsible on small screens)
// -----------------------------------------------------------------------------
const MapLegend = () => {
  const [open, setOpen] = useState(false);
  return (
    <div className="absolute left-4 top-24 z-20">
      <button
        onClick={() => setOpen((v) => !v)}
        data-testid="legend-toggle"
        className="bg-white rounded-2xl shadow-[0_10px_30px_rgba(31,42,68,0.15)] border border-black/5 h-10 px-3 flex items-center gap-2 text-[11px] font-bold uppercase tracking-widest text-[#1F2A44]"
      >
        <Compass size={14} /> Legend
      </button>
      <AnimatePresence>
        {open && (
          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            className="mt-2 bg-white rounded-2xl shadow-[0_10px_30px_rgba(31,42,68,0.15)] border border-black/5 p-3 space-y-1.5 w-56"
          >
            {Object.entries(CATEGORIES).map(([k, v]) => (
              <div key={k} className="flex items-center gap-2">
                <span
                  className="h-4 w-6 rounded border"
                  style={{ background: v.color, borderColor: v.stroke + "88" }}
                />
                <span className="text-[12px] text-[#1F2A44] font-semibold">{v.label}</span>
              </div>
            ))}
            <div className="flex items-center gap-2 pt-1">
              <span className="h-1.5 w-6 rounded-full bg-[#BFBFBF] relative">
                <span className="absolute inset-0 flex items-center">
                  <span className="mx-auto h-[2px] w-4 bg-white" />
                </span>
              </span>
              <span className="text-[12px] text-[#1F2A44] font-semibold">Roads</span>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};

// -----------------------------------------------------------------------------
// Zoom / reset button
// -----------------------------------------------------------------------------
const ControlBtn = ({ onClick, children, testid }) => (
  <button
    onClick={onClick}
    data-testid={testid}
    className="h-10 w-10 rounded-full bg-white shadow-[0_10px_30px_rgba(31,42,68,0.15)] border border-black/5 flex items-center justify-center text-[#1F2A44] hover:bg-[#F2EEE6]"
  >
    {children}
  </button>
);

// -----------------------------------------------------------------------------
// Bottom sheets
// -----------------------------------------------------------------------------
const sheetMotion = {
  initial: { y: 200, opacity: 0 },
  animate: { y: 0, opacity: 1 },
  exit: { y: 200, opacity: 0 },
  transition: { type: "spring", stiffness: 320, damping: 32 },
};

const BuildingSheet = ({ building, onClose, onDirections }) => {
  const cat = CATEGORIES[building.category];
  return (
    <motion.div
      {...sheetMotion}
      data-testid="building-sheet"
      className="fixed bottom-24 inset-x-4 z-40 max-w-md mx-auto bg-white rounded-3xl shadow-[0_20px_50px_rgba(31,42,68,0.25)] border border-black/5 overflow-hidden"
    >
      <div className="p-5">
        <div className="flex items-start gap-3">
          <div
            className="h-11 w-11 rounded-xl flex items-center justify-center border"
            style={{ background: cat.color, borderColor: cat.stroke + "55" }}
          >
            <Building2 size={18} className="text-[#1F2A44]" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-[10px] uppercase tracking-widest font-bold text-[#1F2A44]/50">
              {cat.label}
            </div>
            <h3 className="font-display text-lg font-black text-[#1F2A44] tracking-tight leading-tight">
              {building.full}
            </h3>
            <div className="text-[12px] text-[#1F2A44]/60 mt-0.5">Short code · {building.name}</div>
          </div>
          <button
            onClick={onClose}
            data-testid="close-sheet"
            className="h-8 w-8 rounded-full hover:bg-black/5 flex items-center justify-center"
            aria-label="Close"
          >
            <X size={16} className="text-[#1F2A44]/60" />
          </button>
        </div>
        <div className="flex items-center gap-2 mt-4">
          <button
            data-testid="get-directions-btn"
            onClick={onDirections}
            className="flex-1 h-11 rounded-full bg-[#1A73E8] text-white font-bold text-sm hover:bg-[#1667D0] active:scale-[0.98] transition-[background-color,transform] flex items-center justify-center gap-2"
          >
            <Navigation size={16} /> Directions from Main Entry
          </button>
        </div>
      </div>
    </motion.div>
  );
};

const DirectionsSheet = ({ building, onClose }) => {
  const cat = CATEGORIES[building.category];
  const legs = building.route.length - 1;
  return (
    <motion.div
      {...sheetMotion}
      data-testid="directions-sheet"
      className="fixed bottom-24 inset-x-4 z-40 max-w-md mx-auto bg-white rounded-3xl shadow-[0_20px_50px_rgba(31,42,68,0.25)] border border-black/5 overflow-hidden"
    >
      <div className="p-5">
        <div className="flex items-start gap-3">
          <div className="h-11 w-11 rounded-xl bg-[#1A73E8]/10 border border-[#1A73E8]/30 flex items-center justify-center">
            <Navigation size={18} className="text-[#1A73E8]" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-[10px] uppercase tracking-widest font-bold text-[#1F2A44]/50">
              Route
            </div>
            <h3 className="font-display text-lg font-black text-[#1F2A44] tracking-tight leading-tight">
              To {building.full}
            </h3>
            <div className="text-[12px] text-[#1F2A44]/60 mt-0.5">
              {legs} leg{legs > 1 ? "s" : ""} along campus roads
            </div>
          </div>
          <button
            onClick={onClose}
            data-testid="close-directions"
            className="h-8 w-8 rounded-full hover:bg-black/5 flex items-center justify-center"
            aria-label="Close"
          >
            <X size={16} className="text-[#1F2A44]/60" />
          </button>
        </div>

        <div className="mt-4 space-y-2">
          <RouteStep
            iconBg="#1F2A44"
            title="Start · Main Entry"
            subtitle="You are here"
            dot="start"
          />
          <RouteStep
            iconBg={cat.stroke}
            title={`End · ${building.full}`}
            subtitle={cat.label}
            dot="end"
          />
        </div>
      </div>
    </motion.div>
  );
};

const RouteStep = ({ title, subtitle, iconBg, dot }) => (
  <div className="flex items-center gap-3">
    <div className="relative flex flex-col items-center">
      <span
        className="h-3 w-3 rounded-full border-2 border-white"
        style={{ background: iconBg, boxShadow: `0 0 0 2px ${iconBg}` }}
      />
      {dot === "start" && (
        <span className="h-6 border-l-2 border-dashed border-[#1F2A44]/25 mt-1" />
      )}
    </div>
    <div className="flex-1 min-w-0">
      <div className="text-[13px] font-bold text-[#1F2A44] truncate">{title}</div>
      <div className="text-[11px] text-[#1F2A44]/55 truncate">{subtitle}</div>
    </div>
    <MapPin size={14} className="text-[#1F2A44]/40" />
  </div>
);
