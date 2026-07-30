import React from "react";
import Profile from "@/pages/Profile";
import Leaderboard from "@/pages/Leaderboard";

/**
 * Merged Profile tab: keeps the EXACT existing Profile (avatar + identity +
 * badges + gallery + community feed) up top, then a visually distinct
 * gamification stats row, then the EXACT existing Leaderboard below it.
 */
export default function ProfileMerged() {
  return (
    <div data-testid="profile-tab">
      <Profile />

      {/* Highlighted gamification stats row (mock values per spec) */}
      <div className="px-6 pt-2 pb-6">
        <div className="rounded-3xl p-4 bg-[#0F0F13] border border-white/6">
          <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-bold">
            Season Stats
          </div>
          <div className="mt-3 grid grid-cols-3 gap-2">
            <StatChip icon="⭐" value="1250" label="XP" tint="#39FF14" />
            <StatChip icon="🏅" value="Lv 5" label="Level" tint="#00E5FF" />
            <StatChip icon="🔥" value="14" label="Day Streak" tint="#FF8A3D" />
          </div>
        </div>
      </div>

      <div className="-mt-6">
        <Leaderboard />
      </div>
    </div>
  );
}

const StatChip = ({ icon, value, label, tint }) => (
  <div
    className="rounded-2xl p-3 border flex flex-col items-center text-center"
    style={{
      background: `${tint}0F`,
      borderColor: `${tint}55`,
      boxShadow: `0 0 22px ${tint}22`,
    }}
  >
    <div className="text-lg leading-none">{icon}</div>
    <div
      className="font-display font-black text-xl mt-1"
      style={{ color: tint, textShadow: `0 0 10px ${tint}66` }}
    >
      {value}
    </div>
    <div className="text-[9px] uppercase tracking-widest text-white/50 font-bold mt-0.5">
      {label}
    </div>
  </div>
);
