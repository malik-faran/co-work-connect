# Co-Work Connect

A co-working space platform with:
- Flutter mobile app for users and workspace owners
- React/Vite admin panel for platform administration

## Features

- User authentication and role-based experience (user/owner)
- Browse and view workspace details
- Book workspaces and review booking history
- Owner workspace management and booking oversight
- Collaboration modules for team/workspace interactions
- Notifications, chat, reviews, and payment flow screens

## Tech Stack

- Mobile App: Flutter, Dart
- Admin Panel: React, Vite
- Backend: Supabase (configured through environment variables)

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK (usually included with Flutter)
- Android Studio or VS Code with Flutter extensions
- Git

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/malik-faran/co-work-connect.git
   cd co-work-connect
   ```
2. Install mobile app dependencies:
   ```bash
   flutter pub get
   ```
3. Install admin panel dependencies:
   ```bash
   cd admin-panel
   npm install
   cd ..
   ```
4. Create your local environment file:
   - Add a `.env` file in the project root.
   - Set your required Supabase keys/URLs.
5. Run the mobile app:
   ```bash
   flutter run
   ```
6. Run admin panel:
   ```bash
   cd admin-panel
   npm run dev
   ```

## Project Structure

```text
lib/
  controllers/   # State/control logic
  models/        # Data models
  services/      # API/business services
  utils/         # Constants, helpers, theme
  views/         # Screens and UI

admin-panel/
  src/           # React source code
  package.json   # Admin dependencies/scripts
```

## Useful Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter clean
cd admin-panel && npm run dev
```

## Security Notes

- Do not commit `.env` or secret keys.
- Keep API keys and service credentials in local environment variables.

## Repository

- GitHub: https://github.com/malik-faran/co-work-connect

