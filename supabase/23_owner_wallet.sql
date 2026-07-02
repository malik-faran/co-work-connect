-- =========================================================================
-- Owner wallet: auto-credit on payment verify (minus platform fee) + payouts
-- Run AFTER 22_user_reports.sql
-- Safe to re-run
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1) Platform fee setting
-- -------------------------------------------------------------------------
create table if not exists public.platform_settings (
  key         text primary key,
  value       text not null,
  updated_at  timestamptz not null default now()
);

insert into public.platform_settings (key, value)
values ('platform_fee_percent', '10')
on conflict (key) do nothing;

alter table public.platform_settings enable row level security;

drop policy if exists "platform_settings_select_all" on public.platform_settings;
create policy "platform_settings_select_all"
  on public.platform_settings for select
  using (true);

drop policy if exists "platform_settings_admin" on public.platform_settings;
create policy "platform_settings_admin"
  on public.platform_settings for all
  using (public.is_admin())
  with check (public.is_admin());

-- -------------------------------------------------------------------------
-- 2) Track owner earnings on payments
-- -------------------------------------------------------------------------
alter table public.payments
  add column if not exists platform_fee_amount numeric(12, 2);

alter table public.payments
  add column if not exists owner_earning_amount numeric(12, 2);

alter table public.payments
  add column if not exists owner_earning_credited boolean not null default false;

-- -------------------------------------------------------------------------
-- 3) Owner payout (withdraw) requests
-- -------------------------------------------------------------------------
create table if not exists public.owner_payout_requests (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null references public.users(id) on delete cascade,
  owner_account_id  uuid not null references public.owner_payment_accounts(id) on delete restrict,
  amount            numeric(12, 2) not null check (amount > 0),
  status            text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  processed_by      uuid references public.users(id) on delete set null,
  processed_at      timestamptz,
  admin_note        text,
  created_at        timestamptz not null default now()
);

create index if not exists idx_owner_payout_requests_status
  on public.owner_payout_requests(status, created_at desc);

alter table public.owner_payout_requests enable row level security;

drop policy if exists "owner_payout_select_self" on public.owner_payout_requests;
create policy "owner_payout_select_self"
  on public.owner_payout_requests for select
  using (auth.uid() = owner_id);

drop policy if exists "owner_payout_insert_self" on public.owner_payout_requests;
create policy "owner_payout_insert_self"
  on public.owner_payout_requests for insert
  with check (
    auth.uid() = owner_id
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.role = 'owner'
    )
  );

drop policy if exists "owner_payout_select_staff" on public.owner_payout_requests;
create policy "owner_payout_select_staff"
  on public.owner_payout_requests for select
  using (public.is_staff());

drop policy if exists "owner_payout_update_staff" on public.owner_payout_requests;
create policy "owner_payout_update_staff"
  on public.owner_payout_requests for update
  using (public.is_staff())
  with check (public.is_staff());

-- -------------------------------------------------------------------------
-- 4) Helpers
-- -------------------------------------------------------------------------
create or replace function public.get_platform_fee_percent()
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select value::numeric from public.platform_settings where key = 'platform_fee_percent'),
    10::numeric
  );
$$;

create or replace function public.credit_owner_booking_earning(
  p_owner_id uuid,
  p_payment_id uuid,
  p_booking_id uuid,
  p_gross_amount numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fee_percent numeric;
  v_fee numeric;
  v_net numeric;
  v_booking_name text;
begin
  if p_owner_id is null or p_gross_amount is null or p_gross_amount <= 0 then
    return;
  end if;

  if exists (
    select 1 from public.payments
    where id = p_payment_id and owner_earning_credited = true
  ) then
    return;
  end if;

  v_fee_percent := public.get_platform_fee_percent();
  v_fee := round(p_gross_amount * v_fee_percent / 100, 2);
  v_net := round(p_gross_amount - v_fee, 2);

  if v_net <= 0 then
    return;
  end if;

  insert into public.user_wallets (user_id, balance, updated_at)
  values (p_owner_id, v_net, now())
  on conflict (user_id) do update
  set balance = public.user_wallets.balance + excluded.balance,
      updated_at = now();

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, payment_id, created_by
  ) values (
    p_owner_id,
    v_net,
    'credit',
    'Booking earning (platform fee ' || v_fee_percent::text || '% deducted)',
    p_booking_id,
    p_payment_id,
    null
  );

  update public.payments
  set platform_fee_amount = v_fee,
      owner_earning_amount = v_net,
      owner_earning_credited = true,
      updated_at = now()
  where id = p_payment_id;

  select workspace_name into v_booking_name
  from public.bookings where id = p_booking_id;

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    p_owner_id,
    'Earning credited to wallet',
    'PKR ' || v_net::text || ' added to your owner wallet for '
      || coalesce(v_booking_name, 'a booking')
      || ' (after ' || v_fee_percent::text || '% platform fee).',
    'owner_earning_credited',
    jsonb_build_object(
      'booking_id', p_booking_id,
      'payment_id', p_payment_id,
      'net_amount', v_net,
      'platform_fee', v_fee
    )
  );
