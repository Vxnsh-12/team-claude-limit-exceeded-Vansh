import React from "react";
import { motion } from "framer-motion";
import { Map as MapIcon, Users, CalendarDays, Rocket, Trophy } from "lucide-react";

const items = [
  { key: "navigate",      label: "Navigate",     icon: MapIcon,      testid: "nav-navigate" },
  { key: "squad",         label: "Squad",        icon: Users,        testid: "nav-squad" },
  { key: "hub",           label: "Campus Hub",   icon: CalendarDays, testid: "nav-hub" },
  { key: "opportunities", label: "Opportunities",icon: Rocket,       testid: "nav-opportunities" },
  { key: "profile",       label: "Profile",      icon: Trophy,       testid: "nav-profile" },
];

export const BottomNav = ({ active, onChange }) => {
  return (
    <nav
      data-testid="bottom-nav"
      className="fixed bottom-5 left-1/2 -translate-x-1/2 w-[calc(100%-2rem)] max-w-md z-50"
    >
      <div className="glass rounded-full h-16 flex items-center justify-around px-1 shadow-[0_20px_50px_rgba(0,0,0,0.55)]">
        {items.map((it) => {
          const Icon = it.icon;
          const isActive = active === it.key;
          return (
            <button
              key={it.key}
              type="button"
              data-testid={it.testid}
              onClick={() => onChange(it.key)}
              className="relative flex-1 flex items-center justify-center h-12 rounded-full"
            >
              {isActive && (
                <motion.div
                  layoutId="active-nav-pill"
                  className="absolute inset-1 rounded-full bg-[#00E5FF]/12 border border-[#00E5FF]/40"
                  transition={{ type: "spring", stiffness: 380, damping: 30 }}
                />
              )}
              <div className="relative flex flex-col items-center gap-0.5">
                <Icon
                  size={20}
                  strokeWidth={2.4}
                  className={isActive ? "text-[#00E5FF]" : "text-white/60"}
                  style={isActive ? { filter: "drop-shadow(0 0 6px rgba(0,229,255,0.7))" } : undefined}
                />
                <span
                  className={`text-[9px] font-semibold tracking-wide ${
                    isActive ? "text-[#00E5FF]" : "text-white/50"
                  }`}
                >
                  {it.label}
                </span>
              </div>
            </button>
          );
        })}
      </div>
    </nav>
  );
};

BottomNav.tabs = items;
