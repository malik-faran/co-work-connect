-- 56: Notify user when admin approves or rejects a booking cancellation (refund) request
-- Run in Supabase SQL Editor after migrations 19–23. Safe to re-run.

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
  v_workspace_name text;
  v_msg text;
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

  select workspace_name into v_workspace_name
  from public.bookings where id = v_refund.booking_id;

  v_msg := 'Your cancellation request for "' || coalesce(v_workspace_name, 'your booking')
    || '" was approved. PKR ' || v_refund.amount::text || ' has been credited to your wallet.';
  if p_admin_note is not null and trim(p_admin_note) <> '' then
    v_msg := v_msg || ' Note: ' || trim(p_admin_note);
  end if;

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_refund.user_id,
    'Cancellation request approved',
    v_msg,
    'refund_approved',
    jsonb_build_object(
      'booking_id', v_refund.booking_id,
      'refund_request_id', p_refund_id,
      'amount', v_refund.amount,
      'admin_note', p_admin_note
    )
  );

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
  v_refund public.refund_requests%rowtype;
  v_role text;
  v_workspace_name text;
  v_note text;
  v_msg text;
begin
  if not public.is_staff() then raise exception 'Only staff can reject refunds'; end if;
  select role into v_role from public.users where id = auth.uid();

  select * into v_refund
  from public.refund_requests
  where id = p_refund_id and status = 'pending'
  for update;

  if not found then
    raise exception 'Refund request not found or already processed';
  end if;

  v_note := coalesce(nullif(trim(p_admin_note), ''), 'Cancellation request rejected by CWC team.');

  update public.refund_requests
  set status = 'rejected',
      processed_by = auth.uid(),
      processed_at = now(),
      admin_note = v_note
  where id = p_refund_id;

  select workspace_name into v_workspace_name
  from public.bookings where id = v_refund.booking_id;

  v_msg := 'Your cancellation request for "' || coalesce(v_workspace_name, 'your booking')
    || '" was denied. Reason: ' || v_note;

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_refund.user_id,
    'Cancellation request denied',
    v_msg,
    'refund_rejected',
    jsonb_build_object(
      'booking_id', v_refund.booking_id,
      'refund_request_id', p_refund_id,
      'admin_note', v_note
    )
  );

  perform public.log_staff_action(
    auth.uid(), coalesce(v_role, 'staff'), 'refund_rejected', 'refund_request', p_refund_id,
    'Rejected refund request',
    jsonb_build_object(
      'booking_id', v_refund.booking_id,
      'user_id', v_refund.user_id,
      'note', v_note
    )
  );
end;
$$;

grant execute on function public.approve_refund_to_wallet(uuid, text) to authenticated;
grant execute on function public.reject_refund_request(uuid, text) to authenticated;