end;
$$;

create or replace function public.reverse_owner_booking_earning(
  p_payment_id uuid,
  p_booking_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
  v_owner_id uuid;
  v_balance numeric;
begin
  select * into v_payment from public.payments where id = p_payment_id;
  if not found or not v_payment.owner_earning_credited then
    return;
  end if;

  select w.owner_id into v_owner_id
  from public.bookings b
  join public.workspaces w on w.id = b.workspace_id
  where b.id = p_booking_id;

  if v_owner_id is null or v_payment.owner_earning_amount is null then
    return;
  end if;

  select balance into v_balance
  from public.user_wallets
  where user_id = v_owner_id
  for update;

  if coalesce(v_balance, 0) < v_payment.owner_earning_amount then
    raise exception 'Owner wallet balance too low to reverse earning (PKR %). Payout may already be withdrawn.',
      v_payment.owner_earning_amount;
  end if;

  update public.user_wallets
  set balance = balance - v_payment.owner_earning_amount,
      updated_at = now()
  where user_id = v_owner_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, payment_id, created_by
  ) values (
    v_owner_id,
    v_payment.owner_earning_amount,
    'debit',
    'Booking refund — earning reversed',
    p_booking_id,
    p_payment_id,
    auth.uid()
  );

  update public.payments
  set owner_earning_credited = false,
      updated_at = now()
  where id = p_payment_id;
end;
$$;

-- -------------------------------------------------------------------------
-- 5) Patch: verify platform payment → credit owner wallet
-- -------------------------------------------------------------------------
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
  v_role text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can verify payments';
  end if;

  select role into v_role from public.users where id = auth.uid();

  select * into v_payment from public.payments where id = p_payment_id for update;
  if not found then raise exception 'Payment not found'; end if;

  if p_approve then
    update public.payments
    set status = 'completed', receipt_status = 'approved', verified_by = auth.uid(),
        owner_verified_at = now(), updated_at = now(), failure_reason = null
    where id = p_payment_id;

    select * into v_booking from public.bookings where id = v_payment.booking_id;
    if found then
      update public.bookings set status = 'confirmed', updated_at = now() where id = v_booking.id;

      select w.owner_id into v_owner_id
      from public.workspaces w where w.id = v_booking.workspace_id;

      select name into v_user_name from public.users where id = v_payment.user_id;

      if v_owner_id is not null then
        perform public.credit_owner_booking_earning(
          v_owner_id, p_payment_id, v_booking.id, v_payment.amount
        );

        insert into public.notifications (user_id, title, message, type, metadata)
        values (v_owner_id, 'Payment verified — booking confirmed',
          coalesce(v_user_name, 'A user') || ' paid for ' || coalesce(v_booking.workspace_name, 'your workspace') || '. CWC verified the payment.',
          'payment_verified', jsonb_build_object('booking_id', v_booking.id, 'payment_id', p_payment_id));
      end if;

      insert into public.notifications (user_id, title, message, type, metadata)
      values (v_payment.user_id, 'Payment approved', 'Your payment was verified. Booking confirmed!',
        'payment_approved', jsonb_build_object('booking_id', v_booking.id, 'payment_id', p_payment_id));
    end if;

    perform public.log_staff_action(
      auth.uid(), coalesce(v_role, 'staff'), 'payment_approved', 'payment', p_payment_id,
      'Approved platform payment PKR ' || v_payment.amount::text,
      jsonb_build_object('booking_id', v_payment.booking_id, 'user_id', v_payment.user_id)
    );
  else
    update public.payments
    set receipt_status = 'rejected',
        failure_reason = coalesce(p_reason, 'Receipt rejected by CWC team'),
        updated_at = now(), verified_by = auth.uid()
    where id = p_payment_id;

    insert into public.notifications (user_id, title, message, type, metadata)
    values (v_payment.user_id, 'Payment receipt rejected',
      coalesce(p_reason, 'Your receipt was rejected. Please upload a valid receipt.'),
      'payment_rejected', jsonb_build_object('booking_id', v_payment.booking_id, 'payment_id', p_payment_id));

    perform public.log_staff_action(
      auth.uid(), coalesce(v_role, 'staff'), 'payment_rejected', 'payment', p_payment_id,
      'Rejected platform payment receipt',
      jsonb_build_object('reason', p_reason, 'booking_id', v_payment.booking_id)
    );
  end if;
