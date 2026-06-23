-- =========================================================================
-- Co-Work Connect — PAYMENT ONLY (single script)
-- Bank / EasyPaisa / JazzCash + receipt upload + owner verify
-- Paste full file in Supabase → SQL Editor → Run
-- Safe to re-run (idempotent where possible)
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1) Owner payment accounts
-- -------------------------------------------------------------------------
create table if not exists public.owner_payment_accounts (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references public.users(id) on delete cascade,
  workspace_id    uuid references public.workspaces(id) on delete set null,
  account_type    text not null check (account_type in ('bank', 'easypaisa', 'jazzcash')),
  account_title   text not null,
  account_number  text not null,
  bank_name       text,
  is_active       boolean not null default true,
  is_default      boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz
);

create index if not exists idx_owner_payment_accounts_owner
  on public.owner_payment_accounts(owner_id);

-- -------------------------------------------------------------------------
-- 2) Extend payments table (manual transfer + receipt)
-- -------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------
-- 3) Notification types for payment receipt flow
-- -------------------------------------------------------------------------
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
    'booking_cancelled',
    'payment_receipt',
    'payment_rejected'
  ]::text[]));

-- -------------------------------------------------------------------------
-- 4) RLS — owner_payment_accounts
-- -------------------------------------------------------------------------
alter table public.owner_payment_accounts enable row level security;

drop policy if exists "owner_accounts_select" on public.owner_payment_accounts;
create policy "owner_accounts_select"
  on public.owner_payment_accounts for select
  using (auth.uid() = owner_id);

drop policy if exists "owner_accounts_insert" on public.owner_payment_accounts;
create policy "owner_accounts_insert"
  on public.owner_payment_accounts for insert
  with check (auth.uid() = owner_id);

drop policy if exists "owner_accounts_update" on public.owner_payment_accounts;
create policy "owner_accounts_update"
  on public.owner_payment_accounts for update
  using (auth.uid() = owner_id);

drop policy if exists "owner_accounts_delete" on public.owner_payment_accounts;
create policy "owner_accounts_delete"
  on public.owner_payment_accounts for delete
  using (auth.uid() = owner_id);

-- Users see active owner accounts when paying for a booking
drop policy if exists "owner_accounts_select_for_booking" on public.owner_payment_accounts;
create policy "owner_accounts_select_for_booking"
  on public.owner_payment_accounts for select
  using (is_active = true and auth.role() = 'authenticated');

-- -------------------------------------------------------------------------
-- 5) RLS — owner can approve/reject manual payments
-- -------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------
-- 6) Storage — payment receipt screenshots
-- Path: payment_receipts/{user_id}/{booking_id}/file.jpg
-- -------------------------------------------------------------------------
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
  );

drop policy if exists "payment_receipts_delete" on storage.objects;
create policy "payment_receipts_delete"
  on storage.objects for delete
  using (
    bucket_id = 'payment_receipts'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- =========================================================================
-- DONE — Payment feature ready
-- =========================================================================
