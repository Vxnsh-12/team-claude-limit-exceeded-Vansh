import React, { useState } from "react";
import { MapPin, MessageCircle, X, Send } from "lucide-react";
import { toast } from "sonner";

const bannedWords = ["abuse", "spam"];

const FRIENDS = [
  { id: "dev",     name: "Dev",     handle: "@dev.mishra",  year: "3rd year · CSE",  status: "Near AB-1 · online now",       color: "#00E5FF", online: true  },
  { id: "aron",    name: "ARON",    handle: "@aron.j",      year: "2nd year · ECE",  status: "At Foodys · 5 min ago",        color: "#39FF14", online: true  },
  { id: "lakshay", name: "Lakshay", handle: "@lakshay.s",   year: "4th year · Mech", status: "Cricket Ground · 12 min ago",  color: "#C084FC", online: false },
];

export default function SquadPage() {
  const [chatFriend, setChatFriend] = useState(null);

  const onLocate = (f) => {
    toast(`📍 Locating ${f.name} on the campus map…`);
  };

  return (
    <div className="px-6 pt-8" data-testid="squad-page">
      <div>
        <div className="text-[10px] uppercase tracking-[0.3em] text-white/50 font-semibold">Your Squad</div>
        <h1 className="font-display text-2xl font-black tracking-tight mt-1">
          <span className="text-[#39FF14]">{FRIENDS.length}</span> friends nearby
        </h1>
      </div>

      <div className="mt-6 space-y-3">
        {FRIENDS.map((f) => (
          <div
            key={f.id}
            data-testid={`friend-${f.id}`}
            className="rounded-3xl bg-[#0F0F13] border border-white/6 p-3 flex items-center gap-3"
          >
            <div className="relative">
              <div
                className="h-12 w-12 rounded-full flex items-center justify-center font-display font-black text-lg"
                style={{
                  background: `${f.color}1F`,
                  border: `2px solid ${f.color}80`,
                  color: f.color,
                }}
              >
                {f.name[0]}
              </div>
              {f.online && (
                <span className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full bg-[#39FF14] border-2 border-[#0F0F13]" />
              )}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-baseline gap-2">
                <span className="text-white font-bold text-sm truncate">{f.name}</span>
                <span className="text-white/40 text-[10px]">{f.handle}</span>
              </div>
              <div className="text-white/60 text-[11px]">{f.year}</div>
              <div className="text-white/40 text-[10px] mt-1 truncate">{f.status}</div>
            </div>
            <button
              type="button"
              data-testid={`locate-${f.id}`}
              onClick={() => onLocate(f)}
              className="h-9 w-9 rounded-xl bg-[#00E5FF]/12 border border-[#00E5FF]/40 flex items-center justify-center hover:bg-[#00E5FF]/20"
              aria-label="Locate"
            >
              <MapPin size={14} className="text-[#00E5FF]" />
            </button>
            <button
              type="button"
              data-testid={`chat-${f.id}`}
              onClick={() => setChatFriend(f)}
              className="h-9 w-9 rounded-xl bg-[#39FF14]/12 border border-[#39FF14]/40 flex items-center justify-center hover:bg-[#39FF14]/20"
              aria-label="Chat"
            >
              <MessageCircle size={14} className="text-[#39FF14]" />
            </button>
          </div>
        ))}
      </div>

      {chatFriend && <ChatModal friend={chatFriend} onClose={() => setChatFriend(null)} />}
    </div>
  );
}

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
    const lower = text.toLowerCase();
    if (bannedWords.some((w) => lower.includes(w))) {
      toast.error("⚠️ Message blocked: Contains inappropriate language.", {
        duration: 3000,
        style: {
          background: "#DC2626",
          border: "1px solid rgba(255,255,255,0.25)",
          color: "#fff",
          fontWeight: 700,
        },
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
          <div
            className="h-9 w-9 rounded-full flex items-center justify-center font-display font-black"
            style={{ background: `${friend.color}1F`, color: friend.color, border: `2px solid ${friend.color}80` }}
          >
            {friend.name[0]}
          </div>
          <div className="flex-1">
            <div className="text-sm font-bold text-white">{friend.name}</div>
            <div className="text-[10px] text-[#39FF14] font-semibold">online</div>
          </div>
          <button onClick={onClose} data-testid="chat-close" className="h-9 w-9 rounded-full hover:bg-white/10 flex items-center justify-center">
            <X size={16} className="text-white/70" />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-4 space-y-2">
          {messages.map((m, i) => (
            <div key={i} className={`flex ${m.mine ? "justify-end" : "justify-start"}`}>
              <div
                className={`max-w-[80%] px-3.5 py-2 text-sm leading-snug font-medium rounded-2xl ${
                  m.mine
                    ? "bg-[#00E5FF] text-black rounded-br-md"
                    : "bg-[#1A1A24] text-white/90 rounded-bl-md"
                }`}
              >
                {m.text}
              </div>
            </div>
          ))}
        </div>
        <form onSubmit={send} className="border-t border-white/6 p-3 flex items-center gap-2">
          <input
            data-testid="chat-input"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="Message…"
            className="flex-1 h-10 rounded-full bg-white/[0.04] border border-white/10 px-4 outline-none text-sm text-white placeholder:text-white/30 focus:border-[#00E5FF]/50"
          />
          <button
            type="submit"
            data-testid="chat-send"
            className="h-10 w-10 rounded-full bg-[#00E5FF] text-black flex items-center justify-center hover:shadow-[0_0_18px_rgba(0,229,255,0.55)] active:scale-95"
          >
            <Send size={16} />
          </button>
        </form>
      </div>
    </div>
  );
};
