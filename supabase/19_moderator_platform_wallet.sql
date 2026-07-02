-- =========================================================================
-- Moderator role + Platform payments + Wallet/Refunds
-- Run in Supabase SQL Editor AFTER 18_owner_workspace_approval.sql
-- Safe to re-run (idempotent)
-- =========================================================================

-- 1) Extend user roles ----------------------------------------------------
alter table public.users drop constraint if exists users_role_check;
alter table public.users
  add constraint users_role_check
  check (role in ('user', 'owner', 'admin', 'moderator'));

alter table public.users
  add column if not exists moderator_active boolean default true;

alter table public.users
  add column if not exists promoted_by uuid references public.users(id) on delete set null;

alter table public.users
  add column if not exists promoted_at timestamptz;

-- 2) Staff helper functions -----------------------------------------------
-- is_admin() required by is_staff(); define here if 04_admin_rls.sql was not run
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

create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users
    where id = auth.uid()
      and role = 'moderator'
      and coalesce(moderator_active, true) = true
  );
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin() or public.is_moderator();
$$;

-- 3) Protect role changes (only admin can assign admin/moderator) ---------
create or replace function public.protect_user_role_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.role is distinct from new.role then
    if not public.is_admin() then
      raise exception 'Only admins can change user roles';
    end if;
  end if;

  if public.is_moderator() and not public.is_admin() then
    if new.email is distinct from old.email
      or new.role is distinct from old.role
      or new.id is distinct from old.id
      or new.cnic_image_url is distinct from old.cnic_image_url
      or new.promoted_by is distinct from old.promoted_by
      or new.promoted_at is distinct from old.promoted_at
      or new.moderator_active is distinct from old.moderator_active
    then
      raise exception 'Moderators can only update approval and profile support fields';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_protect_user_role_change on public.users;
create trigger trg_protect_user_role_change
  before update on public.users
  for each row execute function public.protect_user_role_change();

-- 4) Platform payment accounts (CWC receives user payments) ---------------
create table if not exists public.platform_payment_accounts (
  id              uuid primary key default gen_random_uuid(),
  account_type    text not null check (account_type in ('bank', 'easypaisa', 'jazzcash')),
  account_title   text not null,
  account_number  text not null,
  bank_name       text,
  is_active       boolean not null default true,
  is_default      boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz
);

create index if not exists idx_platform_payment_accounts_active
  on public.platform_payment_accounts(is_active);

-- 5) Extend payments for platform middle-man ------------------------------
alter table public.payments
  add column if not exists payee_type text default 'platform';

alter table public.payments
  add column if not exists platform_account_id uuid
    references public.platform_payment_accounts(id) on delete set null;

alter table public.payments
  add column if not exists verified_by uuid references public.users(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'payments_payee_type_check'
  ) then
    alter table public.payments
      add constraint payments_payee_type_check
      check (payee_type is null or payee_type in ('platform', 'owner'));
  end if;
end $$;

update public.payments
set payee_type = 'owner'
where payee_type is null and owner_account_id is not null;

update public.payments
set payee_type = 'platform'
where payee_type is null;

-- 6) User wallet + refund requests ----------------------------------------
create table if not exists public.user_wallets (
  user_id     uuid primary key references public.users(id) on delete cascade,
  balance     numeric(12, 2) not null default 0 check (balance >= 0),
  currency    text not null default 'PKR',
  updated_at  timestamptz not null default now()
);

create table if not exists public.wallet_transactions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete cascade,
  amount            numeric(12, 2) not null check (amount > 0),
  txn_type          text not null check (txn_type in ('credit', 'debit')),
  reason            text not null,
  booking_id        uuid references public.bookings(id) on delete set null,
  payment_id        uuid references public.payments(id) on delete set null,
  refund_request_id uuid,
  created_by        uuid references public.users(id) on delete set null,
  created_at        timestamptz not null default now()
);

create index if not exists idx_wallet_transactions_user
  on public.wallet_transactions(user_id, created_at desc);

