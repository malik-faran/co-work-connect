-- =========================================================================
-- Co-Work Connect — Row Level Security (RLS) Policies
-- Run this file AFTER 01_schema.sql.
-- All policies ensure users can access ONLY their own data + public reads.
-- =========================================================================

-- Enable RLS on every public table ----------------------------------------
alter table public.users                   enable row level security;
alter table public.workspaces              enable row level security;
alter table public.bookings                enable row level security;
alter table public.reviews                 enable row level security;
alter table public.collaborations          enable row level security;
alter table public.collaboration_responses enable row level security;
alter table public.chat_rooms              enable row level security;
alter table public.chat_messages           enable row level security;
alter table public.notifications           enable row level security;
alter table public.payments                enable row level security;

-- Drop existing (re-run safety) -------------------------------------------
do $$
declare r record;
begin
  for r in
    select tablename, policyname
    from pg_policies
    where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on public.%I;', r.policyname, r.tablename);
  end loop;
end $$;

-- =========================================================================
-- USERS : public can read profiles (for Fiverr-style discovery);
--         users may only update/delete their own row.
-- =========================================================================
create policy "users_select_public"
  on public.users for select
  using (true);

create policy "users_insert_self"
  on public.users for insert
  with check (auth.uid() = id);

create policy "users_update_self"
  on public.users for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "users_delete_self"
  on public.users for delete
  using (auth.uid() = id);

-- =========================================================================
-- WORKSPACES : public read; owners write/update/delete their own.
-- =========================================================================
create policy "workspaces_select_public"
  on public.workspaces for select
  using (true);

create policy "workspaces_insert_owner"
  on public.workspaces for insert
  with check (auth.uid() = owner_id);

create policy "workspaces_update_owner"
  on public.workspaces for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "workspaces_delete_owner"
  on public.workspaces for delete
  using (auth.uid() = owner_id);

-- =========================================================================
-- BOOKINGS : users see their own; owners see bookings on their workspaces.
-- =========================================================================
create policy "bookings_select_self_or_owner"
  on public.bookings for select
  using (
    auth.uid() = user_id
    or auth.uid() in (select owner_id from public.workspaces where id = workspace_id)
  );

create policy "bookings_insert_self"
  on public.bookings for insert
  with check (auth.uid() = user_id);

create policy "bookings_update_self_or_owner"
  on public.bookings for update
  using (
    auth.uid() = user_id
    or auth.uid() in (select owner_id from public.workspaces where id = workspace_id)
  )
  with check (
    auth.uid() = user_id
    or auth.uid() in (select owner_id from public.workspaces where id = workspace_id)
  );

create policy "bookings_delete_self"
  on public.bookings for delete
  using (auth.uid() = user_id);

-- =========================================================================
-- REVIEWS : public read, only the booking's user may write/update/delete.
-- =========================================================================
create policy "reviews_select_public"
  on public.reviews for select
  using (true);

create policy "reviews_insert_self"
  on public.reviews for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.bookings
      where id = booking_id
        and user_id = auth.uid()
        and status in ('confirmed','completed')
    )
  );

create policy "reviews_update_self"
  on public.reviews for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "reviews_delete_self"
  on public.reviews for delete
  using (auth.uid() = user_id);

-- =========================================================================
-- COLLABORATIONS : public read, only author writes/updates/deletes.
-- =========================================================================
create policy "collab_select_public"
  on public.collaborations for select
  using (true);

create policy "collab_insert_self"
  on public.collaborations for insert
  with check (auth.uid() = user_id);

create policy "collab_update_self"
  on public.collaborations for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "collab_delete_self"
  on public.collaborations for delete
  using (auth.uid() = user_id);

-- Collaboration responses : visible to responder and collab owner.
create policy "collab_resp_select_participants"
  on public.collaboration_responses for select
  using (
    auth.uid() = user_id
    or auth.uid() in (select user_id from public.collaborations where id = collaboration_id)
  );

create policy "collab_resp_insert_self"
  on public.collaboration_responses for insert
  with check (auth.uid() = user_id);

create policy "collab_resp_update_participants"
  on public.collaboration_responses for update
  using (
    auth.uid() = user_id
    or auth.uid() in (select user_id from public.collaborations where id = collaboration_id)
  )
  with check (
    auth.uid() = user_id
    or auth.uid() in (select user_id from public.collaborations where id = collaboration_id)
  );

create policy "collab_resp_delete_self"
  on public.collaboration_responses for delete
  using (auth.uid() = user_id);

-- =========================================================================
-- CHAT : only participants can see or write to a chat room/message.
-- =========================================================================
create policy "chat_rooms_select_participants"
  on public.chat_rooms for select
  using (auth.uid() = user1_id or auth.uid() = user2_id);

create policy "chat_rooms_insert_participant"
  on public.chat_rooms for insert
  with check (auth.uid() = user1_id or auth.uid() = user2_id);

create policy "chat_rooms_update_participants"
  on public.chat_rooms for update
  using (auth.uid() = user1_id or auth.uid() = user2_id)
  with check (auth.uid() = user1_id or auth.uid() = user2_id);

create policy "chat_messages_select_participants"
  on public.chat_messages for select
  using (
    exists (
      select 1 from public.chat_rooms r
      where r.id = chat_room_id
        and (auth.uid() = r.user1_id or auth.uid() = r.user2_id)
    )
  );

create policy "chat_messages_insert_self"
  on public.chat_messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.chat_rooms r
      where r.id = chat_room_id
        and (auth.uid() = r.user1_id or auth.uid() = r.user2_id)
    )
  );

create policy "chat_messages_update_sender"
  on public.chat_messages for update
  using (auth.uid() = sender_id)
  with check (auth.uid() = sender_id);

-- =========================================================================
-- NOTIFICATIONS : user can only see / mark-read their own.
-- =========================================================================
create policy "notif_select_self"
  on public.notifications for select
  using (auth.uid() = user_id);

create policy "notif_insert_self"
  on public.notifications for insert
  with check (auth.uid() = user_id);

create policy "notif_update_self"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "notif_delete_self"
  on public.notifications for delete
  using (auth.uid() = user_id);

-- =========================================================================
-- PAYMENTS : only booking user or workspace owner can see payment.
-- =========================================================================
create policy "payments_select_user_or_owner"
  on public.payments for select
  using (
    auth.uid() = user_id
    or auth.uid() in (
      select w.owner_id
      from public.bookings b join public.workspaces w on w.id = b.workspace_id
      where b.id = booking_id
    )
  );

create policy "payments_insert_self"
  on public.payments for insert
  with check (auth.uid() = user_id);

create policy "payments_update_self"
  on public.payments for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
