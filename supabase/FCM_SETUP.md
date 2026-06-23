# FCM (Firebase Cloud Messaging) Setup — Co-Work Connect

Push notifications work **even when the app is closed**. Follow every step.

---

## Part 1 — Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. **Create project** (or use existing) → name e.g. `cowork-connect`
3. Enable **Google Analytics** (optional)

### Android app

1. Firebase → **Add app** → **Android**
2. Package name: `com.example.cwc` (must match `android/app/build.gradle.kts`)
3. Download **`google-services.json`**
4. Place it at: `android/app/google-services.json`

### iOS app (optional)

1. Firebase → **Add app** → **iOS**
2. Bundle ID: `com.example.cwc`
3. Download **`GoogleService-Info.plist`** → `ios/Runner/GoogleService-Info.plist`
4. Xcode → Runner → **Signing & Capabilities** → add **Push Notifications** + **Background Modes** → Remote notifications

---

## Part 2 — FlutterFire configure

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

- Select your Firebase project
- Select **Android** (and iOS if needed)
- This overwrites `lib/firebase_options.dart` with real keys

Then:

```bash
flutter pub get
flutter run
```

Login once → app saves **FCM token** to `users.fcm_token` in Supabase.

---

## Part 3 — Supabase database

Run in **SQL Editor**:

```sql
-- File: supabase/06_fcm.sql
alter table public.users add column if not exists fcm_token text;
```

Verify token saved after login:

```sql
select id, email, left(fcm_token, 20) as token_preview from public.users;
```

---

## Part 4 — Service account (server push)

1. Firebase Console → **Project settings** → **Service accounts**
2. Click **Generate new private key** → save JSON file
3. Supabase Dashboard → **Edge Functions** → **Secrets**:

| Secret name | Value |
|-------------|--------|
| `FIREBASE_SERVICE_ACCOUNT` | Entire JSON file contents (one line is fine) |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-set for Edge Functions.

---

## Part 5 — Deploy Edge Function

Install [Supabase CLI](https://supabase.com/docs/guides/cli), then:

```bash
cd c:\FYP\cwc
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy send-fcm --no-verify-jwt
```

`--no-verify-jwt` is required for **Database Webhooks** (they don't send a user JWT).

---

## Part 6 — Database Webhook (auto push on new notification)

Supabase Dashboard → **Database** → **Webhooks** → **Create webhook**

| Field | Value |
|-------|--------|
| Name | `send-fcm-on-notification` |
| Table | `notifications` |
| Events | **Insert** |
| Type | Supabase Edge Function |
| Function | `send-fcm` |
| HTTP method | POST |
| Timeout | 5000ms |

Now whenever a row is inserted into `notifications` (chat, booking, admin approve, etc.), FCM push is sent to that user's phone.

---

## How it works

```text
Notification inserted (Supabase)
        ↓
Database Webhook
        ↓
Edge Function send-fcm
        ↓
Looks up users.fcm_token
        ↓
FCM → Phone notification bar + sound
```

App also keeps **Realtime + local notifications** as backup when app is open.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build fails on Android | Add `android/app/google-services.json` |
| `REPLACE_ME` in logs | Run `flutterfire configure` |
| No push when app closed | Check webhook + Edge Function logs |
| `no fcm_token` in function logs | User must login once with FCM configured |
| No sound | Check phone notification settings for CWC app |

### Test push manually

```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/send-fcm" \
  -H "Content-Type: application/json" \
  -d '{"record":{"user_id":"USER_UUID","title":"Test","message":"Hello from FCM","id":"test-1","type":"general"}}'
```

---

## Files added in this project

| File | Purpose |
|------|---------|
| `lib/firebase_options.dart` | Firebase config (from flutterfire configure) |
| `lib/services/fcm_service.dart` | Token + foreground handling |
| `lib/services/fcm_background.dart` | Background/killed app handler |
| `supabase/06_fcm.sql` | `fcm_token` column |
| `supabase/functions/send-fcm/index.ts` | Server push sender |
