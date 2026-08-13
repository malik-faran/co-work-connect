# Co-Work Connect

A comprehensive co-working space management platform featuring:
- **Flutter Mobile App**: For workspace users and workspace owners (iOS & Android)
- **React / Vite Admin Panel**: For platform administration and management
- **Supabase Backend**: Realtime database, authentication, storage, and edge functions

---

## Features

- **User Authentication**: Role-based access (Users & Owners) with Supabase Auth
- **Workspace Discovery**: Browse, filter, search, and view detailed workspace amenities & maps
- **Booking Engine**: Book desks/offices with booking management & payment options
- **Owner Dashboard**: Workspace management, analytics, wallet, and booking oversight
- **Collaboration Hub**: Team creation, project management, and workspace networking
- **Realtime Chat & Notifications**: Built-in messaging, FCM push notifications, and review system
- **Admin Panel**: Platform analytics, user management, and system configuration

---

## Tech Stack

- **Mobile App**: Flutter, Dart, Supabase Flutter SDK
- **Admin Panel**: React 18, Vite, Tailwind CSS / Lucide icons
- **Backend**: Supabase (PostgreSQL, Realtime, Auth, Storage)

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.x or higher)
- [Node.js](https://nodejs.org/) (v18+ recommended) & npm
- Android Studio / VS Code with Flutter & Dart extensions

---

### Setup Steps

#### 1. Clone the Repository
```bash
git clone https://github.com/malik-faran/co-work-connect.git
cd co-work-connect
```

#### 2. Setup & Run Mobile App (Flutter)
```bash
# Get Flutter dependencies
flutter pub get

# (Optional) Clean build cache if experiencing build issues
flutter clean
flutter pub get

# Run on an attached device / emulator
flutter run
```

#### 3. Setup & Run Admin Panel (React / Vite)
```bash
cd admin-panel

# Install dependencies
npm install

# Run development server
npm run dev
```

#### 4. Environment Configuration
- Create a `.env` file in the project root for Flutter (Supabase URL & Anon Key).
- Create a `.env` file inside `admin-panel/` with necessary Vite environment variables (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`).

---

## Maintenance & Build Commands

| Action | Command |
|---|---|
| Fetch Flutter Dependencies | `flutter pub get` |
| Clean Flutter Cache & Build | `flutter clean && flutter pub get` |
| Run Flutter App | `flutter run` |
| Build Android APK | `flutter build apk --release` |
| Run Admin Panel | `cd admin-panel && npm run dev` |
| Build Admin Panel | `cd admin-panel && npm run build` |

---

## Security Notes

- **Never commit `.env` files** or production credentials to Git.
- Keep Supabase service role keys secure and stored in server/edge environments only.

---

## Repository

- **GitHub Repository**: [https://github.com/malik-faran/co-work-connect](https://github.com/malik-faran/co-work-connect)


