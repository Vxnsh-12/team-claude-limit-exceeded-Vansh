# VIT Quest — Product Requirements Doc (living)

## Original Problem Statement
Create a modern, clean, and interactive design system for a gamified campus navigation app called 'VIT Quest'. The app should have a dark mode aesthetic with vibrant, neon-accent colors (like electric blue or lime green) to emphasize the gaming and fitness aspects. Use sleek, rounded containers with soft shadows, minimalistic typography, and plenty of negative space to keep the UI uncluttered. Include a custom Bottom Navigation Bar with four icons: Home (Dashboard), Map (Navigate), Trophy (Leaderboard), and User (Social Profile).

## User Choices (locked)
- Scope: Full-stack functional app
- Map: Custom stylized SVG/illustrated campus map (game-like)
- Neon accents: BOTH electric blue (#00E5FF) + lime green (#39FF14)
- Auth: Simple JWT email/password
- Gamification: Full loop with mock data (quests, XP, badges, streaks)

## Architecture
- Backend: FastAPI + MongoDB (Motor). JWT via httpOnly cookies + Bearer header fallback. Bcrypt hashing. Startup seeding of users/quests/locations.
- Frontend: React 19 + React Router + Tailwind + Framer Motion + Sonner + shadcn/ui. Mobile-first `max-w-md` column centered on desktop.
- Fonts: Unbounded (display, XP/level numbers) + Manrope (body).
- Palette: `#050505` bg, `#0F0F13` surface, `#00E5FF` primary, `#39FF14` secondary.

## Personas
- **Player (student)** — logs in, browses active quests, walks to campus POIs, completes quests for XP, collects badges, competes on leaderboard.
- **Admin** — seeded account for demo purposes.

## Core Requirements
- Auth (JWT): register / login / logout / me
- Dashboard: level ring, streak/quests/badges stats, list of active quests
- Custom SVG campus map with pulsing quest pins per location
- Leaderboard with podium + rows + all-time/weekly scope toggle
- Profile with avatar, XP ring, badges, quest history, logout
- Bottom nav with 4 tabs (Home/Map/Trophy/Profile) + framer-motion active pill

## Implemented (2026-02)
- [x] Backend auth (register/login/logout/me) with bcrypt + JWT + httpOnly cookie
- [x] Seed: 12 quests, 12 campus locations, 8 mock leaderboard users, admin, test player
- [x] Quests: /api/quests, /api/quests/active, /api/quests/complete (XP + level curve + badge unlocks)
- [x] Leaderboard endpoint sorted by XP with is_you flag
- [x] Frontend: Login, Register, Dashboard, MapPage (SVG map + pins + legend + Nearby list), Leaderboard (podium + rows), Profile (badges + history + logout)
- [x] BottomNav with framer-motion active pill and 4 data-testid'd nav items
- [x] QuestModal (Dialog + Sonner toast on complete)
- [x] LevelRing SVG with gradient stroke and XP-to-level curve
- [x] Full theming (Unbounded/Manrope fonts, grid-bg backdrop, glass utility, neon glows)

## Backlog / Next Priorities
### P0 (real functionality upgrades)
- Real user-to-user friending / social feed (currently profile is read-only)
- Weekly leaderboard scope actually filtered by created_at instead of same all-time list
- Password reset + email verification

### P1 (product depth)
- Quest categories filter chips on dashboard/map (fitness/social/academic/exploration)
- Quest streak bonus multiplier + daily-quest highlight
- Push notifications when new quest spawns at a nearby location
- Share badge / achievement to social image (great virality lever)

### P2 (polish / nice-to-have)
- Optional: split server.py into routers (auth/, quests/, users/)
- Set explicit CORS origins (spec-compliant with credentials)
- Add DialogDescription for Radix a11y compliance
- Weekly XP recap email

## Testing
- Backend: /app/backend/tests/backend_test.py (11/11 passing)
- Frontend: playwright end-to-end via testing_agent (95% passing; only known low: sonner overlap fixed, SVG pin hit-target fixed 2026-02)
- Test credentials: `player@vitquest.com` / `player123`, admin `admin@vitquest.com` / `admin123`

## Deployment Notes
- Backend port 8001 (supervisor). Frontend port 3000 (supervisor).
- MONGO_URL + DB_NAME from env. JWT_SECRET, ADMIN_EMAIL, ADMIN_PASSWORD in backend/.env.
