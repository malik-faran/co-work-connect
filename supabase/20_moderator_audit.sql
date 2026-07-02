-- =========================================================================
-- Moderator registration audit log + staff action history
-- Run AFTER 19_moderator_platform_wallet.sql
-- Safe to re-run
-- =========================================================================

create table if not exists public.staff_audit_log (
  id            uuid primary key default gen_random_uuid(),
  actor_id      uuid not null references public.users(id) on delete cascade,
  actor_role    text not null,
  action        text not null,
  entity_type   text,
  entity_id     uuid,
  summary       text not null,
  details       jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

create index if not exists idx_staff_audit_log_created
  on public.staff_audit_log(created_at desc);

create index if not exists idx_staff_audit_log_actor
  on public.staff_audit_log(actor_id, created_at desc);

alter table public.staff_audit_log enable row level security;

drop policy if exists "audit_select_admin" on public.staff_audit_log;
create policy "audit_select_admin"
  on public.staff_audit_log for select
  using (public.is_admin());

drop policy if exists "audit_select_self" on public.staff_audit_log;
create policy "audit_select_self"
  on public.staff_audit_log for select
  using (auth.uid() = actor_id);

-- Internal helper (called from RPCs / edge function via service role)
create or replace function public.log_staff_action(
  p_actor_id uuid,
  p_actor_role text,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_summary text,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.staff_audit_log (
    actor_id, actor_role, action, entity_type, entity_id, summary, details
  ) values (
    p_actor_id, p_actor_role, p_action, p_entity_type, p_entity_id, p_summary, coalesce(p_details, '{}'::jsonb)
  )
  returning id into v_id;
  return v_id;
end;
$$;

-- Callable from admin panel after direct updates
create or replace function public.record_staff_action(
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_summary text,
  p_details jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can record actions';
  end if;

  select role into v_role from public.users where id = auth.uid();

  return public.log_staff_action(
    auth.uid(),
    coalesce(v_role, 'unknown'),
    p_action,
    p_entity_type,
    p_entity_id,
    p_summary,
    p_details
  );
end;
$$;

grant execute on function public.record_staff_action(text, text, uuid, text, jsonb) to authenticated;
grant execute on function public.log_staff_action(uuid, text, text, text, uuid, text, jsonb) to service_role;

-- Patch: admin_set_moderator with audit
create or replace function public.admin_set_moderator(
  p_user_id uuid,
  p_make_moderator boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.users%rowtype;
begin
  if not public.is_admin() then
    raise exception 'Only admins can manage moderators';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Cannot change your own role';
  end if;

  select * into v_target from public.users where id = p_user_id;

  if p_make_moderator then
    update public.users
    set role = 'moderator',
        moderator_active = true,
        promoted_by = auth.uid(),
        promoted_at = now(),
        updated_at = now()
    where id = p_user_id
      and role = 'user';

    if not found then
      raise exception 'User not found or invalid role transition';
    end if;

    perform public.log_staff_action(
      auth.uid(), 'admin', 'moderator_promoted', 'user', p_user_id,
      'Promoted user to moderator: ' || coalesce(v_target.email, p_user_id::text),
      jsonb_build_object('email', v_target.email, 'name', v_target.name)
    );
  else
    update public.users
    set role = 'user',
        moderator_active = false,
        updated_at = now()
    where id = p_user_id
      and role = 'moderator';

    if not found then
      raise exception 'User not found or invalid role transition';
    end if;

    perform public.log_staff_action(
      auth.uid(), 'admin', 'moderator_demoted', 'user', p_user_id,
      'Removed moderator access: ' || coalesce(v_target.email, p_user_id::text),
      jsonb_build_object('email', v_target.email, 'name', v_target.name)
    );
  end if;
end;
$$;

-- Patch: payment verify with audit
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
      select w.owner_id into v_owner_id from public.workspaces w where w.id = v_booking.workspace_id;
      select name into v_user_name from public.users where id = v_payment.user_id;

      if v_owner_id is not null then
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

-- Patch: refund approve/reject with audit
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

create or replace function public.reject_refund_request(
  p_refund_id uuid,
  p_admin_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if not public.is_staff() then raise exception 'Only staff can reject refunds'; end if;
  select role into v_role from public.users where id = auth.uid();

  update public.refund_requests
  set status = 'rejected', processed_by = auth.uid(), processed_at = now(),
      admin_note = coalesce(p_admin_note, admin_note)
  where id = p_refund_id and status = 'pending';

  if not found then raise exception 'Refund request not found or already processed'; end if;

  perform public.log_staff_action(
    auth.uid(), coalesce(v_role, 'staff'), 'refund_rejected', 'refund_request', p_refund_id,
    'Rejected refund request',
    jsonb_build_object('note', p_admin_note)
  );
end;
$$;

-- =========================================================================
-- DONE — Deploy edge function: supabase functions deploy create-moderator
-- =========================================================================
