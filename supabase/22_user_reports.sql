-- =========================================================================
-- User / Owner reports — submit from app, moderators resolve in admin panel
-- Run AFTER 21_notifications_staff_delete.sql
-- Safe to re-run
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1) Reports table
-- -------------------------------------------------------------------------
create table if not exists public.user_reports (
  id                uuid primary key default gen_random_uuid(),
  reporter_id       uuid not null references public.users(id) on delete cascade,
  reporter_role     text not null default 'user'
    check (reporter_role in ('user', 'owner')),
  report_type       text not null
    check (report_type in (
      'harassment',
      'fraud',
      'fake_listing',
      'payment_issue',
      'inappropriate_content',
      'spam',
      'safety',
      'other'
    )),
  subject           text not null,
  description       text not null,
  reported_user_id  uuid references public.users(id) on delete set null,
  workspace_id      uuid references public.workspaces(id) on delete set null,
  booking_id        uuid references public.bookings(id) on delete set null,
  evidence_urls     jsonb not null default '[]'::jsonb,
  status            text not null default 'pending'
    check (status in ('pending', 'under_review', 'resolved', 'dismissed')),
  staff_action      text
    check (staff_action is null or staff_action in ('none', 'workspace_hidden')),
  processed_by      uuid references public.users(id) on delete set null,
  processed_at      timestamptz,
  resolution_note   text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists idx_user_reports_status
  on public.user_reports(status, created_at desc);

create index if not exists idx_user_reports_reporter
  on public.user_reports(reporter_id, created_at desc);

-- -------------------------------------------------------------------------
-- 2) RLS
-- -------------------------------------------------------------------------
alter table public.user_reports enable row level security;

drop policy if exists "reports_select_self" on public.user_reports;
create policy "reports_select_self"
  on public.user_reports for select
  using (auth.uid() = reporter_id);

drop policy if exists "reports_insert_self" on public.user_reports;
create policy "reports_insert_self"
  on public.user_reports for insert
  with check (
    auth.uid() = reporter_id
    and reporter_role in ('user', 'owner')
  );

drop policy if exists "reports_select_staff" on public.user_reports;
create policy "reports_select_staff"
  on public.user_reports for select
  using (public.is_staff());

drop policy if exists "reports_update_staff" on public.user_reports;
create policy "reports_update_staff"
  on public.user_reports for update
  using (public.is_staff())
  with check (public.is_staff());

-- -------------------------------------------------------------------------
-- 3) Notification types (merge existing + report types)
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
    'report_received','report_under_review','report_resolved','report_dismissed'
  ]::text[]));

-- -------------------------------------------------------------------------
-- 4) Storage bucket for report evidence
-- -------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('report_evidence', 'report_evidence', true)
on conflict (id) do nothing;

drop policy if exists "report_evidence_read" on storage.objects;
create policy "report_evidence_read"
  on storage.objects for select
  using (bucket_id = 'report_evidence');

drop policy if exists "report_evidence_insert" on storage.objects;
create policy "report_evidence_insert"
  on storage.objects for insert
  with check (
    bucket_id = 'report_evidence'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -------------------------------------------------------------------------
-- 5) Staff processes a report
-- -------------------------------------------------------------------------
create or replace function public.process_user_report(
  p_report_id uuid,
  p_status text,
  p_note text default null,
  p_staff_action text default 'none'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.user_reports%rowtype;
  v_actor_role text;
  v_notif_type text;
  v_notif_title text;
  v_notif_message text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can process reports';
  end if;

  if p_status not in ('under_review', 'resolved', 'dismissed') then
    raise exception 'Invalid status. Use under_review, resolved, or dismissed';
  end if;

  select * into v_report
  from public.user_reports
  where id = p_report_id
  for update;

  if not found then
    raise exception 'Report not found';
  end if;

  if v_report.status in ('resolved', 'dismissed') then
    raise exception 'Report already closed';
  end if;

  if p_staff_action = 'workspace_hidden' and v_report.workspace_id is not null then
    update public.workspaces
    set is_available = false,
        updated_at = now()
    where id = v_report.workspace_id;
  end if;

  update public.user_reports
  set status = p_status,
      staff_action = case
        when p_status in ('resolved', 'dismissed') then coalesce(p_staff_action, 'none')
        else staff_action
      end,
      processed_by = auth.uid(),
      processed_at = now(),
      resolution_note = coalesce(p_note, resolution_note),
      updated_at = now()
  where id = p_report_id;

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    case
      when p_status = 'under_review' then 'report_under_review'
      when p_status = 'resolved' then 'report_resolved'
      else 'report_dismissed'
    end,
    'user_report',
    p_report_id,
    case
      when p_status = 'under_review' then 'Report marked under review'
      when p_status = 'resolved' then 'Report resolved'
      else 'Report dismissed'
    end,
    jsonb_build_object(
      'report_type', v_report.report_type,
      'subject', v_report.subject,
      'staff_action', coalesce(p_staff_action, 'none'),
      'note', p_note
    )
  );

  v_notif_type := case
    when p_status = 'under_review' then 'report_under_review'
    when p_status = 'resolved' then 'report_resolved'
    else 'report_dismissed'
  end;

  v_notif_title := case
    when p_status = 'under_review' then 'Report under review'
    when p_status = 'resolved' then 'Report resolved'
    else 'Report dismissed'
  end;

  v_notif_message := case
    when p_status = 'under_review' then
      'Your report "' || v_report.subject || '" is being reviewed by our team.'
    when p_status = 'resolved' then
      'Your report "' || v_report.subject || '" has been resolved.'
      || case when p_note is not null and length(trim(p_note)) > 0
         then ' Note: ' || p_note else '' end
    else
      'Your report "' || v_report.subject || '" was reviewed and closed.'
      || case when p_note is not null and length(trim(p_note)) > 0
         then ' Note: ' || p_note else '' end
  end;

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_report.reporter_id,
    v_notif_title,
    v_notif_message,
    v_notif_type,
    jsonb_build_object('report_id', p_report_id, 'status', p_status)
  );
end;
$$;

grant execute on function public.process_user_report(uuid, text, text, text) to authenticated;

-- =========================================================================
-- DONE — run in Supabase SQL Editor
-- =========================================================================
