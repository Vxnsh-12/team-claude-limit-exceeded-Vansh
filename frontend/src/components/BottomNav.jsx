import React from "react";
import { NavLink, useLocation } from "react-router-dom";
import { motion } from "framer-motion";
import { Home, Map as MapIcon, Trophy, User } from "lucide-react";

const items = [
  { to: "/", label: "Home", icon: Home, testid: "nav-home" },
  { to: "/map", label: "Map", icon: MapIcon, testid: "nav-map" },
  { to: "/leaderboard", label: "Leaderboard", icon: Trophy, testid: "nav-leaderboard" },
  { to: "/profile", label: "Profile", icon: User, testid: "nav-profile" },
];

export const BottomNav = () => {
  const location = useLocation();
  return (
    <nav
      data-testid="bottom-nav"
      className="fixed bottom-5 left-1/2 -translate-x-1/2 w-[calc(100%-2rem)] max-w-md z-50"
    >
      <div className="glass rounded-full h-16 flex items-center justify-around px-2 shadow-[0_20px_50px_rgba(0,0,0,0.55)]">
        {items.map((it) => {
          const Icon = it.icon;
          const active = location.pathname === it.to;
          return (
            <NavLink
              key={it.to}
              to={it.to}
              data-testid={it.testid}
              className="relative flex-1 flex items-center justify-center h-12 rounded-full"
            >
              {active && (
                <motion.div
                  layoutId="active-nav-pill"
                  className="absolute inset-1 rounded-full bg-[#00E5FF]/12 border border-[#00E5FF]/40"
                  transition={{ type: "spring", stiffness: 380, damping: 30 }}
                />
              )}
              <div className="relative flex flex-col items-center gap-0.5">
                <Icon
                  size={22}
                  strokeWidth={2.4}
                  className={active ? "text-[#00E5FF]" : "text-white/60"}
                  style={active ? { filter: "drop-shadow(0 0 6px rgba(0,229,255,0.7))" } : undefined}
                />
                <span
                  className={`text-[10px] font-semibold tracking-wide ${
                    active ? "text-[#00E5FF]" : "text-white/50"
                  }`}
                >
                  {it.label}
                </span>
              </div>
            </NavLink>
          );
        })}
      </div>
    </nav>
  );
};
