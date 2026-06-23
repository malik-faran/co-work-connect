-- =========================================================================
-- FCM push notifications — add device token column
-- Run in Supabase SQL Editor
-- =========================================================================

alter table public.users
  add column if not exists fcm_token text;

create index if not exists idx_users_fcm_token
  on public.users (fcm_token)
  where fcm_token is not null;

-- Users may update their own FCM token (covered by users_update_self policy)
