-- =========================================================================
-- Staff (moderator) can update/delete notifications + audit support
-- Run AFTER 20_moderator_audit.sql
-- Safe to re-run
-- =========================================================================

drop policy if exists "notif_update_staff" on public.notifications;
create policy "notif_update_staff"
  on public.notifications for update
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists "notif_delete_staff" on public.notifications;
create policy "notif_delete_staff"
  on public.notifications for delete
  using (public.is_staff());

-- =========================================================================
-- DONE
-- =========================================================================
