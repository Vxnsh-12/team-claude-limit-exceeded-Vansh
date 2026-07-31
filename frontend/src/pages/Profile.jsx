import React, { useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";
import {
  Flame, Trophy, Sparkles, Zap, ShieldCheck, Compass, MapPin, LogOut,
  Camera, Globe, Lock, Loader2,
} from "lucide-react";
import { toast } from "sonner";
import { useAuth } from "../context/AuthContext";
import { api, resolveMediaUrl, formatApiErrorDetail } from "../lib/api";
import { LevelRing } from "../components/LevelRing";

const badgeDefs = {
  "first-quest": { label: "First Quest", icon: Sparkles, color: "#00E5FF" },
  "explorer":    { label: "Explorer",    icon: Compass,   color: "#39FF14" },
  "veteran":     { label: "Veteran",     icon: ShieldCheck, color: "#C084FC" },
  "fit-warrior": { label: "Fit Warrior", icon: Flame,     color: "#FF8A3D" },
};

export default function Profile() {
  // 1. ALL HOOKS AND THEIR DEPENDENCIES GO FIRST
  const { user: rawUser, logout, setUser, refreshUser } = useAuth();
  const [tab, setTab] = useState("mine"); // "mine" | "feed"
  const [mine, setMine] = useState([]);
  const [feed, setFeed] = useState([]);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const avatarInput = useRef(null);

  const loadMine = async () => {
    try {
      const { data } = await api.get("/uploads/mine");
      setMine(Array.isArray(data) ? data : []);
    } catch {}
  };
  
  const loadFeed = async () => {
    try {
      const { data } = await api.get("/feed");
      setFeed(Array.isArray(data) ? data : []);
    } catch {}
  };

  useEffect(() => {
    loadMine();
    loadFeed();
  }, []);

  // 2. EARLY RETURN GOES AFTER ALL HOOKS
  if (!rawUser) return null;

  // 3. SAFE TEMPLATES AND HANDLERS
  const safeUser = {
    name: "Student",
    xp: 0,
    level: 1,
    streak_days: 0,
    completed_quests: [],
    badges: [],
    createdAt: Date.now(),
    ...rawUser,
  };

  const safeMine = Array.isArray(mine) ? mine : [];
  const safeFeed = Array.isArray(feed) ? feed : [];

  const handleAvatarPick = async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    if (f.size > 20 * 1024 * 1024) {
      toast.error("Image too large — max 20 MB");
      return;
    }
    setUploadingAvatar(true);
    try {
      const fd = new FormData();
      fd.append("file", f);
      const { data } = await api.post("/uploads/avatar", fd, {
        headers: { "Content-Type": "multipart/form-data" },
      });
      setUser({ ...safeUser, avatar_url: data.avatar_url });
      await refreshUser();
      toast.success("Avatar updated");
      loadMine();
    } catch (err) {
      toast.error(formatApiErrorDetail(err.response?.data?.detail) || err.message);
    } finally {
      setUploadingAvatar(false);
      e.target.value = "";
    }
  };

  const toggleVisibility = async (upload) => {
    const next = !upload.is_public;
    try {
      const { data } = await api.put(`/uploads/${upload.id}/visibility?is_public=${next}`);
      setMine((prev) => (Array.isArray(prev) ? prev.map((u) => (u.id === upload.id ? data : u)) : []));
      toast.success(next ? "Shared to public feed" : "Set to private");
      loadFeed();
    } catch (e) {
      toast.error(formatApiErrorDetail(e.response?.data?.detail) || e.message);
    }
  };

  return (
    <div className="px-6 pt-8">
      <div className="flex items-center justify-between">
        <div>
          <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">Player</div>
          <h1 className="font-display text-2xl font-black tracking-tight mt-1">Profile</h1>
        </div>
        <button
          data-testid="profile-logout"
          onClick={logout}
          className="h-10 px-4 rounded-full bg-white/4 border border-white/8 flex items-center gap-2 text-[12px] font-semibold text-white/70 hover:border-red-400/40 transition-colors"
        >
          <LogOut size={14} /> Log out
        </button>
      </div>

      {/* Profile card */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.35 }}
        className="mt-6 rounded-3xl p-6 bg-[#0F0F13] border border-white/6 relative overflow-hidden"
      >
        <div className="absolute -right-16 -top-16 w-56 h-56 rounded-full bg-[#00E5FF]/8 blur-3xl pointer-events-none" />
        <div className="relative flex items-center gap-5">
          <div className="relative">
            <img
              src={resolveMediaUrl(safeUser.avatar_url)}
              alt={safeUser.name}
              className="h-24 w-24 rounded-full bg-[#1A1A24] object-cover ring-2 ring-[#00E5FF]/60"
              style={{ boxShadow: "0 0 30px rgba(0,229,255,0.35)" }}
            />
            <div className="absolute -bottom-1 -right-1 h-8 w-8 rounded-full bg-[#39FF14] text-black flex items-center justify-center font-display font-black text-xs">
              L{safeUser.level}
            </div>
            <button
              type="button"
              data-testid="avatar-upload-btn"
              disabled={uploadingAvatar}
              onClick={() => avatarInput.current?.click()}
              className="absolute -top-1 -right-1 h-8 w-8 rounded-full bg-[#00E5FF] text-black flex items-center justify-center hover:shadow-[0_0_18px_rgba(0,229,255,0.6)] transition-shadow active:scale-95"
              aria-label="Change avatar"
            >
              {uploadingAvatar ? <Loader2 size={14} className="animate-spin" /> : <Camera size={14} />}
            </button>
            <input
              ref={avatarInput}
              data-testid="avatar-input"
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleAvatarPick}
            />
          </div>
          <div className="flex-1 min-w-0">
            <h2 className="font-display text-2xl font-black tracking-tight truncate">
              {safeUser.name}
            </h2>
            <p className="text-xs text-white/50 truncate">{safeUser.email}</p>
            <div className="mt-3 flex items-center gap-2">
              <span className="glass rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider flex items-center gap-1">
                <MapPin size={10} className="text-[#00E5FF]" /> VIT Bhopal
              </span>
              <span className="glass rounded-full px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider flex items-center gap-1">
                <Flame size={10} className="text-[#FF8A3D]" /> {safeUser.streak_days}d streak
              </span>
            </div>
          </div>
        </div>

        {/* Level ring + XP */}
        <div className="mt-6 flex items-center gap-5">
          <LevelRing xp={safeUser.xp} level={safeUser.level} size={120} stroke={9} />
          <div className="flex-1 grid grid-cols-1 gap-2">
            <StatTile icon={Zap} tint="#39FF14" label="Total XP" value={safeUser.xp.toLocaleString()} />
            <StatTile icon={Trophy} tint="#00E5FF" label="Quests" value={safeUser.completed_quests.length} />
            <StatTile icon={Sparkles} tint="#C084FC" label="Badges" value={safeUser.badges.length} />
          </div>
        </div>
      </motion.div>

      {/* Badges */}
      <h3 className="font-display text-lg font-bold tracking-tight mt-8">Badges</h3>
      <div className="mt-3 grid grid-cols-4 gap-2">
        {Object.entries(badgeDefs).map(([key, def]) => {
          const owned = safeUser.badges.includes(key);
          const Icon = def.icon;
          return (
            <div
              key={key}
              data-testid={`badge-${key}`}
              className={`rounded-2xl p-3 flex flex-col items-center text-center border transition-colors ${
                owned ? "border-white/10 bg-[#0F0F13]" : "border-white/6 bg-white/[0.02] opacity-45"
              }`}
              style={owned ? { boxShadow: `0 0 22px ${def.color}22` } : undefined}
            >
              <div
                className="h-10 w-10 rounded-2xl flex items-center justify-center border"
                style={{
                  borderColor: `${def.color}${owned ? "55" : "22"}`,
                  background: `${def.color}${owned ? "18" : "08"}`,
                }}
              >
                <Icon size={18} strokeWidth={2.4} style={{ color: def.color }} />
              </div>
              <div className="text-[10px] font-bold mt-2 leading-tight">{def.label}</div>
            </div>
          );
        })}
      </div>

      {/* Gallery tabs */}
      <div className="flex items-center gap-2 mt-8">
        <TabBtn active={tab === "mine"} onClick={() => setTab("mine")} testid="tab-mine">
          My Gallery ({safeMine.length})
        </TabBtn>
        <TabBtn active={tab === "feed"} onClick={() => setTab("feed")} testid="tab-feed">
          Community ({safeFeed.length})
        </TabBtn>
      </div>

      <div className="mt-4">
        {tab === "mine" ? (
          <MyGallery items={safeMine} onToggle={toggleVisibility} />
        ) : (
          <CommunityFeed items={safeFeed} />
        )}
      </div>
    </div>
  );
}

