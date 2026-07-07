-- 45: Rollback voice call feature (run if 44_voice_call_logs.sql was applied)

drop table if exists public.voice_call_logs cascade;

-- Revert notification types to pre-voice-call list (matches migration 37+)
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
    'collaboration_milestone_review',
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
  where type = 'voice_call_missed';

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
    'collaboration_milestone_review',
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
