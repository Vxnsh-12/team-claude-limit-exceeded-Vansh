import React, { useEffect, useState } from "react";
import { MapPin, MessageCircle, X, Send, UserPlus, Check, Users2, BookOpen, Rocket, Dumbbell, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { api, resolveMediaUrl } from "@/lib/api";

const bannedWords = ["abuse", "spam"];

const MOCK_FRIENDS = [
  { id: "dev",     name: "Dev",     handle: "@dev.mishra",  year: "3rd year · CSE",  status: "Near AB-1 · online now",       color: "#00E5FF", online: true  },
  { id: "aron",    name: "ARON",    handle: "@aron.j",      year: "2nd year · ECE",  status: "At Foodys · 5 min ago",        color: "#39FF14", online: true  },
  { id: "lakshay", name: "Lakshay", handle: "@lakshay.s",   year: "4th year · Mech", status: "Cricket Ground · 12 min ago",  color: "#C084FC", online: false },
];

const groupIcons = { BookOpen, Rocket, Dumbbell };

export default function SquadPage() {
  const [chatFriend, setChatFriend] = useState(null);
  const [nearby, setNearby] = useState([]);
  const [groups, setGroups] = useState([]);
  const [locBusy, setLocBusy] = useState(false);
  const [joinBusy, setJoinBusy] = useState(null);

  const loadGroups = async () => {
    try { const { data } = await api.get("/groups"); setGroups(data); } catch {}
  };
  const loadNearby = async () => {
    try { const { data } = await api.get("/users/nearby?radius_m=50"); setNearby(data); } catch {}
  };
  useEffect(() => { loadGroups(); loadNearby(); }, []);

  const shareMyLocation = () => {
    if (!navigator.geolocation) return toast.error("Geolocation not supported");
    setLocBusy(true);
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          await api.put("/users/location", { lat: pos.coords.latitude, lng: pos.coords.longitude });
          await loadNearby();
          toast("📍 Location shared · scanning within 50 m");
        } catch (e) { toast.error(e.response?.data?.detail || "Failed"); }
        finally { setLocBusy(false); }
      },
      (err) => { setLocBusy(false); toast.error(err.message || "Location denied"); },
      { enableHighAccuracy: true, timeout: 8000 }
    );
  };

  const sendFriendRequest = async (uid, name) => {
    try {
      const { data } = await api.post("/friends/requests", { to_user_id: uid });
      toast(data.status === "accepted" ? `🎉 You're now friends with ${name}` : `✅ Friend request sent to ${name}`);
      setNearby((cur) => cur.map((u) => u.id === uid ? { ...u, friend_status: data.status === "accepted" ? "friends" : "requested" } : u));
    } catch (e) { toast.error(e.response?.data?.detail || "Failed to send request"); }
  };

  const toggleGroup = async (g) => {
    setJoinBusy(g.id);
    try {
      const path = g.joined ? "leave" : "join";
      await api.post(`/groups/${g.id}/${path}`);
      toast(g.joined ? `Left ${g.name}` : `🎉 Joined ${g.name}`);
      await loadGroups();
    } catch (e) { toast.error(e.response?.data?.detail || "Failed"); }
    finally { setJoinBusy(null); }
  };

  return (
    <div className="px-6 pt-8 pb-6" data-testid="squad-page">
      <div>
        <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">Your Squad</div>
        <h1 className="font-display text-2xl font-black tracking-tight mt-1">
          <span className="text-[#39FF14]">{MOCK_FRIENDS.length}</span> friends nearby
        </h1>
      </div>

      <div className="mt-6 space-y-3">
        {MOCK_FRIENDS.map((f) => (
          <div key={f.id} data-testid={`friend-${f.id}`} className="rounded-3xl bg-[#0F0F13] border border-white/6 p-3 flex items-center gap-3">
            <div className="relative">
              <div className="h-12 w-12 rounded-full flex items-center justify-center font-display font-black text-lg"
                   style={{ background: `${f.color}1F`, border: `2px solid ${f.color}80`, color: f.color }}>
                {f.name[0]}
              </div>
              {f.online && <span className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full bg-[#39FF14] border-2 border-[#0F0F13]" />}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-baseline gap-2">
                <span className="text-white font-bold text-sm truncate">{f.name}</span>
                <span className="text-white/40 text-[10px]">{f.handle}</span>
              </div>
              <div className="text-white/60 text-[11px]">{f.year}</div>
              <div className="text-white/40 text-[10px] mt-1 truncate">{f.status}</div>
            </div>
            <button type="button" data-testid={`locate-${f.id}`} onClick={() => toast(`📍 Locating ${f.name} on the campus map…`)} className="h-9 w-9 rounded-xl bg-[#00E5FF]/12 border border-[#00E5FF]/40 flex items-center justify-center" aria-label="Locate"><MapPin size={14} className="text-[#00E5FF]" /></button>
            <button type="button" data-testid={`chat-${f.id}`} onClick={() => setChatFriend(f)} className="h-9 w-9 rounded-xl bg-[#39FF14]/12 border border-[#39FF14]/40 flex items-center justify-center" aria-label="Chat"><MessageCircle size={14} className="text-[#39FF14]" /></button>
          </div>
        ))}
      </div>

      {/* Nearby users (within 50m) */}
      <div className="mt-8 flex items-baseline justify-between">
        <h2 className="font-display text-lg font-bold tracking-tight">Nearby <span className="text-white/40 text-[11px] font-semibold uppercase tracking-widest ml-1">within 50 m</span></h2>
        <button data-testid="share-location-btn" onClick={shareMyLocation} disabled={locBusy}
          className="h-8 px-3 rounded-full text-[10px] font-bold uppercase tracking-wider bg-[#00E5FF]/12 border border-[#00E5FF]/40 text-[#00E5FF] hover:bg-[#00E5FF]/20 disabled:opacity-50 flex items-center gap-1.5">
          {locBusy ? <Loader2 size={12} className="animate-spin" /> : <MapPin size={12} />} Scan
        </button>
      </div>
      <div className="mt-3 space-y-2">
        {nearby.length === 0 && (
          <div data-testid="nearby-empty" className="rounded-2xl border border-white/6 bg-[#0F0F13] p-4 text-center text-white/50 text-xs">
            Tap Scan to share your location and find classmates within 50 m.
          </div>
        )}
        {nearby.map((u) => (
          <div key={u.id} data-testid={`nearby-${u.id}`} className="rounded-2xl bg-[#0F0F13] border border-white/6 p-3 flex items-center gap-3">
            <img src={resolveMediaUrl(u.avatar_url)} alt={u.name} className="h-10 w-10 rounded-full ring-1 ring-white/10 bg-[#1A1A24]" />
            <div className="flex-1 min-w-0">
              <div className="text-white text-xs font-bold truncate">{u.name}</div>
              <div className="text-white/50 text-[10px]">Lv {u.level} · {u.distance_m} m away</div>
            </div>
            <FriendActionBtn user={u} testid={`add-nearby-${u.id}`} onAdd={() => sendFriendRequest(u.id, u.name)} />
          </div>
        ))}
      </div>

      {/* Groups */}
      <div className="mt-8">
        <h2 className="font-display text-lg font-bold tracking-tight flex items-center gap-2">
          <Users2 size={16} className="text-[#C084FC]" /> Study Groups
        </h2>
        <div className="mt-3 space-y-2">
          {groups.map((g) => {
            const Icon = groupIcons[g.icon] || Users2;
            const busy = joinBusy === g.id;
            return (
              <div key={g.id} data-testid={`group-${g.id}`} className="rounded-2xl bg-[#0F0F13] border border-white/6 p-3 flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl flex items-center justify-center border" style={{ background: `${g.color}18`, borderColor: `${g.color}66` }}>
                  <Icon size={16} style={{ color: g.color }} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-white text-xs font-bold truncate">{g.name}</div>
                  <div className="text-white/50 text-[10px] truncate">{g.member_count} member{g.member_count === 1 ? "" : "s"} · {g.description}</div>
                </div>
                <button
                  type="button"
                  data-testid={`join-${g.id}`}
                  disabled={busy}
                  onClick={() => toggleGroup(g)}
                  className={`h-8 px-3 rounded-full text-[10px] font-black uppercase tracking-wider flex items-center gap-1.5 disabled:opacity-50 ${
                    g.joined
                      ? "bg-[#39FF14]/15 border border-[#39FF14]/50 text-[#39FF14]"
                      : "bg-[#00E5FF] text-black hover:shadow-[0_0_16px_rgba(0,229,255,0.55)]"
                  }`}
                >
                  {busy ? <Loader2 size={11} className="animate-spin" /> : g.joined ? <Check size={11} /> : <UserPlus size={11} />}
                  {g.joined ? "Joined" : "Join"}
                </button>
              </div>
            );
          })}
        </div>
      </div>

      {chatFriend && <ChatModal friend={chatFriend} onClose={() => setChatFriend(null)} />}
    </div>
  );
}

export const FriendActionBtn = ({ user, onAdd, testid }) => {
  const s = user.friend_status;
  if (s === "self") return null;
  if (s === "friends")
    return <span className="h-8 px-3 rounded-full text-[10px] font-black uppercase tracking-wider bg-[#39FF14]/15 border border-[#39FF14]/50 text-[#39FF14] flex items-center gap-1"><Check size={11} /> Friends</span>;
  if (s === "requested")
    return <span className="h-8 px-3 rounded-full text-[10px] font-black uppercase tracking-wider bg-white/[0.06] border border-white/15 text-white/60 flex items-center gap-1">Requested</span>;
  return (
    <button type="button" data-testid={testid} onClick={onAdd}
      className="h-8 px-3 rounded-full text-[10px] font-black uppercase tracking-wider bg-[#00E5FF] text-black flex items-center gap-1 hover:shadow-[0_0_16px_rgba(0,229,255,0.55)]">
      <UserPlus size={11} /> Add
    </button>
  );
};

const ChatModal = ({ friend, onClose }) => {
  const [messages, setMessages] = useState([
    { text: "Hey! Are you coming to AdVITya tonight?", mine: false },
    { text: "Yep, meet at Foodys around 7?", mine: true },
    { text: "Perfect. I'll grab a table for the squad 🍟", mine: false },
  ]);
  const [draft, setDraft] = useState("");
  const send = (e) => {
    e?.preventDefault?.();
    const text = draft.trim();
    if (!text) return;
    if (bannedWords.some((w) => text.toLowerCase().includes(w))) {
      toast.error("⚠️ Message blocked: Contains inappropriate language.", {
        duration: 3000,
        style: { background: "#DC2626", border: "1px solid rgba(255,255,255,0.25)", color: "#fff", fontWeight: 700 },
      });
      return;
    }
    setMessages((m) => [...m, { text, mine: true }]);
    setDraft("");
  };
  return (
    <div className="fixed inset-0 z-[60] bg-black/70 backdrop-blur-sm flex items-center justify-center px-4" data-testid="chat-modal">
      <div className="w-full max-w-md h-[80vh] rounded-3xl bg-[#0F0F13] border border-white/10 flex flex-col overflow-hidden">
        <div className="h-14 border-b border-white/6 flex items-center gap-3 px-4">
          <div className="h-9 w-9 rounded-full flex items-center justify-center font-display font-black" style={{ background: `${friend.color}1F`, color: friend.color, border: `2px solid ${friend.color}80` }}>{friend.name[0]}</div>
          <div className="flex-1"><div className="text-sm font-bold text-white">{friend.name}</div><div className="text-[10px] text-[#39FF14] font-semibold">online</div></div>
          <button onClick={onClose} data-testid="chat-close" className="h-9 w-9 rounded-full hover:bg-white/10 flex items-center justify-center"><X size={16} className="text-white/70" /></button>
        </div>
        <div className="flex-1 overflow-y-auto p-4 space-y-2">
          {messages.map((m, i) => (
            <div key={i} className={`flex ${m.mine ? "justify-end" : "justify-start"}`}>
              <div className={`max-w-[80%] px-3.5 py-2 text-sm leading-snug font-medium rounded-2xl ${m.mine ? "bg-[#00E5FF] text-black rounded-br-md" : "bg-[#1A1A24] text-white/90 rounded-bl-md"}`}>{m.text}</div>
            </div>
          ))}
        </div>
        <form onSubmit={send} className="border-t border-white/6 p-3 flex items-center gap-2">
          <input data-testid="chat-input" value={draft} onChange={(e) => setDraft(e.target.value)} placeholder="Message…" className="flex-1 h-10 rounded-full bg-white/[0.04] border border-white/10 px-4 outline-none text-sm text-white placeholder:text-white/30 focus:border-[#00E5FF]/50" />
          <button type="submit" data-testid="chat-send" className="h-10 w-10 rounded-full bg-[#00E5FF] text-black flex items-center justify-center hover:shadow-[0_0_18px_rgba(0,229,255,0.55)] active:scale-95"><Send size={16} /></button>
        </form>
      </div>
    </div>
  );
};