const TabBtn = ({ active, onClick, children, testid }) => (
  <button
    type="button"
    onClick={onClick}
    data-testid={testid}
    className={`px-3 py-1.5 rounded-full text-[11px] font-bold uppercase tracking-wider border transition-colors ${
      active
        ? "border-[#00E5FF]/50 bg-[#00E5FF]/10 text-[#00E5FF]"
        : "border-white/8 bg-white/[0.02] text-white/60 hover:text-white/80"
    }`}
  >
    {children}
  </button>
);

const MyGallery = ({ items, onToggle }) => {
  const proofs = items.filter((u) => u.kind === "quest_proof");
  if (proofs.length === 0)
    return (
      <div className="rounded-2xl border border-white/6 bg-[#0F0F13] p-6 text-center text-white/50 text-sm">
        No quest proofs yet. Complete a quest with a photo to fill this gallery.
      </div>
    );
  return (
    <div className="grid grid-cols-2 gap-3">
      {proofs.map((u) => (
        <div
          key={u.id}
          data-testid={`mine-${u.id}`}
          className="relative rounded-2xl overflow-hidden border border-white/8 bg-[#0F0F13]"
        >
          {u.content_type?.startsWith("video/") ? (
            <video
              src={resolveMediaUrl(u.url)}
              className="w-full h-32 object-cover"
              muted
              playsInline
            />
          ) : (
            <img
              src={resolveMediaUrl(u.url)}
              alt=""
              className="w-full h-32 object-cover"
            />
          )}
          <button
            type="button"
            data-testid={`visibility-toggle-${u.id}`}
            onClick={() => onToggle(u)}
            className="absolute top-1.5 right-1.5 h-7 px-2 rounded-full bg-black/70 border border-white/15 flex items-center gap-1 text-[9px] font-bold uppercase tracking-wider hover:bg-black/90"
          >
            {u.is_public ? (
              <>
                <Globe size={10} className="text-[#39FF14]" /> Public
              </>
            ) : (
              <>
                <Lock size={10} className="text-white/60" /> Private
              </>
            )}
          </button>
          {u.caption && (
            <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/85 to-transparent p-2">
              <p className="text-[10px] text-white/85 line-clamp-2">{u.caption}</p>
            </div>
          )}
        </div>
      ))}
    </div>
  );
};

