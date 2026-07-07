-- 48: Report handling + self-service account deletion
-- Run AFTER 47_collab_payment_release_fix.sql

alter table public.users
  add column if not exists deleted_at timestamptz;

-- Notify staff when a new report is filed
create or replace function public.notify_staff_new_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, message, type, metadata)
  select
    u.id,
    'New user report',
    'New ' || new.report_type || ' report: "' || new.subject || '"',
    'report_received',
    jsonb_build_object(
      'report_id', new.id,
      'report_type', new.report_type,
      'reporter_id', new.reporter_id
    )
  from public.users u
  where u.role in ('moderator', 'admin')
    and u.deleted_at is null;

  return new;
end;
$$;

drop trigger if exists trg_notify_staff_new_report on public.user_reports;
create trigger trg_notify_staff_new_report
  after insert on public.user_reports
  for each row
  execute function public.notify_staff_new_report();

-- Staff reply on a report (visible to reporter in app)
create or replace function public.submit_report_staff_reply(
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
  if not public.is_staff() then
    raise exception 'Only staff can reply to reports';
  end if;

  if v_msg is null or char_length(v_msg) < 5 then
    raise exception 'Reply must be at least 5 characters';
  end if;

  select * into v_report from public.user_reports where id = p_report_id;
  if not found then
    raise exception 'Report not found';
  end if;

  insert into public.user_report_followups (report_id, author_id, author_role, message)
  values (p_report_id, auth.uid(), 'staff', v_msg);

  if v_report.status = 'pending' then
    update public.user_reports
    set status = 'under_review', updated_at = now()
    where id = p_report_id;
  end if;

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_report.reporter_id,
    'Update on your report',
    'Regarding "' || v_report.subject || '": ' || v_msg,
    'report_under_review',
    jsonb_build_object('report_id', p_report_id, 'status', 'under_review')
  );
end;
$$;

grant execute on function public.submit_report_staff_reply(uuid, text) to authenticated;

-- Allow reporter to object when under_review too (follow-up message)
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

  if v_report.status not in ('resolved', 'dismissed', 'under_review') then
    raise exception 'Follow-up is only allowed after a decision or during review';
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
    'Follow-up received',
    'We received your message on "' || v_report.subject || '" and reopened the review.',
    'report_under_review',
    jsonb_build_object('report_id', p_report_id, 'status', 'under_review')
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  select
    u.id,
    'Report follow-up',
    'Reporter added a follow-up on "' || v_report.subject || '".',
    'report_received',
    jsonb_build_object('report_id', p_report_id, 'objection', true)
  from public.users u
  where u.role in ('moderator', 'admin')
    and u.deleted_at is null;
end;
$$;

grant execute on function public.submit_report_objection(uuid, text) to authenticated;

-- Self-service account deletion (soft delete + anonymize)
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if exists (
    select 1 from public.users where id = v_uid and deleted_at is not null
  ) then
    raise exception 'Account already deleted';
  end if;

  -- Hide owner workspaces
  update public.workspaces
  set is_available = false, updated_at = now()
  where owner_id = v_uid;

  update public.users
  set
    name = 'Deleted User',
    email = 'deleted_' || replace(v_uid::text, '-', '') || '@deleted.local',
    phone = null,
    profile_image_url = null,
    business_name = null,
    business_address = null,
    city = null,
    collaboration_enabled = false,
    deleted_at = now(),
    updated_at = now()
  where id = v_uid;
end;
$$;

grant execute on function public.delete_own_account() to authenticated;