create table if not exists public.refund_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  booking_id    uuid not null references public.bookings(id) on delete cascade,
  payment_id    uuid references public.payments(id) on delete set null,
  amount        numeric(12, 2) not null check (amount > 0),
  reason        text,
  status        text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  processed_by  uuid references public.users(id) on delete set null,
  processed_at  timestamptz,
  admin_note    text,
  created_at    timestamptz not null default now()
);

create index if not exists idx_refund_requests_status
  on public.refund_requests(status, created_at desc);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'wallet_transactions_refund_request_id_fkey'
  ) then
    alter table public.wallet_transactions
      add constraint wallet_transactions_refund_request_id_fkey
      foreign key (refund_request_id) references public.refund_requests(id) on delete set null;
  end if;
end $$;

-- Auto-create wallet row for new users
create or replace function public.ensure_user_wallet()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_wallets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_ensure_user_wallet on public.users;
create trigger trg_ensure_user_wallet
  after insert on public.users
  for each row execute function public.ensure_user_wallet();

insert into public.user_wallets (user_id)
select id from public.users
on conflict (user_id) do nothing;

-- Wallet credit on refund approval
create or replace function public.approve_refund_to_wallet(
  p_refund_id uuid,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_refund public.refund_requests%rowtype;
begin
  if not public.is_staff() then
    raise exception 'Only staff can approve refunds';
  end if;

  select * into v_refund
  from public.refund_requests
  where id = p_refund_id
  for update;

  if not found then
    raise exception 'Refund request not found';
  end if;

  if v_refund.status <> 'pending' then
    raise exception 'Refund already processed';
  end if;

  insert into public.user_wallets (user_id, balance, updated_at)
  values (v_refund.user_id, v_refund.amount, now())
  on conflict (user_id) do update
  set balance = public.user_wallets.balance + excluded.balance,
      updated_at = now();

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, payment_id,
    refund_request_id, created_by
  ) values (
    v_refund.user_id,
    v_refund.amount,
    'credit',
    'Booking cancellation refund',
    v_refund.booking_id,
    v_refund.payment_id,
    v_refund.id,
    auth.uid()
  );

  update public.refund_requests
  set status = 'approved',
      processed_by = auth.uid(),
      processed_at = now(),
      admin_note = coalesce(p_admin_note, admin_note)
  where id = p_refund_id;

  update public.bookings
  set status = 'cancelled',
      updated_at = now()
  where id = v_refund.booking_id
    and status in ('pending', 'confirmed');
end;
$$;

