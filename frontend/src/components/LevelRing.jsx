import React from "react";

/**
 * Circular XP progress ring.
 * xp: current XP total
 * level: current level
 * next_level_xp / current_level_xp determined by simple curve on frontend for display.
 */
export const LevelRing = ({ xp = 0, level = 1, size = 148, stroke = 10 }) => {
  // level = 1 + floor(sqrt(xp/100))
  const currentLevelXp = Math.pow(level - 1, 2) * 100;
  const nextLevelXp = Math.pow(level, 2) * 100;
  const span = nextLevelXp - currentLevelXp;
  const progress = Math.min(1, Math.max(0, (xp - currentLevelXp) / span));

  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - progress);

  return (
    <div className="relative" style={{ width: size, height: size }} data-testid="level-ring">
      <svg width={size} height={size} className="-rotate-90">
        <defs>
          <linearGradient id="ringGrad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#00E5FF" />
            <stop offset="100%" stopColor="#39FF14" />
          </linearGradient>
        </defs>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke="rgba(255,255,255,0.08)"
          strokeWidth={stroke}
          fill="none"
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          stroke="url(#ringGrad)"
          strokeWidth={stroke}
          strokeLinecap="round"
          fill="none"
          strokeDasharray={c}
          strokeDashoffset={offset}
          style={{ transition: "stroke-dashoffset 0.6s ease" }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">
          Level
        </span>
        <span className="font-display text-4xl font-black text-white" data-testid="level-value">
          {level}
        </span>
        <span className="text-[11px] text-[#00E5FF] font-semibold mt-0.5">
          {xp.toLocaleString()} XP
        </span>
      </div>
    </div>
  );
};
