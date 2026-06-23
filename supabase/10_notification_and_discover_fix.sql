-- =========================================================================
-- Co-Work Connect — Notification insert + public discover backfill
-- Run once in Supabase SQL Editor after 09_collaboration_hub.sql
-- =========================================================================

-- 1) Allow authenticated users to send notifications to other users
--    (invites, applications, chat, bookings, etc.)
drop policy if exists "notif_insert_authenticated" on public.notifications;
create policy "notif_insert_authenticated"
  on public.notifications for insert
  to authenticated
  with check (auth.uid() is not null);

-- 2) Backfill legacy rows so public projects appear in Discover
update public.collaborations
   set visibility = 'public'
 where visibility is null;

update public.collaborations
   set status = 'recruiting'
 where status = 'open';
