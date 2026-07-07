-- Remove duplicate project-complete activity from RPC (app logs it via logActivity)
-- Run AFTER 38_collab_milestone_complete.sql

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
