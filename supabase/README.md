# Supabase Setup — Co-Work Connect

Follow these steps **in order**. Each SQL file is idempotent and safe to re-run.

## 0) Prerequisites

- A Supabase project (free tier is fine).
- Project URL + anon key already wired into `lib/services/supabase_service.dart`.

## 1) Enable Email Auth

Dashboard -> **Authentication -> Providers -> Email**

- Enable "Email" provider.
- Turn **"Confirm email"** ON (required — the app gates users on email verification).
- (Optional) Customize the "Confirm signup" and "Reset password" templates.

## 2) Redirect URLs (for deep links to work)

Dashboard -> **Authentication -> URL Configuration -> Redirect URLs**

Add (example values — adjust to your bundle):

```
io.supabase.cwc://login-callback/
cwc://reset-password/
http://localhost:3000/*
```

## 3) Run SQL files (in this order)

Open **SQL Editor -> New query**, paste and run each file:

1. `supabase/01_schema.sql` — tables, indexes, triggers.
2. `supabase/02_rls.sql` — Row Level Security policies.
3. `supabase/03_storage.sql` — storage buckets + policies.
4. `supabase/04_admin_rls.sql` — admin panel access policies.

## 4) Create an admin account

1. In Supabase Dashboard → **Authentication → Users**, create a user (e.g. `admin@cwc.com`) with a strong password.
2. In **SQL Editor**, promote that user to admin:

```sql
update public.users
set role = 'admin', name = 'Admin User'
where email = 'admin@cwc.com';
```

3. Start the admin panel: `cd admin-panel && npm run dev`
4. Log in with the admin email/password (Supabase Auth — not hardcoded credentials).

## 5) Verify

```sql
-- tables + policies exist?
select schemaname, tablename, rowsecurity from pg_tables
  where schemaname = 'public' order by tablename;

select schemaname, tablename, policyname from pg_policies
  where schemaname = 'public' order by tablename, policyname;

-- buckets exist?
select id, name, public from storage.buckets;
```

## 6) Quick smoke tests

- **Signup**: create an account in the app → you should get a confirmation email. The app shows `EmailVerificationScreen` until you click the link.
- **Login pre-verification**: should fail with "Please verify your email…".
- **Login post-verification**: lands on Home.
- **Forgot password**: emails a reset link to the user.
- **Users.select**: you can see other users (needed for Fiverr-style discovery) but you can only update your own row.
- **Workspaces.insert**: only allowed when `auth.uid() = owner_id` (RLS).
- **Bookings**: user sees only their bookings + owners see bookings on their workspaces.

## 7) Where data lives

| Feature            | Table(s)                                        |
|--------------------|-------------------------------------------------|
| Auth account       | `auth.users` (managed by Supabase)              |
| Public profile     | `public.users` (mirrored via trigger)           |
| Workspaces         | `public.workspaces`                             |
| Bookings           | `public.bookings`                               |
| Reviews / ratings  | `public.reviews` (auto-refreshes workspace avg) |
| Collaborations     | `public.collaborations`, `public.collaboration_responses` |
| Chat               | `public.chat_rooms`, `public.chat_messages`     |
| Notifications      | `public.notifications`                          |
| Payments           | `public.payments`                               |
| Images / files     | storage buckets: `profile_images`, `workspace_images`, `chat_files` |

## 8) Resetting / wiping data (dev only)

```sql
-- DROP everything (DEV ONLY!):
drop table if exists public.payments, public.notifications,
  public.chat_messages, public.chat_rooms,
  public.collaboration_responses, public.collaborations,
  public.reviews, public.bookings, public.workspaces, public.users cascade;
```

Then re-run `01 -> 02 -> 03 -> 04 -> 06`.

## 9) Push notifications (FCM)

See **`supabase/FCM_SETUP.md`** for full Firebase + Edge Function setup.
