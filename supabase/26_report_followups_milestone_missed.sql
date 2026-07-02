-- Report follow-ups (user objections) + overdue milestone notifications
-- Run AFTER 25_collab_inactive_experience.sql

-- -------------------------------------------------------------------------
-- 1) Report conversation / objections
-- -------------------------------------------------------------------------
create table if not exists public.user_report_followups (
  id          uuid primary key default gen_random_uuid(),
  report_id   uuid not null references public.user_reports(id) on delete cascade,
  author_id   uuid not null references public.users(id) on delete cascade,
  author_role text not null check (author_role in ('reporter', 'staff')),
  message     text not null check (char_length(trim(message)) >= 10),
  created_at  timestamptz not null default now()
);

create index if not exists idx_report_followups_report
  on public.user_report_followups(report_id, created_at asc);

alter table public.user_report_followups enable row level security;

drop policy if exists "report_followups_select_reporter" on public.user_report_followups;
create policy "report_followups_select_reporter"
  on public.user_report_followups for select
  using (
    exists (
      select 1 from public.user_reports r
      where r.id = report_id and r.reporter_id = auth.uid()
    )
    or public.is_staff()
  );

drop policy if exists "report_followups_insert_reporter" on public.user_report_followups;
create policy "report_followups_insert_reporter"
  on public.user_report_followups for insert
  with check (
    author_id = auth.uid()
    and author_role = 'reporter'
    and exists (
      select 1 from public.user_reports r
      where r.id = report_id and r.reporter_id = auth.uid()
    )
  );

drop policy if exists "report_followups_staff_all" on public.user_report_followups;
create policy "report_followups_staff_all"
  on public.user_report_followups for all
  using (public.is_staff())
  with check (public.is_staff());

-- -------------------------------------------------------------------------
-- 2) Reporter submits objection after a closed outcome
-- -------------------------------------------------------------------------
create or replace function public.submit_report_objection(
  p_report_id uuid,
  p_message text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.user_reports%rowtype;
  v_msg text := trim(p_message);
begin
  if v_msg is null or char_length(v_msg) < 10 then
    raise exception 'Please explain your objection in at least 10 characters';
  end if;

  select * into v_report
  from public.user_reports
  where id = p_report_id
  for update;

  if not found then
    raise exception 'Report not found';
  end if;

  if v_report.reporter_id <> auth.uid() then
    raise exception 'Only the reporter can submit an objection';
  end if;

  if v_report.status not in ('resolved', 'dismissed') then
    raise exception 'Objections are only allowed after a report is closed';
  end if;

  insert into public.user_report_followups (report_id, author_id, author_role, message)
  values (p_report_id, auth.uid(), 'reporter', v_msg);

  update public.user_reports
  set status = 'under_review',
      updated_at = now()
  where id = p_report_id;

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_report.reporter_id,
    'Objection received',
    'We received your follow-up on "' || v_report.subject || '" and reopened the review.',
    'report_under_review',
    jsonb_build_object('report_id', p_report_id, 'status', 'under_review')
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  select
    u.id,
    'Report objection',
  'Reporter disagrees with the outcome of "' || v_report.subject || '".',
    'report_received',
    jsonb_build_object('report_id', p_report_id, 'objection', true)
  from public.users u
  where u.role in ('moderator', 'admin');
end;
$$;

grant execute on function public.submit_report_objection(uuid, text) to authenticated;

-- -------------------------------------------------------------------------
-- 3) Overdue milestone notifications
-- -------------------------------------------------------------------------
alter table public.collaboration_milestones
  add column if not exists missed_notified_at timestamptz;

create or replace function public.notify_overdue_milestones(p_collaboration_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_m record;
  v_member record;
  v_collab_title text;
  v_count integer := 0;
begin
  if not exists (
    select 1 from public.collaboration_members m
    where m.collaboration_id = p_collaboration_id and m.user_id = auth.uid()
  ) and not exists (
    select 1 from public.collaborations c
    where c.id = p_collaboration_id and c.user_id = auth.uid()
  ) then
    raise exception 'Not a project member';
  end if;

  select title into v_collab_title
  from public.collaborations
  where id = p_collaboration_id;

  for v_m in
    select *
    from public.collaboration_milestones
    where collaboration_id = p_collaboration_id
      and status = 'pending'
      and due_date is not null
      and due_date < now()
      and missed_notified_at is null
  loop
    for v_member in
      select distinct user_id
      from (
        select user_id from public.collaboration_members
        where collaboration_id = p_collaboration_id
        union
        select user_id from public.collaborations
        where id = p_collaboration_id
      ) members
    loop
      insert into public.notifications (user_id, title, message, type, metadata)
      values (
        v_member.user_id,
        'Milestone not met',
        'Milestone "' || v_m.title || '" on "' || coalesce(v_collab_title, 'your project')
          || '" was not completed by the due date.',
        'collaboration_milestone_missed',
        jsonb_build_object(
          'collaboration_id', p_collaboration_id,
          'milestone_id', v_m.id,
          'milestone_title', v_m.title
        )
      );
    end loop;

    insert into public.collaboration_activity (
      id, collaboration_id, action, detail, created_at
    ) values (
      gen_random_uuid(),
      p_collaboration_id,
      'milestone_missed',
      v_m.title,
      now()
    );

    update public.collaboration_milestones
    set missed_notified_at = now()
    where id = v_m.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.notify_overdue_milestones(uuid) to authenticated;

-- -------------------------------------------------------------------------
-- 4) Notification types
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
    'collaboration_completed','collaboration_milestone','collaboration_milestone_missed',
    'chat_message','booking_confirmed','booking_cancelled',
    'payment_receipt','payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected'
  ]::text[]));
