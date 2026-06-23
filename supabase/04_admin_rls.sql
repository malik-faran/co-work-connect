-- =========================================================================
-- Co-Work Connect — Admin RLS Policies
-- Run AFTER 02_rls.sql
-- Allows users with role = 'admin' to manage the platform from the admin panel.
-- =========================================================================

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

-- USERS -------------------------------------------------------------------
create policy "users_update_admin"
  on public.users for update
  using (public.is_admin())
  with check (public.is_admin());

create policy "users_delete_admin"
  on public.users for delete
  using (public.is_admin());

-- WORKSPACES --------------------------------------------------------------
create policy "workspaces_update_admin"
  on public.workspaces for update
  using (public.is_admin())
  with check (public.is_admin());

create policy "workspaces_delete_admin"
  on public.workspaces for delete
  using (public.is_admin());

-- BOOKINGS ----------------------------------------------------------------
create policy "bookings_select_admin"
  on public.bookings for select
  using (public.is_admin());

create policy "bookings_update_admin"
  on public.bookings for update
  using (public.is_admin())
  with check (public.is_admin());

create policy "bookings_delete_admin"
  on public.bookings for delete
  using (public.is_admin());

-- REVIEWS -----------------------------------------------------------------
create policy "reviews_delete_admin"
  on public.reviews for delete
  using (public.is_admin());

-- COLLABORATIONS ----------------------------------------------------------
create policy "collab_update_admin"
  on public.collaborations for update
  using (public.is_admin())
  with check (public.is_admin());

create policy "collab_delete_admin"
  on public.collaborations for delete
  using (public.is_admin());

create policy "collab_resp_delete_admin"
  on public.collaboration_responses for delete
  using (public.is_admin());

-- CHAT (admin monitoring) -------------------------------------------------
create policy "chat_rooms_select_admin"
  on public.chat_rooms for select
  using (public.is_admin());

create policy "chat_rooms_delete_admin"
  on public.chat_rooms for delete
  using (public.is_admin());

create policy "chat_messages_select_admin"
  on public.chat_messages for select
  using (public.is_admin());

create policy "chat_messages_delete_admin"
  on public.chat_messages for delete
  using (public.is_admin());

-- NOTIFICATIONS -----------------------------------------------------------
create policy "notif_select_admin"
  on public.notifications for select
  using (public.is_admin());

create policy "notif_insert_admin"
  on public.notifications for insert
  with check (public.is_admin());

create policy "notif_delete_admin"
  on public.notifications for delete
  using (public.is_admin());

-- PAYMENTS ----------------------------------------------------------------
create policy "payments_select_admin"
  on public.payments for select
  using (public.is_admin());

create policy "payments_update_admin"
  on public.payments for update
  using (public.is_admin())
  with check (public.is_admin());
