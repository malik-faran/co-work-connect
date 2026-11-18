# Co-Work Connect

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter: 3.x+](https://img.shields.io/badge/Flutter-3.x+-blue.svg)](https://flutter.dev)
[![React: 18](https://img.shields.io/badge/React-18-61DAFB.svg)](https://react.dev)
[![Vite: 5.x](https://img.shields.io/badge/Vite-5.x-646CFF.svg)](https://vitejs.dev)
[![Supabase: Backend](https://img.shields.io/badge/Supabase-Backend-3ECF8E.svg)](https://supabase.io)

---

## 📋 Overview

**Co-Work Connect** is a full-stack co-working space management platform that bridges the gap between workspace users, owners, and platform administrators. The ecosystem comprises:

- **Flutter Mobile Application** — Available on iOS and Android for workspace users and owners to discover, book, and manage workspaces on-the-go.
- **React Admin Panel (Vite)** — A modern, performant administration interface built with React 18, Vite, and Tailwind CSS for platform oversight, user management, and analytics.
- **Supabase Backend** — Hosted PostgreSQL database, realtime subscriptions, authentication, storage, and edge functions powering the entire platform.

The platform enables workspace discovery, desk/office booking, owner dashboards, team collaboration, realtime communication, and comprehensive admin oversight.

---

## ✨ Features

### 👥 User Features
- **Role-based Authentication**: Secure sign-in and registration for Users and Owners via Supabase Auth.
- **Workspace Discovery**: Browse, filter, and search workspaces with detailed amenities, photos, and interactive maps.
- **Booking Engine**: Reserve desks or offices with flexible payment options, booking confirmations, and management.
- **Collaboration Hub**: Create or join teams, manage projects, and network with other workspace users.
- **Realtime Chat & Notifications**: Built-in messaging with Firebase Cloud Messaging push notifications.
- **Workspace Reviews**: Rate and review workspaces after booking to help the community.

### 👔 Owner Features
- **Workspace Management**: Add, update, and remove workspaces, amenities, and pricing.
- **Analytics Dashboard**: View booking trends, revenue, occupancy rates, and user engagement metrics.
- **Wallet Management**: Track earnings, manage payouts, and view transaction history.
- **Booking Oversight**: Approve, reject, or modify bookings for your workspace.
- **Custom Branding**: Personalize workspace profile and communication themes.

### 🛡️ Admin Panel Features
- **Platform Analytics**: Overview of user growth, workspace distribution, and system health metrics.
- **User Management**: View, filter, and manage all user accounts and roles across the platform.
- **Workspace Moderation**: Review and approve new workspace submissions, enforce policies.
- **System Configuration**: Global feature flags, pricing tiers, and platform-wide settings.
- **Realtime Monitoring**: Observe active bookings, chat sessions, and system performance in realtime.
- **Reporting Tools**: Generate and download reports on revenue, user activity, and booking analytics.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter, Dart, Supabase Flutter SDK |
| **Admin Panel** | React 18, Vite, Tailwind CSS, Lucide Icons |
| **Backend** | Supabase (PostgreSQL, Realtime, Auth, Storage, Edge Functions) |
| **Database** | PostgreSQL via Supabase |
| **State Management** | Flutter Riverpod, React Query |
| **Deployments** | Supabase Edge Functions, Vite build, Flutter build apk / appbundle |
| **Hosting** | Supabase Netlify/Vercel integration (frontend), Cloudflare CDN (assets) |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.x or higher)
- [Node.js](https://nodejs.org/) (v18+ recommended) & npm
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter & Dart extensions
- [Supabase Account](https://supabase.io/) (required for backend setup)
- [Git](https://git-scm.com/) for version control

### Setup Steps

#### 1. Clone the Repository

```bash
git clone https://github.com/malik-faran/co-work-connect.git
cd co-work-connect
```

#### 2. Setup & Run Mobile App (Flutter)

```bash
# Install Flutter dependencies
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

# Run development server with hot module replacement
npm run dev
```

The admin panel will be available at `http://localhost:5173` by default.

#### 4. Environment Configuration

1. **Create a `.env` file in the project root** for Flutter (Supabase URL & Anon Key):
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_anon_public_key
   ```

2. **Create a `.env` file inside `admin-panel/`** with necessary Vite environment variables:
   ```
   VITE_SUPABASE_URL=https://your-project.supabase.co
   VITE_SUPABASE_ANON_KEY=your_anon_public_key
   ```

> ⚠️ **Never commit `.env` files or production credentials to version control.** Use `.env.example` to document required variables.

---

## 📦 Maintenance & Build Commands

| Action | Command |
|---|---|
| **Fetch Flutter Dependencies** | `flutter pub get` |
| **Clean Flutter Cache & Build** | `flutter clean && flutter pub get` |
| **Run Flutter App** | `flutter run` |
| **Build Android APK (Release)** | `flutter build apk --release` |
| **Build Android App Bundle** | `flutter build appbundle --release` |
| **Run Admin Panel** | `cd admin-panel && npm run dev` |
| **Build Admin Panel** | `cd admin-panel && npm run build` |
| **Lint Admin Panel** | `cd admin-panel && npm run lint` |
| **Preview Admin Build** | `cd admin-panel && npx serve dist/` |

---

## 🔒 Security Notes

- **Never commit `.env` files** or production credentials to Git. Add `.env*` to `.gitignore`.
- Keep Supabase service role keys secure and store them in server/edge environments only (never in client apps).
- Enable [Supabase RLS (Row Level Security)](https://supabase.com/docs/guides/auth/row-level-security) on all tables to restrict data access.
- Use Supabase [edge functions](https://supabase.com/docs/references/javascript/functions) for sensitive backend logic (payments, authentication flows, data validation).
- Validate all user inputs on the admin panel before persisting to the database.
- Regularly rotate Supabase API keys and review authentication logs for suspicious activity.

---

## 📁 Repository

- **GitHub Repository**: [https://github.com/malik-faran/co-work-connect](https://github.com/malik-faran/co-work-connect)
- **Issues**: [Report bugs or feature requests](https://github.com/malik-faran/co-work-connect/issues)
- **Documentation**: [Wiki](https://github.com/malik-faran/co-work-connect/wiki)
- **License**: MIT

---

## 👥 Contributing

1. **Fork** the repository to your GitHub account.
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add some amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open a Pull Request** with a clear description of:
   - What the change does
   - Which section(s) of the codebase it affects (mobile, admin panel, backend)
   - Any relevant screenshots or demo links

### Contribution Guidelines

- **Code Style**: Follow the existing code style (Flutter: effective Dart, React: airbnb style with Prettier).
- **Commit Messages**: Use present tense, "Add feature" not "Added feature".
- **Testing**: Ensure existing tests pass; add new tests for new functionality.
- **Documentation**: Update this README and any relevant docs for new features.
- **Admin Panel**: When modifying the admin panel, also update the corresponding TypeScript types and Supabase schemas if applicable.

Please read the [Code of Conduct](https://github.com/malik-faran/co-work-connect/blob/main/CODE_OF_CONDUCT.md) before contributing.

---

## 💬 Contact

- **Project Owner**: Malik Farhan
- **GitHub**: [@malik-faran](https://github.com/malik-faran)
- **Email**: malik.faran@co-work-connect.dev
- **LinkedIn**: [linkedin.com/in/malik-faran](https://linkedin.com/in/malik-faran)

---

## 🙏 Acknowledgments

- Inspired by the growing co-working and flexible workspace industry.
- Built with [Flutter](https://flutter.dev), [React](https://react.dev), and [Supabase](https://supabase.io).
- Special thanks to all contributors and early adopters.