# CWL Web — Coworking Spaces (React + Vite)

A full-featured web version of the CWL Flutter app, built with **React + Vite** and connected to the **same Supabase database** as the mobile app and admin panel.

> Find teammates. Build projects. Book spaces.

## Features

**For Members**
- Browse / search / filter workspaces (by type & amenities)
- Workspace detail with image gallery, reviews & ratings
- Book by **hour / day / month** with time slots, seats and category pricing
- Manual payments (Bank / EasyPaisa / JazzCash) with receipt upload
- Digital booking ticket with QR code
- Write reviews after a booking
- **Collaboration Hub** (Fiverr-style): discover projects, apply for roles, open teammates
- **Project rooms**: team, milestones, files, group chat, activity feed
- Real-time 1-1 & group chat (with image messages)
- Notifications, profile, collaboration profile, portfolio, public profiles
- Emergency / SOS contacts

**For Space Owners**
- Owner dashboard with stats
- Add / edit / manage workspaces (categories, pricing, time slots, amenities, images)
- Manage bookings (confirm / cancel)
- Verify manual payment receipts (approve / reject)
- Payment accounts (bank / mobile wallets)
- Analytics & revenue per workspace

## Tech Stack

- React 18 + Vite 5 + React Router 6
- Supabase JS (auth, Postgres, storage, realtime)
- Bootstrap 5 + Bootstrap Icons + Animate.css + AOS (via CDN)
- lucide-react / date-fns

## Getting Started

```bash
cd cwc-web
npm install        # node_modules were copied from admin-panel; run only if needed
npm run dev        # http://localhost:5174
```

`npm run build` produces a production bundle in `dist/`.

## Configuration

Supabase credentials live in `.env` (same project as the Flutter app):

```
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

## Project Structure

```
src/
  components/   shared UI (Layout, common, WorkspaceCard, ProtectedRoute)
  context/      AuthContext, ToastContext
  lib/          supabase client, constants, helpers
  services/     Supabase data layer (auth, workspaces, bookings, payments,
                collaboration, chat, notifications, reviews, profile, storage)
  pages/        auth/ user/ collab/ chat/ owner/ profile/ + Landing, Notifications, Sos
```

The color scheme, fonts (Poppins) and overall design mirror the Flutter app's theme.
