-- Milestone completion approval flow (request -> owner approve/reject)
-- Run AFTER 42_collab_payment_mode.sql

-- 1) Add submitted status
alter table public.collaboration_milestones
  drop constraint if exists collaboration_milestones_status_check;

alter table public.collaboration_milestones
  add constraint collaboration_milestones_status_check
  check (status in ('pending', 'submitted', 'done', 'missed'));

-- 2) Add request/review metadata
alter table public.collaboration_milestones
  add column if not exists completion_requested_by uuid references public.users(id) on delete set null;

alter table public.collaboration_milestones
  add column if not exists completion_requested_at timestamptz;

alter table public.collaboration_milestones
  add column if not exists review_reason text;

-- 3) Normalize any old invalid states
update public.collaboration_milestones
set review_reason = null
where review_reason is not null and btrim(review_reason) = '';
