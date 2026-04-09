# Co-Work Connect

A Flutter-based co-working space booking and management app with collaboration features for users and workspace owners.

## Features

- User authentication and role-based experience (user/owner)
- Browse and view workspace details
- Book workspaces and review booking history
- Owner workspace management and booking oversight
- Collaboration modules for team/workspace interactions
- Notifications, chat, reviews, and payment flow screens

## Tech Stack

- Flutter
- Dart
- Supabase (configured through environment variables)

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
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Create your local environment file:
   - Add a `.env` file in the project root.
   - Set your required Supabase keys/URLs.
4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```text
lib/
  controllers/   # State/control logic
  models/        # Data models
  services/      # API/business services
  utils/         # Constants, helpers, theme
  views/         # Screens and UI
```

## Useful Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter clean
```

## Security Notes

- Do not commit `.env` or secret keys.
- Keep API keys and service credentials in local environment variables.

## Repository

- GitHub: https://github.com/malik-faran/co-work-connect

