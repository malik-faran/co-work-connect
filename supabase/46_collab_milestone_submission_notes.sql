-- 46: Milestone submission notes + accept/payment-release notifications
-- Run AFTER 45_revert_voice_call_logs.sql (or 44 if 45 skipped)

alter table public.collaboration_milestones
  add column if not exists submission_note text;

-- Notify assignee when owner releases escrow payment
create or replace function public.release_collaboration_milestone_payment(p_milestone_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_m public.collaboration_milestones%rowtype;
  v_collab public.collaborations%rowtype;
  v_pay public.collaboration_payments%rowtype;
  v_project_title text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_m from public.collaboration_milestones where id = p_milestone_id;
  if not found then
    raise exception 'Milestone not found';
  end if;

  select * into v_collab from public.collaborations where id = v_m.collaboration_id;
  if v_collab.user_id <> v_uid then
    raise exception 'Only the project owner can release payments';
  end if;

  if v_collab.payment_mode = 'none' then
    raise exception 'This project is set to non-paid collaboration';
  end if;

  if v_m.status <> 'done' then
    raise exception 'Complete the milestone before releasing payment';
  end if;

  select * into v_pay from public.collaboration_payments
  where milestone_id = p_milestone_id and status = 'held'
  for update;

  if not found then
    raise exception 'No held payment found for this milestone';
  end if;

  insert into public.user_wallets (user_id)
  values (v_pay.payee_id)
  on conflict (user_id) do nothing;

  update public.user_wallets
  set balance = balance + v_pay.amount,
      updated_at = now()
  where user_id = v_pay.payee_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, collaboration_id, milestone_id, created_by
  ) values (
    v_pay.payee_id, v_pay.amount, 'credit',
    'Milestone payment released: ' || v_m.title,
    v_m.collaboration_id, p_milestone_id, v_uid
  );

  update public.collaboration_payments
  set status = 'released',
      released_at = now()
  where id = v_pay.id;

  v_project_title := coalesce(v_collab.title, 'your project');

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_pay.payee_id,
    'Milestone payment released',
    'Payment of Rs ' || trim(to_char(v_pay.amount, '999,999,999.99'))
      || ' for "' || v_m.title || '" on "' || v_project_title || '" has been released to your wallet.',
    'collaboration_milestone_payment_released',
    jsonb_build_object(
      'collaboration_id', v_m.collaboration_id,
      'milestone_id', p_milestone_id,
      'milestone_title', v_m.title,
      'amount', v_pay.amount
    )
  );
end;
$$;

grant execute on function public.release_collaboration_milestone_payment(uuid) to authenticated;

-- Notification types
do $$
declare
  v_allowed text[] := array[
    'general',
    'registration_approved','registration_rejected',
    'owner_approved','owner_rejected',
    'workspace_approved','workspace_rejected',
    'collaboration_response','collaboration_accepted','collaboration_rejected',
    'collaboration_application','collaboration_shortlisted',
    'collaboration_launched','collaboration_invite','collaboration_join_request',
    'collaboration_completed','collaboration_milestone','collaboration_milestone_missed',
    'collaboration_milestone_review','collaboration_milestone_accepted',
    'collaboration_milestone_payment_released',
    'collaboration_added','collaboration_removed',
    'chat_message',
    'booking_confirmed','booking_cancelled','booking_ending_soon','booking_completed',
    'payment_receipt','payment_receipt_submitted',
    'payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected',
    'wallet_topup_approved','wallet_topup_rejected'
  ];
begin
  update public.notifications
  set type = 'general'
  where type is null or not (type = any (v_allowed));
end;
$$;

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
    'collaboration_milestone_review','collaboration_milestone_accepted',
    'collaboration_milestone_payment_released',
    'collaboration_added','collaboration_removed',
    'chat_message',
    'booking_confirmed','booking_cancelled','booking_ending_soon','booking_completed',
    'payment_receipt','payment_receipt_submitted',
    'payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected',
    'wallet_topup_approved','wallet_topup_rejected'
  ]::text[]));
