-- =========================================================================
-- Co-Work Connect — Run on YOUR existing Supabase database
-- Safe to paste in SQL Editor. Adjust admin email if needed.
-- =========================================================================

-- 1) Admin helper function
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where id = auth.uid() and role = 'admin'
  );
$$;

-- 2) Allow all notification types used by app + admin panel
alter table public.notifications drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'general',
    'registration_approved',
    'registration_rejected',
    'owner_approved',
    'owner_rejected',
    'collaboration_response',
    'collaboration_accepted',
    'collaboration_rejected',
    'chat_message',
    'booking_confirmed',
    'booking_cancelled'
  ]::text[]));

-- 3) Optional: column used by user profile (skip if already exists)
alter table public.users
  add column if not exists collaboration_requests text[] default '{}';

-- 3b) FCM device token for push notifications
alter table public.users
  add column if not exists fcm_token text;

create index if not exists idx_users_fcm_token
  on public.users (fcm_token)
  where fcm_token is not null;

-- =========================================================================
-- 4) Admin RLS policies (uses your table name: messages)
-- =========================================================================

-- USERS
drop policy if exists "users_update_admin" on public.users;
create policy "users_update_admin"
  on public.users for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "users_delete_admin" on public.users;
create policy "users_delete_admin"
  on public.users for delete
  using (public.is_admin());

-- WORKSPACES
drop policy if exists "workspaces_update_admin" on public.workspaces;
create policy "workspaces_update_admin"
  on public.workspaces for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "workspaces_delete_admin" on public.workspaces;
create policy "workspaces_delete_admin"
  on public.workspaces for delete
  using (public.is_admin());

-- BOOKINGS
drop policy if exists "bookings_select_admin" on public.bookings;
create policy "bookings_select_admin"
  on public.bookings for select
  using (public.is_admin());

drop policy if exists "bookings_update_admin" on public.bookings;
create policy "bookings_update_admin"
  on public.bookings for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "bookings_delete_admin" on public.bookings;
create policy "bookings_delete_admin"
  on public.bookings for delete
  using (public.is_admin());

-- REVIEWS
drop policy if exists "reviews_delete_admin" on public.reviews;
create policy "reviews_delete_admin"
  on public.reviews for delete
  using (public.is_admin());

-- COLLABORATIONS
drop policy if exists "collab_update_admin" on public.collaborations;
create policy "collab_update_admin"
  on public.collaborations for update
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "collab_delete_admin" on public.collaborations;
create policy "collab_delete_admin"
  on public.collaborations for delete
  using (public.is_admin());

drop policy if exists "collab_resp_delete_admin" on public.collaboration_responses;
create policy "collab_resp_delete_admin"
  on public.collaboration_responses for delete
  using (public.is_admin());

-- CHAT (your table is public.messages)
drop policy if exists "chat_rooms_select_admin" on public.chat_rooms;
create policy "chat_rooms_select_admin"
  on public.chat_rooms for select
  using (public.is_admin());

drop policy if exists "chat_rooms_delete_admin" on public.chat_rooms;
create policy "chat_rooms_delete_admin"
  on public.chat_rooms for delete
  using (public.is_admin());

drop policy if exists "messages_select_admin" on public.messages;
create policy "messages_select_admin"
  on public.messages for select
  using (public.is_admin());

drop policy if exists "messages_delete_admin" on public.messages;
create policy "messages_delete_admin"
  on public.messages for delete
  using (public.is_admin());

-- NOTIFICATIONS
drop policy if exists "notif_select_admin" on public.notifications;
create policy "notif_select_admin"
  on public.notifications for select
  using (public.is_admin());

drop policy if exists "notif_insert_admin" on public.notifications;
create policy "notif_insert_admin"
  on public.notifications for insert
  with check (public.is_admin());

drop policy if exists "notif_delete_admin" on public.notifications;
create policy "notif_delete_admin"
  on public.notifications for delete
  using (public.is_admin());

-- PAYMENTS
drop policy if exists "payments_select_admin" on public.payments;
create policy "payments_select_admin"
  on public.payments for select
  using (public.is_admin());

drop policy if exists "payments_update_admin" on public.payments;
create policy "payments_update_admin"
  on public.payments for update
  using (public.is_admin())
  with check (public.is_admin());

-- =========================================================================
-- 5) Create admin user (run AFTER creating user in Auth dashboard)
-- =========================================================================
-- update public.users
-- set role = 'admin', name = 'Admin User'
-- where email = 'admin@cwc.com';
