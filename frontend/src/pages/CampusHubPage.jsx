import React, { useEffect, useRef, useState } from "react";
import { UploadCloud, Loader2, MapPin, Clock, User, AlertTriangle, X } from "lucide-react";
import { toast } from "sonner";
import Dashboard from "@/pages/Dashboard";

export default function CampusHubPage() {
  const [syncing, setSyncing] = useState(false);
  const [alertOpen, setAlertOpen] = useState(false);
  const alertFiredRef = useRef(false);

  // Mock next-class time = mount + 15 min + 12 sec, so the alert fires ~12 s after entering the tab.
  const classStartRef = useRef(new Date(Date.now() + (15 * 60 + 12) * 1000));

  useEffect(() => {
    const timer = setInterval(() => {
      if (alertFiredRef.current) return;
      const minsUntil = (classStartRef.current.getTime() - Date.now()) / 60000;
      if (minsUntil <= 15 && minsUntil > 14.5) {
        alertFiredRef.current = true;
        setAlertOpen(true);
      }
    }, 5000);
    return () => clearInterval(timer);
  }, []);

  const handleSync = async () => {
    setSyncing(true);
    await new Promise((r) => setTimeout(r, 2000));
    setSyncing(false);
    toast("✅ VTOP Schedule Synced Successfully", {
      style: {
        background: "#0F0F13",
        border: "1px solid rgba(57,255,20,0.5)",
        color: "#fff",
        fontWeight: 700,
      },
    });
  };

  const classTimeStr = classStartRef.current.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });

  return (
    <div className="px-6 pt-8" data-testid="campus-hub-page">
      {/* Schedule card */}
      <div
        data-testid="schedule-card"
        className="rounded-3xl p-5 relative overflow-hidden"
        style={{
          background: "linear-gradient(135deg, #00E5FF 0%, #0891B2 100%)",
          boxShadow: "0 20px 40px rgba(0,229,255,0.25)",
        }}
      >
        <div className="flex items-center justify-between">
          <div className="text-[10px] font-black uppercase tracking-[0.3em] text-black/60">
            VTOP · Up Next
          </div>
          <div className="rounded-full bg-black/25 px-2.5 py-1 flex items-center gap-1 text-black">
            <Clock size={12} /> <span className="text-[11px] font-black">{classTimeStr}</span>
          </div>
        </div>
        <h2 className="font-display text-3xl font-black text-black tracking-tight mt-3">OS Lab</h2>
        <div className="mt-2 flex items-center gap-3 text-black/80 text-xs font-bold">
          <div className="flex items-center gap-1"><MapPin size={12} /> AB-1 · Room 304</div>
          <div className="flex items-center gap-1"><User size={12} /> Prof. Menon</div>
        </div>
        <button
          type="button"
          data-testid="sync-vtop"
          onClick={handleSync}
          disabled={syncing}
          className="mt-4 w-full h-11 rounded-full bg-black/85 text-white font-bold text-sm flex items-center justify-center gap-2 hover:bg-black transition-colors active:scale-[0.98] disabled:opacity-70"
        >
          {syncing ? <Loader2 size={16} className="animate-spin" /> : <UploadCloud size={16} />}
          {syncing ? "Syncing VTOP…" : "Upload VTOP Timetable"}
        </button>
      </div>

      {/* Existing Quests + Community feed via Dashboard */}
      <div className="mt-2 -mx-6">
        <Dashboard />
      </div>

      {alertOpen && (
        <div
          data-testid="class-alert-modal"
          className="fixed inset-0 z-[70] bg-black/70 backdrop-blur-sm flex items-center justify-center px-6"
        >
          <div className="w-full max-w-sm rounded-3xl bg-[#0F0F13] border border-[#F59E0B]/40 p-5 shadow-[0_20px_60px_rgba(245,158,11,0.25)]">
            <div className="flex items-center gap-3">
              <div className="h-11 w-11 rounded-2xl bg-[#F59E0B]/15 border border-[#F59E0B]/40 flex items-center justify-center">
                <AlertTriangle size={20} className="text-[#F59E0B]" />
              </div>
              <div className="flex-1">
                <div className="text-[10px] uppercase tracking-widest text-white/50 font-bold">Smart Alert</div>
                <h3 className="font-display text-lg font-black text-white">Class starts in 15 mins!</h3>
              </div>
              <button
                onClick={() => setAlertOpen(false)}
                className="h-8 w-8 rounded-full hover:bg-white/10 flex items-center justify-center"
                aria-label="Dismiss"
              >
                <X size={16} className="text-white/70" />
              </button>
            </div>
            <p className="text-sm text-white/70 mt-3 leading-relaxed">
              <span className="font-bold text-white">OS Lab · AB-1 · Room 304.</span> Leave now to be on time —
              the walk from Central Mess is about 6 minutes.
            </p>
            <button
              data-testid="alert-dismiss"
              onClick={() => setAlertOpen(false)}
              className="mt-5 w-full h-11 rounded-full bg-[#F59E0B] text-black font-bold text-sm hover:shadow-[0_0_22px_rgba(245,158,11,0.55)] active:scale-[0.98]"
            >
              Got it
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