const CommunityFeed = ({ items }) => {
  if (items.length === 0)
    return (
      <div className="rounded-2xl border border-white/6 bg-[#0F0F13] p-6 text-center text-white/50 text-sm">
        No public quest proofs yet. Share one to kick things off!
      </div>
    );
  return (
    <div className="space-y-3">
      {items.map((it) => (
        <div
          key={it.id}
          data-testid={`feed-${it.id}`}
          className="rounded-3xl overflow-hidden border border-white/8 bg-[#0F0F13]"
        >
          <div className="flex items-center gap-3 p-3">
            <img
              src={resolveMediaUrl(it.owner_avatar)}
              alt={it.owner_name}
              className="h-9 w-9 rounded-full object-cover ring-1 ring-white/10 bg-[#1A1A24]"
            />
            <div className="flex-1 min-w-0">
              <div className="text-xs font-bold text-white truncate">{it.owner_name}</div>
              <div className="text-[10px] text-white/50 truncate">
                {it.quest_title} · {it.quest_location}
              </div>
            </div>
            <div className="flex items-center gap-1 text-[#39FF14] font-display font-black text-sm">
              <Zap size={12} /> {it.quest_xp}
            </div>
          </div>
          {it.content_type?.startsWith("video/") ? (
            <video
              src={resolveMediaUrl(it.url)}
              className="w-full max-h-72 object-cover"
              controls
              playsInline
            />
          ) : (
            <img
              src={resolveMediaUrl(it.url)}
              alt={it.caption || it.quest_title}
              className="w-full max-h-72 object-cover"
            />
          )}
          {it.caption && (
            <p className="text-xs text-white/80 px-3 py-2 leading-relaxed">
              {it.caption}
            </p>
          )}
        </div>
      ))}
    </div>
  );
};

const StatTile = ({ icon: Icon, tint, label, value }) => (
  <div className="rounded-2xl border border-white/6 bg-white/[0.02] p-3 flex items-center gap-3">
    <div
      className="h-9 w-9 rounded-xl flex items-center justify-center border"
      style={{ borderColor: `${tint}55`, background: `${tint}12` }}
    >
      <Icon size={14} style={{ color: tint }} />
    </div>
    <div className="flex-1">
      <div className="text-[9px] uppercase tracking-widest text-white/40 font-semibold">
        {label}
      </div>
      <div className="font-display text-sm font-black text-white">{value}</div>
    </div>
  </div>
);
