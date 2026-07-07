-- 44: Voice call logs + missed-call notification types

create table if not exists public.voice_call_logs (
  id uuid primary key default gen_random_uuid(),
  call_id text not null unique,
  chat_room_id uuid references public.chat_rooms(id) on delete set null,
  caller_id uuid not null references auth.users(id) on delete cascade,
  caller_name text,
  callee_id uuid not null references auth.users(id) on delete cascade,
  callee_name text,
  status text not null default 'ringing'
    check (status in ('ringing', 'accepted', 'declined', 'missed', 'cancelled', 'timeout')),
  is_video boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now(),
  ended_at timestamptz
);

create index if not exists idx_voice_call_logs_callee
  on public.voice_call_logs (callee_id, created_at desc);
create index if not exists idx_voice_call_logs_caller
  on public.voice_call_logs (caller_id, created_at desc);
create index if not exists idx_voice_call_logs_chat_room
  on public.voice_call_logs (chat_room_id, created_at desc);

alter table public.voice_call_logs enable row level security;

drop policy if exists "Call participants can view voice call logs" on public.voice_call_logs;
create policy "Call participants can view voice call logs"
  on public.voice_call_logs for select
  using (auth.uid() in (caller_id, callee_id));

drop policy if exists "Call participants can insert voice call logs" on public.voice_call_logs;
create policy "Call participants can insert voice call logs"
  on public.voice_call_logs for insert
  with check (auth.uid() in (caller_id, callee_id));

drop policy if exists "Call participants can update voice call logs" on public.voice_call_logs;
create policy "Call participants can update voice call logs"
  on public.voice_call_logs for update
  using (auth.uid() in (caller_id, callee_id))
  with check (auth.uid() in (caller_id, callee_id));

-- Allow notification type for missed voice calls (keep all types from migration 37+)
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
    'chat_message','voice_call_missed',
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
    'collaboration_milestone_review',
    'collaboration_added','collaboration_removed',
    'chat_message','voice_call_missed',
    'booking_confirmed','booking_cancelled','booking_ending_soon','booking_completed',
    'payment_receipt','payment_receipt_submitted',
    'payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected',
    'wallet_topup_approved','wallet_topup_rejected'
  ]::text[]));
