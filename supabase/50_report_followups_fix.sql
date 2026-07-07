-- 50: Create missing user_report_followups table (admin panel + staff reply)
-- Run this if you see:
--   relation "public.user_report_followups" does not exist
-- Safe to re-run. Run in Supabase SQL Editor.

-- Requires: user_reports table + is_staff() from earlier migrations

create table if not exists public.user_report_followups (
  id          uuid primary key default gen_random_uuid(),
  report_id   uuid not null references public.user_reports(id) on delete cascade,
  author_id   uuid not null references public.users(id) on delete cascade,
  author_role text not null check (author_role in ('reporter', 'staff')),
  message     text not null check (char_length(trim(message)) >= 5),
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

-- Ensure staff reply RPC exists (from 48; safe to replace)
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
