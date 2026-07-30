import React, { useState } from "react";
import { BottomNav } from "./BottomNav";
import MapPage from "@/pages/MapPage";
import SquadPage from "@/pages/SquadPage";
import CampusHubPage from "@/pages/CampusHubPage";
import OpportunitiesPage from "@/pages/OpportunitiesPage";
import ProfileMerged from "@/pages/ProfileMerged";

/**
 * State-based tab shell (React equivalent of Flutter's IndexedStack).
 * Every tab component stays mounted — inactive ones are hidden with
 * `hidden` attribute so the Map keeps its zoom / route / GPS state when
 * switching tabs and back.
 */
export const AppLayout = () => {
  const [active, setActive] = useState("hub");

  const tabs = [
    { key: "navigate",      Component: MapPage,          light: true },
    { key: "squad",         Component: SquadPage,        light: false },
    { key: "hub",           Component: CampusHubPage,    light: false },
    { key: "opportunities", Component: OpportunitiesPage,light: false },
    { key: "profile",       Component: ProfileMerged,    light: false },
  ];

  const isLight = tabs.find((t) => t.key === active)?.light;

  return (
    <div className={`min-h-screen w-full flex justify-center ${isLight ? "bg-[#FBF7F0]" : "bg-[#050505]"}`}>
      <div
        className={`relative w-full max-w-md min-h-screen ${
          isLight ? "bg-[#FBF7F0]" : "bg-[#050505] grid-bg"
        } text-white pb-28`}
      >
        {tabs.map(({ key, Component }) => (
          <div key={key} hidden={active !== key} className="min-h-screen">
            <Component />
          </div>
        ))}
        <BottomNav active={active} onChange={setActive} />
      </div>
    </div>
  );
};
