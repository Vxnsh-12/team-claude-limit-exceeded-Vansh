import React from "react";
import { Outlet } from "react-router-dom";
import { BottomNav } from "./BottomNav";

export const AppLayout = () => {
  return (
    <div className="min-h-screen w-full flex justify-center bg-[#050505]">
      <div className="relative w-full max-w-md min-h-screen bg-[#050505] text-white pb-28 grid-bg">
        <Outlet />
        <BottomNav />
      </div>
    </div>
  );
};
