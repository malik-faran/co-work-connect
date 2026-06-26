-- =========================================================================
-- Co-Work Connect — Payment flow fixes (safe to re-run)
-- Run in Supabase SQL Editor if payment method switch or receipt upload fails.
-- =========================================================================

-- 1) Ensure manual-payment columns exist on payments
alter table public.payments
  add column if not exists receipt_url text;

alter table public.payments
  add column if not exists receipt_status text;

alter table public.payments
  add column if not exists owner_account_id uuid
    references public.owner_payment_accounts(id) on delete set null;

alter table public.payments
  add column if not exists transfer_reference text;

alter table public.payments
  add column if not exists owner_verified_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'payments_receipt_status_check'
  ) then
    alter table public.payments
      add constraint payments_receipt_status_check
      check (receipt_status is null or receipt_status in (
        'awaiting_upload',
        'awaiting_verification',
        'approved',
        'rejected'
      ));
  end if;
end $$;

-- 1b) Allow bank / EasyPaisa manual payments (app uses payment_method = 'manual')
alter table public.payments drop constraint if exists payments_payment_method_check;

alter table public.payments
  add constraint payments_payment_method_check
  check (payment_method in ('stripe', 'manual', 'cash'));

-- 2) Notification types — must include collaboration hub + payment types
--    (narrow lists fail if rows already use types from 09_collaboration_hub.sql)
update public.notifications
set type = 'general'
where type not in (
  'general',
  'registration_approved',
  'registration_rejected',
  'owner_approved',
  'owner_rejected',
  'collaboration_response',
  'collaboration_accepted',
  'collaboration_rejected',
  'collaboration_application',
  'collaboration_shortlisted',
  'collaboration_launched',
  'collaboration_invite',
  'collaboration_join_request',
  'collaboration_completed',
  'collaboration_milestone',
  'chat_message',
  'booking_confirmed',
  'booking_cancelled',
  'payment_receipt',
  'payment_rejected'
);

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
    'collaboration_application',
    'collaboration_shortlisted',
    'collaboration_launched',
    'collaboration_invite',
    'collaboration_join_request',
    'collaboration_completed',
    'collaboration_milestone',
    'chat_message',
    'booking_confirmed',
    'booking_cancelled',
    'payment_receipt',
    'payment_rejected'
  ]::text[]));

-- 3) Users can update their own payments (method switch + receipt upload)
drop policy if exists "payments_update_self" on public.payments;
create policy "payments_update_self"
  on public.payments for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 4) Payers can read active owner bank accounts
drop policy if exists "owner_accounts_select_for_booking" on public.owner_payment_accounts;
create policy "owner_accounts_select_for_booking"
  on public.owner_payment_accounts for select
  using (is_active = true and auth.role() = 'authenticated');

-- 5) Payment receipt storage (re-applies if 03_storage.sql wiped policies)
insert into storage.buckets (id, name, public)
values ('payment_receipts', 'payment_receipts', true)
on conflict (id) do update set public = true;

drop policy if exists "payment_receipts_read" on storage.objects;
create policy "payment_receipts_read"
  on storage.objects for select
  using (bucket_id = 'payment_receipts');

drop policy if exists "payment_receipts_write" on storage.objects;
create policy "payment_receipts_write"
  on storage.objects for insert
  with check (
    bucket_id = 'payment_receipts'
    and auth.role() = 'authenticated'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "payment_receipts_update" on storage.objects;
create policy "payment_receipts_update"
  on storage.objects for update
  using (
    bucket_id = 'payment_receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'payment_receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "payment_receipts_delete" on storage.objects;
create policy "payment_receipts_delete"
  on storage.objects for delete
  using (
    bucket_id = 'payment_receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- =========================================================================
-- DONE
-- =========================================================================
