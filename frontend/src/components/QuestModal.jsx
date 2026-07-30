import React, { useState } from "react";
import { Dialog, DialogContent, DialogTitle, DialogDescription } from "./ui/dialog";
import {
  MapPin, Clock, Trophy, Loader2, Camera, Globe, Lock, Upload, X,
  Zap, BookOpen, Utensils, Dumbbell, Search, Map as MapIcon, Users,
  KeyRound, GraduationCap, Sun, PartyPopper, Timer,
} from "lucide-react";
import { toast } from "sonner";
import { api, formatApiErrorDetail } from "../lib/api";
import { useAuth } from "../context/AuthContext";

const iconMap = {
  Zap, BookOpen, Utensils, Dumbbell, Search, Map: MapIcon, Users,
  KeyRound, GraduationCap, Sun, PartyPopper, Timer,
};

const MAX_BYTES = 20 * 1024 * 1024;

export const QuestModal = ({ quest, open, onClose, onCompleted }) => {
  const [loading, setLoading] = useState(false);
  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState(null);
  const [caption, setCaption] = useState("");
  const [isPublic, setIsPublic] = useState(true);
  const { setUser } = useAuth();

  if (!quest) return null;
  const Icon = iconMap[quest.icon] || Zap;

  const reset = () => {
    setFile(null);
    if (preview) URL.revokeObjectURL(preview);
    setPreview(null);
    setCaption("");
    setIsPublic(true);
  };

  const onPickFile = (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    if (f.size > MAX_BYTES) {
      toast.error("File too large — max 20 MB");
      e.target.value = "";
      return;
    }
    setFile(f);
    if (preview) URL.revokeObjectURL(preview);
    setPreview(URL.createObjectURL(f));
  };

  const handleClose = () => {
    reset();
    onClose();
  };

  const handleFinish = async () => {
    setLoading(true);
    try {
      let res;
      if (file) {
        const fd = new FormData();
        fd.append("quest_id", quest.id);
        fd.append("caption", caption);
        fd.append("is_public", String(isPublic));
        fd.append("file", file);
        const { data } = await api.post("/uploads/quest-proof", fd, {
          headers: { "Content-Type": "multipart/form-data" },
        });
        res = data;
      } else {
        const { data } = await api.post("/quests/complete", { quest_id: quest.id });
        res = data;
      }
      setUser(res.user);
      if (res.xp_gained > 0) {
        toast.success(`+${res.xp_gained} XP earned!`, {
          description: res.leveled_up ? "You leveled up!" : quest.title,
        });
      } else {
        toast(file ? "Proof uploaded" : "Already completed");
      }
      if (res.new_badges?.length) {
        toast(`New badge: ${res.new_badges.join(", ")}`);
      }
      onCompleted?.(res);
      handleClose();
    } catch (e) {
      toast.error(formatApiErrorDetail(e.response?.data?.detail) || e.message);
    } finally {
      setLoading(false);
    }
  };

  const isVideo = file?.type?.startsWith("video/");

  return (
    <Dialog open={open} onOpenChange={(v) => !v && handleClose()}>
      <DialogContent
        data-testid="quest-modal"
        className="glass border-white/10 rounded-3xl max-w-sm p-0 overflow-hidden max-h-[92vh] overflow-y-auto"
      >
        <div className="relative p-6 pb-4">
          <div className="absolute inset-x-0 -top-24 h-40 bg-[#00E5FF]/10 blur-3xl pointer-events-none" />
          <div className="relative flex items-start gap-4">
            <div className="h-14 w-14 rounded-2xl bg-[#1A1A24] border border-[#00E5FF]/30 flex items-center justify-center neon-glow-blue">
              <Icon size={24} strokeWidth={2.5} className="text-[#00E5FF]" />
            </div>
            <div className="flex-1">
              <span className="text-[10px] font-bold uppercase tracking-[0.25em] text-white/50">
                Quest
              </span>
              <DialogTitle className="font-display text-xl font-bold text-white mt-0.5">
                {quest.title}
              </DialogTitle>
              <DialogDescription className="sr-only">
                {quest.description}
              </DialogDescription>
            </div>
          </div>
          <p className="text-sm text-white/70 mt-4 leading-relaxed">{quest.description}</p>

          <div className="grid grid-cols-3 gap-2 mt-6">
            <Stat icon={MapPin} label="Location" value={quest.location} />
            <Stat icon={Clock} label="Duration" value={`${quest.duration_min}m`} />
            <Stat icon={Trophy} label="Reward" value={`${quest.xp_reward} XP`} accent />
          </div>

          {/* Proof upload */}
          {!quest.completed && (
            <div className="mt-6">
              <div className="flex items-center justify-between mb-2">
                <span className="text-[10px] uppercase tracking-[0.25em] text-white/50 font-semibold">
                  Attach Proof <span className="text-white/30 normal-case tracking-normal">(optional)</span>
                </span>
                <span className="text-[10px] text-white/30">Max 20 MB</span>
              </div>

              {!file && (
                <label
                  data-testid="proof-picker"
                  className="flex flex-col items-center justify-center gap-2 rounded-2xl border border-dashed border-white/12 bg-white/[0.02] py-6 cursor-pointer hover:border-[#00E5FF]/50 transition-colors"
                >
                  <input
                    type="file"
                    accept="image/*,video/mp4,video/webm,video/quicktime"
                    className="hidden"
                    onChange={onPickFile}
                    data-testid="proof-input"
                  />
                  <Upload size={22} className="text-[#00E5FF]" />
                  <span className="text-xs font-semibold text-white/70">
                    Snap a photo or short video
                  </span>
                  <span className="text-[10px] text-white/30">JPG · PNG · WEBP · MP4</span>
                </label>
              )}

              {file && (
                <div className="rounded-2xl border border-white/8 bg-[#0F0F13] overflow-hidden">
                  <div className="relative">
                    {isVideo ? (
                      <video src={preview} className="w-full h-40 object-cover" controls muted />
                    ) : (
                      <img src={preview} alt="preview" className="w-full h-40 object-cover" />
                    )}
                    <button
                      type="button"
                      onClick={reset}
                      data-testid="proof-remove"
                      className="absolute top-2 right-2 h-7 w-7 rounded-full bg-black/70 border border-white/15 flex items-center justify-center hover:bg-black/90"
                      aria-label="Remove media"
                    >
                      <X size={14} className="text-white" />
                    </button>
                  </div>
                  <div className="p-3 space-y-2">
                    <input
                      data-testid="proof-caption"
                      value={caption}
                      onChange={(e) => setCaption(e.target.value)}
                      placeholder="Say something about this quest..."
                      maxLength={140}
                      className="w-full bg-transparent outline-none text-xs text-white placeholder:text-white/30 font-medium"
                    />
                    <div className="flex items-center gap-2">
                      <ToggleChip
                        active={isPublic}
                        onClick={() => setIsPublic(true)}
                        icon={Globe}
                        label="Public"
                        testid="proof-toggle-public"
                      />
                      <ToggleChip
                        active={!isPublic}
                        onClick={() => setIsPublic(false)}
                        icon={Lock}
                        label="Private"
                        testid="proof-toggle-private"
                      />
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="p-6 pt-2 border-t border-white/6">
          <button
            data-testid="complete-quest-btn"
            onClick={handleFinish}
            disabled={loading || quest.completed}
            className="w-full h-12 rounded-full bg-[#00E5FF] text-black font-bold text-sm tracking-wide hover:shadow-[0_0_28px_rgba(0,229,255,0.55)] transition-[box-shadow,transform] active:scale-[0.98] disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {loading && <Loader2 size={16} className="animate-spin" />}
            {file && <Camera size={16} />}
            {quest.completed
              ? "Already Completed"
              : file
              ? "Complete with Proof"
              : "Complete Quest"}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
};

const Stat = ({ icon: Icon, label, value, accent }) => (
  <div className="rounded-2xl border border-white/6 bg-white/[0.02] px-3 py-3">
    <Icon size={14} className={accent ? "text-[#39FF14]" : "text-white/50"} />
    <div className="text-[10px] uppercase tracking-widest text-white/40 font-semibold mt-2">
      {label}
    </div>
    <div className={`text-xs font-bold mt-0.5 truncate ${accent ? "text-[#39FF14]" : "text-white"}`}>
      {value}
    </div>
  </div>
);

const ToggleChip = ({ active, onClick, icon: Icon, label, testid }) => (
  <button
    type="button"
    onClick={onClick}
    data-testid={testid}
    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-[10px] font-bold uppercase tracking-wider border transition-colors ${
      active
        ? "border-[#00E5FF]/50 bg-[#00E5FF]/10 text-[#00E5FF]"
        : "border-white/10 bg-white/[0.02] text-white/50 hover:text-white/80"
    }`}
  >
    <Icon size={11} /> {label}
  </button>
);