create or replace function public.reject_refund_request(
  p_refund_id uuid,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_staff() then
    raise exception 'Only staff can reject refunds';
  end if;

  update public.refund_requests
  set status = 'rejected',
      processed_by = auth.uid(),
      processed_at = now(),
      admin_note = coalesce(p_admin_note, admin_note)
  where id = p_refund_id
    and status = 'pending';

  if not found then
    raise exception 'Refund request not found or already processed';
  end if;
end;
$$;

-- Staff verifies platform payment → confirm booking + notify owner
create or replace function public.staff_verify_platform_payment(
  p_payment_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
  v_booking public.bookings%rowtype;
  v_owner_id uuid;
  v_user_name text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can verify payments';
  end if;

  select * into v_payment
  from public.payments
  where id = p_payment_id
  for update;

  if not found then
    raise exception 'Payment not found';
  end if;

  if p_approve then
    update public.payments
    set status = 'completed',
        receipt_status = 'approved',
        verified_by = auth.uid(),
        owner_verified_at = now(),
        updated_at = now(),
        failure_reason = null
    where id = p_payment_id;

    select * into v_booking
    from public.bookings
    where id = v_payment.booking_id;

    if found then
      update public.bookings
      set status = 'confirmed',
          updated_at = now()
      where id = v_booking.id;

      select w.owner_id into v_owner_id
      from public.workspaces w
      where w.id = v_booking.workspace_id;

      select name into v_user_name
      from public.users
      where id = v_payment.user_id;

      if v_owner_id is not null then
        insert into public.notifications (user_id, title, message, type, metadata)
        values (
          v_owner_id,
          'Payment verified — booking confirmed',
          coalesce(v_user_name, 'A user') || ' paid for ' || coalesce(v_booking.workspace_name, 'your workspace') || '. CWC verified the payment.',
          'payment_verified',
          jsonb_build_object(
            'booking_id', v_booking.id,
            'payment_id', p_payment_id
          )
        );
      end if;

      insert into public.notifications (user_id, title, message, type, metadata)
      values (
        v_payment.user_id,
        'Payment approved',
        'Your payment was verified. Booking confirmed!',
        'payment_approved',
        jsonb_build_object(
          'booking_id', v_booking.id,
          'payment_id', p_payment_id
        )
      );
    end if;
  else
    update public.payments
    set receipt_status = 'rejected',
        failure_reason = coalesce(p_reason, 'Receipt rejected by CWC team'),
        updated_at = now(),
        verified_by = auth.uid()
    where id = p_payment_id;

    insert into public.notifications (user_id, title, message, type, metadata)
    values (
      v_payment.user_id,
      'Payment receipt rejected',
      coalesce(p_reason, 'Your receipt was rejected. Please upload a valid receipt.'),
      'payment_rejected',
      jsonb_build_object(
        'booking_id', v_payment.booking_id,
        'payment_id', p_payment_id
      )
    );
  end if;
end;
$$;

-- Admin promotes/demotes moderators
create or replace function public.admin_set_moderator(
  p_user_id uuid,
  p_make_moderator boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can manage moderators';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Cannot change your own role';
  end if;

  if p_make_moderator then
    update public.users
    set role = 'moderator',
        moderator_active = true,
        promoted_by = auth.uid(),
        promoted_at = now(),
        updated_at = now()
    where id = p_user_id
      and role = 'user';
  else
    update public.users
    set role = 'user',
        moderator_active = false,
        updated_at = now()
    where id = p_user_id
      and role = 'moderator';
  end if;

  if not found then
    raise exception 'User not found or invalid role transition';
  end if;
end;
$$;

-- 7) RLS — platform accounts ----------------------------------------------
alter table public.platform_payment_accounts enable row level security;

drop policy if exists "platform_accounts_select_active" on public.platform_payment_accounts;
create policy "platform_accounts_select_active"
  on public.platform_payment_accounts for select
  using (is_active = true or public.is_admin());

drop policy if exists "platform_accounts_admin_all" on public.platform_payment_accounts;
create policy "platform_accounts_admin_all"
  on public.platform_payment_accounts for all
  using (public.is_admin())
  with check (public.is_admin());

-- 8) RLS — wallets --------------------------------------------------------
alter table public.user_wallets enable row level security;

drop policy if exists "wallet_select_self" on public.user_wallets;
create policy "wallet_select_self"
  on public.user_wallets for select
  using (auth.uid() = user_id or public.is_staff());

drop policy if exists "wallet_staff_update" on public.user_wallets;
create policy "wallet_staff_update"
  on public.user_wallets for update
  using (public.is_staff())
  with check (public.is_staff());

alter table public.wallet_transactions enable row level security;

drop policy if exists "wallet_txn_select_self" on public.wallet_transactions;
create policy "wallet_txn_select_self"
  on public.wallet_transactions for select
  using (auth.uid() = user_id or public.is_staff());

drop policy if exists "wallet_txn_insert_staff" on public.wallet_transactions;
create policy "wallet_txn_insert_staff"
  on public.wallet_transactions for insert
  with check (public.is_staff() or auth.uid() = user_id);

alter table public.refund_requests enable row level security;

drop policy if exists "refund_select_self" on public.refund_requests;
create policy "refund_select_self"
  on public.refund_requests for select
  using (auth.uid() = user_id or public.is_staff());

drop policy if exists "refund_insert_self" on public.refund_requests;
create policy "refund_insert_self"
  on public.refund_requests for insert
  with check (auth.uid() = user_id);

drop policy if exists "refund_update_staff" on public.refund_requests;
create policy "refund_update_staff"
  on public.refund_requests for update
  using (public.is_staff())
  with check (public.is_staff());

-- 9) Staff RLS (moderator + admin) — mirror admin policies ----------------
-- USERS
drop policy if exists "users_update_staff" on public.users;
create policy "users_update_staff"
  on public.users for update
  using (public.is_staff())
  with check (public.is_staff());

