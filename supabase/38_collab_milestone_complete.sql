-- Collaboration milestones: missed status + gated project completion
-- Run AFTER 37_booking_lifecycle.sql (or any prior collab migrations)

-- -------------------------------------------------------------------------
-- 1) Allow milestone status 'missed'
-- -------------------------------------------------------------------------
alter table public.collaboration_milestones
  drop constraint if exists collaboration_milestones_status_check;

alter table public.collaboration_milestones
  add constraint collaboration_milestones_status_check
  check (status in ('pending', 'done', 'missed'));

-- -------------------------------------------------------------------------
-- 2) Overdue milestones -> status missed (not just notification)
-- -------------------------------------------------------------------------
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
    set status = 'missed',
        missed_notified_at = now()
    where id = v_m.id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.notify_overdue_milestones(uuid) to authenticated;

-- -------------------------------------------------------------------------
-- 3) Gated project completion (owner only, all milestones done, none missed)
-- -------------------------------------------------------------------------
create or replace function public.complete_collaboration_project(p_collaboration_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_collab public.collaborations%rowtype;
  v_total integer;
  v_done integer;
  v_missed integer;
  v_pending integer;
  v_member record;
begin
  select * into v_collab
  from public.collaborations
  where id = p_collaboration_id
  for update;

  if not found then
    raise exception 'Project not found';
  end if;

  if v_collab.user_id <> auth.uid() then
    raise exception 'Only the project owner can mark it complete';
  end if;

  if v_collab.status = 'completed' then
    raise exception 'Project is already completed';
  end if;

  if v_collab.status <> 'active' then
    raise exception 'Only active projects can be completed';
  end if;

  select count(*)::integer,
         count(*) filter (where status = 'done')::integer,
         count(*) filter (where status = 'missed')::integer,
         count(*) filter (where status = 'pending')::integer
  into v_total, v_done, v_missed, v_pending
  from public.collaboration_milestones
  where collaboration_id = p_collaboration_id;

  if v_total = 0 then
    raise exception 'Add milestones before marking the project complete';
  end if;

  if v_missed > 0 then
    raise exception 'Cannot complete: % milestone(s) were missed', v_missed;
  end if;

  if v_pending > 0 then
    raise exception 'Complete all milestones first (% of % done)', v_done, v_total;
  end if;

  update public.collaborations
  set status = 'completed',
      updated_at = now()
  where id = p_collaboration_id;

  for v_member in
    select user_id from public.collaboration_members
    where collaboration_id = p_collaboration_id
      and user_id <> v_collab.user_id
  loop
    insert into public.notifications (user_id, title, message, type, metadata)
    values (
      v_member.user_id,
      'Project completed',
      '"' || v_collab.title || '" has been marked completed. Great work!',
      'collaboration_completed',
      jsonb_build_object('collaboration_id', p_collaboration_id)
    );
  end loop;
end;
$$;

grant execute on function public.complete_collaboration_project(uuid) to authenticated;
