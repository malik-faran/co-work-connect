-- 30: Revert migration 30_wallet_topup_notification_types (if applied)
-- and fix staff_verify_topup_request to use existing notification types.
-- Run in Supabase SQL Editor.

-- 1) Restore notifications constraint (pre wallet-topup types)
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
    'collaboration_completed','collaboration_milestone','collaboration_milestone_missed',
    'chat_message','booking_confirmed','booking_cancelled',
    'payment_receipt','payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected'
  ]::text[]));

-- 2) Re-deploy RPC with allowed notification types
create or replace function public.staff_verify_topup_request(
  p_request_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_amount numeric;
  v_status text;
  v_user_name text;
  v_role text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can verify wallet top-ups';
  end if;

  select role into v_role from public.users where id = auth.uid();

  select user_id, amount, status
    into v_user_id, v_amount, v_status
  from public.wallet_topup_requests
  where id = p_request_id
  for update;

  if v_user_id is null then
    raise exception 'Top-up request not found';
  end if;

  if v_status != 'pending' then
    raise exception 'Request already processed';
  end if;

  select name into v_user_name from public.users where id = v_user_id;

  if p_approve then
    update public.wallet_topup_requests
    set status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now(),
        rejection_reason = null
    where id = p_request_id;

    perform public.top_up_wallet(v_user_id, v_amount);

    insert into public.notifications (user_id, title, message, type, metadata)
    values (
      v_user_id,
      'Wallet top-up approved',
      'Your wallet top-up of PKR ' || v_amount::text || ' has been verified and credited.',
      'payment_verified',
      jsonb_build_object('request_id', p_request_id, 'amount', v_amount, 'source', 'wallet_topup')
    );

    perform public.log_staff_action(
      auth.uid(), coalesce(v_role, 'staff'), 'wallet_topup_approved', 'wallet_topup_request', p_request_id,
      'Approved wallet top-up PKR ' || v_amount::text || ' for ' || coalesce(v_user_name, v_user_id::text),
      jsonb_build_object('user_id', v_user_id, 'amount', v_amount)
    );
  else
    update public.wallet_topup_requests
    set status = 'rejected',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now(),
        rejection_reason = coalesce(p_reason, 'Receipt rejected by CWC team')
    where id = p_request_id;

    insert into public.notifications (user_id, title, message, type, metadata)
    values (
      v_user_id,
      'Wallet top-up rejected',
      coalesce(p_reason, 'Your top-up receipt could not be verified. Please contact support or try again.'),
      'payment_rejected',
      jsonb_build_object('request_id', p_request_id, 'amount', v_amount, 'source', 'wallet_topup')
    );

    perform public.log_staff_action(
      auth.uid(), coalesce(v_role, 'staff'), 'wallet_topup_rejected', 'wallet_topup_request', p_request_id,
      'Rejected wallet top-up PKR ' || v_amount::text,
      jsonb_build_object('user_id', v_user_id, 'amount', v_amount, 'reason', p_reason)
    );
  end if;
end;
$$;

grant execute on function public.staff_verify_topup_request(uuid, boolean, text) to authenticated;