drop policy if exists "users_select_staff" on public.users;
create policy "users_select_staff"
  on public.users for select
  using (public.is_staff());

-- WORKSPACES
drop policy if exists "workspaces_update_staff" on public.workspaces;
create policy "workspaces_update_staff"
  on public.workspaces for update
  using (public.is_staff())
  with check (public.is_staff());

-- BOOKINGS
drop policy if exists "bookings_select_staff" on public.bookings;
create policy "bookings_select_staff"
  on public.bookings for select
  using (public.is_staff());

drop policy if exists "bookings_update_staff" on public.bookings;
create policy "bookings_update_staff"
  on public.bookings for update
  using (public.is_staff())
  with check (public.is_staff());

-- PAYMENTS
drop policy if exists "payments_select_staff" on public.payments;
create policy "payments_select_staff"
  on public.payments for select
  using (public.is_staff());

drop policy if exists "payments_update_staff" on public.payments;
create policy "payments_update_staff"
  on public.payments for update
  using (public.is_staff())
  with check (public.is_staff());

-- NOTIFICATIONS
drop policy if exists "notif_select_staff" on public.notifications;
create policy "notif_select_staff"
  on public.notifications for select
  using (public.is_staff());

drop policy if exists "notif_insert_staff" on public.notifications;
create policy "notif_insert_staff"
  on public.notifications for insert
  with check (public.is_staff());

-- REVIEWS (moderator can delete abusive reviews)
drop policy if exists "reviews_delete_staff" on public.reviews;
create policy "reviews_delete_staff"
  on public.reviews for delete
  using (public.is_staff());

-- COLLABORATIONS
drop policy if exists "collab_update_staff" on public.collaborations;
create policy "collab_update_staff"
  on public.collaborations for update
  using (public.is_staff())
  with check (public.is_staff());

-- Pay booking from wallet (user self)
create or replace function public.pay_booking_from_wallet(
  p_booking_id uuid,
  p_amount numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_balance numeric;
  v_booking public.bookings%rowtype;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then
    raise exception 'Booking not found';
  end if;
  if v_booking.user_id <> v_user_id then
    raise exception 'Not your booking';
  end if;

  select balance into v_balance
  from public.user_wallets
  where user_id = v_user_id
  for update;

  if v_balance is null or v_balance < p_amount then
    raise exception 'Insufficient wallet balance';
  end if;

  update public.user_wallets
  set balance = balance - p_amount,
      updated_at = now()
  where user_id = v_user_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, created_by
  ) values (
    v_user_id, p_amount, 'debit', 'Booking payment from wallet', p_booking_id, v_user_id
  );

  update public.bookings
  set status = 'confirmed',
      updated_at = now()
  where id = p_booking_id;
end;
$$;

grant execute on function public.pay_booking_from_wallet(uuid, numeric) to authenticated;
grant execute on function public.staff_verify_platform_payment(uuid, boolean, text) to authenticated;
grant execute on function public.approve_refund_to_wallet(uuid, text) to authenticated;
grant execute on function public.reject_refund_request(uuid, text) to authenticated;
grant execute on function public.admin_set_moderator(uuid, boolean) to authenticated;

-- Allow wallet payment method
alter table public.payments drop constraint if exists payments_payment_method_check;
alter table public.payments
  add constraint payments_payment_method_check
  check (payment_method in ('stripe', 'manual', 'cash', 'wallet'));

-- Default platform account (edit details in admin panel after run)
insert into public.platform_payment_accounts (
  account_type, account_title, account_number, bank_name, is_active, is_default
)
select 'easypaisa', 'Co-Work Connect', '03001234567', null, true, true
where not exists (select 1 from public.platform_payment_accounts where is_default = true);

-- =========================================================================
-- DONE — After run:
-- 1) Admin panel → Platform Accounts: update real JazzCash/EasyPaisa/Bank details
-- 2) Admin panel → Moderators: promote existing users to moderator
-- 3) Login as moderator at admin panel (web only)
-- =========================================================================