end;
$$;

-- -------------------------------------------------------------------------
-- 6) Patch: wallet payment → credit owner immediately
-- -------------------------------------------------------------------------
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
  v_owner_id uuid;
  v_payment_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.user_id <> v_user_id then raise exception 'Not your booking'; end if;

  select balance into v_balance
  from public.user_wallets where user_id = v_user_id for update;

  if v_balance is null or v_balance < p_amount then
    raise exception 'Insufficient wallet balance';
  end if;

  update public.user_wallets
  set balance = balance - p_amount, updated_at = now()
  where user_id = v_user_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, created_by
  ) values (
    v_user_id, p_amount, 'debit', 'Booking payment from wallet', p_booking_id, v_user_id
  );

  update public.bookings
  set status = 'confirmed', updated_at = now()
  where id = p_booking_id;

  select id into v_payment_id
  from public.payments
  where booking_id = p_booking_id
  order by created_at desc
  limit 1;

  if v_payment_id is null then
    v_payment_id := gen_random_uuid();
    insert into public.payments (
      id, booking_id, user_id, amount, status, payment_method,
      payee_type, receipt_status, updated_at
    ) values (
      v_payment_id, p_booking_id, v_user_id, p_amount, 'completed',
      'wallet', 'platform', 'approved', now()
    );
  else
    update public.payments
    set status = 'completed',
        payment_method = 'wallet',
        payee_type = 'platform',
        receipt_status = 'approved',
        amount = p_amount,
        updated_at = now()
    where id = v_payment_id;
  end if;

  select w.owner_id into v_owner_id
  from public.workspaces w where w.id = v_booking.workspace_id;

  if v_owner_id is not null then
    perform public.credit_owner_booking_earning(
      v_owner_id, v_payment_id, p_booking_id, p_amount
    );
  end if;
end;
$$;

-- -------------------------------------------------------------------------
-- 7) Patch: refund → reverse owner earning if credited
-- -------------------------------------------------------------------------
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
  v_role text;
begin
  if not public.is_staff() then raise exception 'Only staff can approve refunds'; end if;
  select role into v_role from public.users where id = auth.uid();

  select * into v_refund from public.refund_requests where id = p_refund_id for update;
  if not found then raise exception 'Refund request not found'; end if;
  if v_refund.status <> 'pending' then raise exception 'Refund already processed'; end if;

  if v_refund.payment_id is not null then
    perform public.reverse_owner_booking_earning(v_refund.payment_id, v_refund.booking_id);
  end if;

  insert into public.user_wallets (user_id, balance, updated_at)
  values (v_refund.user_id, v_refund.amount, now())
  on conflict (user_id) do update
  set balance = public.user_wallets.balance + excluded.balance, updated_at = now();

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, payment_id, refund_request_id, created_by
  ) values (
    v_refund.user_id, v_refund.amount, 'credit', 'Booking cancellation refund',
    v_refund.booking_id, v_refund.payment_id, v_refund.id, auth.uid()
  );

  update public.refund_requests
  set status = 'approved', processed_by = auth.uid(), processed_at = now(),
      admin_note = coalesce(p_admin_note, admin_note)
  where id = p_refund_id;

  update public.bookings set status = 'cancelled', updated_at = now()
  where id = v_refund.booking_id and status in ('pending', 'confirmed');

  perform public.log_staff_action(
    auth.uid(), coalesce(v_role, 'staff'), 'refund_approved', 'refund_request', p_refund_id,
    'Approved refund PKR ' || v_refund.amount::text || ' to wallet',
    jsonb_build_object('booking_id', v_refund.booking_id, 'user_id', v_refund.user_id, 'note', p_admin_note)
  );
end;
$$;

