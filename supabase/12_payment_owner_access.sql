-- =========================================================================
-- Co-Work Connect — Owner read access for bookings & payments
-- Run once in Supabase SQL Editor (safe to re-run / idempotent)
--
-- Fixes:
--   * Owner could not see uploaded payment receipts (Received section empty)
--   * Owner payment history empty
-- Root cause: missing SELECT policies letting a workspace owner read the
-- bookings + payments that belong to their workspaces.
-- =========================================================================

-- 1) Owners (and the booking user) can read bookings on their workspaces
drop policy if exists "bookings_select_self_or_owner" on public.bookings;
create policy "bookings_select_self_or_owner"
  on public.bookings for select
  using (
    auth.uid() = user_id
    or auth.uid() in (
      select owner_id from public.workspaces where id = bookings.workspace_id
    )
  );

-- 2) Owners (and the payer) can read payments for their workspace bookings
drop policy if exists "payments_select_user_or_owner" on public.payments;
create policy "payments_select_user_or_owner"
  on public.payments for select
  using (
    auth.uid() = user_id
    or auth.uid() in (
      select w.owner_id
      from public.bookings b
      join public.workspaces w on w.id = b.workspace_id
      where b.id = payments.booking_id
    )
  );

-- 3) Owners can update (approve/reject) payments for their workspace bookings
drop policy if exists "payments_update_owner_verify" on public.payments;
create policy "payments_update_owner_verify"
  on public.payments for update
  using (
    exists (
      select 1
      from public.bookings b
      join public.workspaces w on w.id = b.workspace_id
      where b.id = payments.booking_id
        and w.owner_id = auth.uid()
    )
  );

-- =========================================================================
-- DONE
-- =========================================================================
