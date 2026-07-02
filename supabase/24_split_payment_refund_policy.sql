-- Split payments (wallet + bank/EasyPaisa) and dynamic refund cancellation policy
-- Run after 23_owner_wallet.sql

-- -------------------------------------------------------------------------
-- 1) Split payment columns
-- -------------------------------------------------------------------------
alter table public.payments
  add column if not exists wallet_amount numeric(12, 2) default 0,
  add column if not exists external_amount numeric(12, 2);

alter table public.payments drop constraint if exists payments_payment_method_check;
alter table public.payments
  add constraint payments_payment_method_check
  check (payment_method in ('stripe', 'manual', 'cash', 'wallet', 'split'));

-- -------------------------------------------------------------------------
-- 2) Dynamic refund lead time (minutes before booking start)
-- -------------------------------------------------------------------------
create or replace function public.booking_refund_lead_minutes(p_until_start interval)
returns integer
language plpgsql
immutable
as $$
declare
  v_mins integer;
begin
  v_mins := greatest(0, extract(epoch from p_until_start)::integer / 60);
  if v_mins <= 0 then return 0; end if;
  if v_mins <= 120 then return 20; end if;
  if v_mins <= 1440 then return 60; end if;
  if v_mins <= 4320 then return 180; end if;
  return 1440;
end;
$$;

create or replace function public.booking_cancellation_deadline(p_start timestamptz)
returns timestamptz
language sql
stable
as $$
  select p_start - make_interval(mins => public.booking_refund_lead_minutes(p_start - now()));
$$;

create or replace function public.booking_can_request_refund(p_booking_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
begin
  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then return false; end if;
  if v_booking.status <> 'confirmed' then return false; end if;
  return now() < public.booking_cancellation_deadline(v_booking.start_date);
end;
$$;

-- Enforce refund window on insert
create or replace function public.enforce_refund_request_window()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
begin
  select * into v_booking from public.bookings where id = new.booking_id;
  if not found then
    raise exception 'Booking not found';
  end if;
  if v_booking.user_id <> new.user_id then
    raise exception 'Not your booking';
  end if;
  if v_booking.status <> 'confirmed' then
    raise exception 'Only confirmed bookings can be refunded';
  end if;
  if now() >= public.booking_cancellation_deadline(v_booking.start_date) then
    raise exception 'Cancellation window closed for this booking';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_refund_request_window on public.refund_requests;
create trigger trg_refund_request_window
  before insert on public.refund_requests
  for each row execute function public.enforce_refund_request_window();

-- -------------------------------------------------------------------------
-- 3) Split payment: debit wallet portion, await bank transfer for remainder
-- -------------------------------------------------------------------------
create or replace function public.debit_wallet_for_split_payment(
  p_booking_id uuid,
  p_wallet_amount numeric,
  p_total_amount numeric
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_balance numeric;
  v_booking public.bookings%rowtype;
  v_external numeric;
  v_payment_id uuid;
begin
  if v_user_id is null then raise exception 'Not authenticated'; end if;
  if p_wallet_amount <= 0 then raise exception 'Wallet amount must be positive'; end if;
  if p_total_amount <= p_wallet_amount then
    raise exception 'Use full wallet payment instead of split';
  end if;

  v_external := p_total_amount - p_wallet_amount;

  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.user_id <> v_user_id then raise exception 'Not your booking'; end if;
  if v_booking.status <> 'pending' then raise exception 'Booking is not pending payment'; end if;

  select balance into v_balance
  from public.user_wallets where user_id = v_user_id for update;

  if coalesce(v_balance, 0) < p_wallet_amount then
    raise exception 'Insufficient wallet balance';
  end if;

  update public.user_wallets
  set balance = balance - p_wallet_amount, updated_at = now()
  where user_id = v_user_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, created_by
  ) values (
    v_user_id, p_wallet_amount, 'debit',
    'Split payment — wallet portion', p_booking_id, v_user_id
  );

  select id into v_payment_id
  from public.payments
  where booking_id = p_booking_id
  order by created_at desc
  limit 1
  for update;

  if v_payment_id is null then
    v_payment_id := gen_random_uuid();
    insert into public.payments (
      id, booking_id, user_id, amount, wallet_amount, external_amount,
      status, payment_method, payee_type, receipt_status,
      expires_at, updated_at
    ) values (
      v_payment_id, p_booking_id, v_user_id, p_total_amount,
      p_wallet_amount, v_external,
      'pending', 'split', 'platform', 'awaiting_upload',
      now() + interval '24 hours', now()
    );
  else
    update public.payments
    set amount = p_total_amount,
        wallet_amount = p_wallet_amount,
        external_amount = v_external,
        payment_method = 'split',
        payee_type = 'platform',
        status = 'pending',
        receipt_status = 'awaiting_upload',
        stripe_payment_intent_id = null,
        stripe_client_secret = null,
        expires_at = now() + interval '24 hours',
        updated_at = now()
    where id = v_payment_id;
  end if;

  return v_payment_id;
end;
$$;

-- Refund wallet portion when split payment is cancelled/expired/rejected
create or replace function public.refund_split_wallet_portion(p_payment_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments%rowtype;
begin
  select * into v_payment from public.payments where id = p_payment_id for update;
  if not found then return; end if;
  if coalesce(v_payment.wallet_amount, 0) <= 0 then return; end if;
  if v_payment.status = 'completed' then return; end if;

  insert into public.user_wallets (user_id, balance, currency)
  values (v_payment.user_id, 0, 'PKR')
  on conflict (user_id) do nothing;

  update public.user_wallets
  set balance = balance + v_payment.wallet_amount, updated_at = now()
  where user_id = v_payment.user_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, booking_id, payment_id, created_by
  ) values (
    v_payment.user_id, v_payment.wallet_amount, 'credit',
    'Split payment wallet portion refunded', v_payment.booking_id,
    p_payment_id, coalesce(auth.uid(), v_payment.user_id)
  );

  update public.payments
  set wallet_amount = 0, updated_at = now()
  where id = p_payment_id;
end;
$$;

-- -------------------------------------------------------------------------
-- 4) Patch staff verify — credit owner full gross (wallet + external)
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
  v_gross numeric;
begin
  if not public.is_staff() then
    raise exception 'Only staff can verify payments';
  end if;

  select role into v_role from public.users where id = auth.uid();

  select * into v_payment from public.payments where id = p_payment_id for update;
  if not found then raise exception 'Payment not found'; end if;

  v_gross := coalesce(v_payment.amount, 0);

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
          v_owner_id, p_payment_id, v_booking.id, v_gross
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
      'Approved platform payment PKR ' || v_gross::text,
      jsonb_build_object('booking_id', v_payment.booking_id, 'user_id', v_payment.user_id)
    );
  else
    if v_payment.payment_method = 'split' and coalesce(v_payment.wallet_amount, 0) > 0 then
      perform public.refund_split_wallet_portion(p_payment_id);
    end if;

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

grant execute on function public.debit_wallet_for_split_payment(uuid, numeric, numeric) to authenticated;
grant execute on function public.booking_can_request_refund(uuid) to authenticated;
grant execute on function public.booking_cancellation_deadline(timestamptz) to authenticated;