-- -------------------------------------------------------------------------
-- 8) Owner requests payout to bank/jazzcash/easypaisa
-- -------------------------------------------------------------------------
create or replace function public.request_owner_payout(
  p_amount numeric,
  p_owner_account_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid := auth.uid();
  v_balance numeric;
  v_account public.owner_payment_accounts%rowtype;
  v_id uuid;
begin
  if v_owner_id is null then raise exception 'Not authenticated'; end if;

  if not exists (
    select 1 from public.users where id = v_owner_id and role = 'owner'
  ) then
    raise exception 'Only owners can request payouts';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Invalid payout amount';
  end if;

  select * into v_account
  from public.owner_payment_accounts
  where id = p_owner_account_id and owner_id = v_owner_id and is_active = true;

  if not found then raise exception 'Payment account not found'; end if;

  select balance into v_balance
  from public.user_wallets where user_id = v_owner_id;

  if coalesce(v_balance, 0) < p_amount then
    raise exception 'Insufficient wallet balance';
  end if;

  if exists (
    select 1 from public.owner_payout_requests
    where owner_id = v_owner_id and status = 'pending'
  ) then
    raise exception 'You already have a pending payout request';
  end if;

  insert into public.owner_payout_requests (
    owner_id, owner_account_id, amount, status
  ) values (
    v_owner_id, p_owner_account_id, p_amount, 'pending'
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.process_owner_payout(
  p_payout_id uuid,
  p_approve boolean,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payout public.owner_payout_requests%rowtype;
  v_account public.owner_payment_accounts%rowtype;
  v_balance numeric;
  v_role text;
begin
  if not public.is_staff() then raise exception 'Only staff can process payouts'; end if;
  select role into v_role from public.users where id = auth.uid();

  select * into v_payout
  from public.owner_payout_requests
  where id = p_payout_id for update;

  if not found then raise exception 'Payout request not found'; end if;
  if v_payout.status <> 'pending' then raise exception 'Payout already processed'; end if;

  select * into v_account
  from public.owner_payment_accounts
  where id = v_payout.owner_account_id;

  if p_approve then
    select balance into v_balance
    from public.user_wallets
    where user_id = v_payout.owner_id
    for update;

    if coalesce(v_balance, 0) < v_payout.amount then
      raise exception 'Owner wallet balance insufficient';
    end if;

    update public.user_wallets
    set balance = balance - v_payout.amount, updated_at = now()
    where user_id = v_payout.owner_id;

    insert into public.wallet_transactions (
      user_id, amount, txn_type, reason, created_by
    ) values (
      v_payout.owner_id,
      v_payout.amount,
      'debit',
      'Payout to ' || coalesce(v_account.account_type, 'account') || ' ' || v_account.account_number,
      auth.uid()
    );

    update public.owner_payout_requests
    set status = 'approved',
        processed_by = auth.uid(),
        processed_at = now(),
        admin_note = coalesce(p_note, admin_note)
    where id = p_payout_id;

    insert into public.notifications (user_id, title, message, type, metadata)
    values (
      v_payout.owner_id,
      'Payout sent',
      'PKR ' || v_payout.amount::text || ' payout approved to your '
        || coalesce(v_account.account_type, 'account') || ' account.',
      'owner_payout_approved',
      jsonb_build_object('payout_id', p_payout_id, 'amount', v_payout.amount)
    );

    perform public.log_staff_action(
      auth.uid(), coalesce(v_role, 'staff'), 'owner_payout_approved', 'owner_payout', p_payout_id,
      'Approved owner payout PKR ' || v_payout.amount::text,
      jsonb_build_object('owner_id', v_payout.owner_id, 'account_id', v_payout.owner_account_id, 'note', p_note)
    );
  else
    update public.owner_payout_requests
    set status = 'rejected',
        processed_by = auth.uid(),
        processed_at = now(),
        admin_note = coalesce(p_note, admin_note)
    where id = p_payout_id;

    insert into public.notifications (user_id, title, message, type, metadata)
    values (
      v_payout.owner_id,
      'Payout rejected',
      coalesce(p_note, 'Your payout request was rejected. Please contact support.'),
      'owner_payout_rejected',
      jsonb_build_object('payout_id', p_payout_id)
    );

    perform public.log_staff_action(
      auth.uid(), coalesce(v_role, 'staff'), 'owner_payout_rejected', 'owner_payout', p_payout_id,
      'Rejected owner payout request',
      jsonb_build_object('note', p_note)
    );
  end if;
end;
$$;

grant execute on function public.request_owner_payout(numeric, uuid) to authenticated;
grant execute on function public.process_owner_payout(uuid, boolean, text) to authenticated;
grant execute on function public.get_platform_fee_percent() to authenticated;

-- -------------------------------------------------------------------------
-- 9) Notification types
-- -------------------------------------------------------------------------
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'general',
    'registration_approved','registration_rejected',
    'owner_approved','owner_rejected',
    'workspace_approved','workspace_rejected',
    'collaboration_response','collaboration_accepted','collaboration_rejected',
    'collaboration_application','collaboration_shortlisted',
    'collaboration_launched','collaboration_invite','collaboration_join_request',
    'collaboration_completed','collaboration_milestone',
    'chat_message','booking_confirmed','booking_cancelled',
    'payment_receipt','payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected'
  ]::text[]));

-- =========================================================================
-- DONE — Default platform fee is 10%. Change in platform_settings table.
-- =========================================================================
