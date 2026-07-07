-- Contract sign fix — ensure columns + reliable RPC (bypasses RLS edge cases)
-- Run in Supabase SQL Editor (safe if 34 already applied)

alter table public.collaborations
  add column if not exists contract_terms text;

alter table public.collaboration_members
  add column if not exists contract_accepted_at timestamptz;

drop policy if exists "members_update_self_contract" on public.collaboration_members;
create policy "members_update_self_contract"
  on public.collaboration_members for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.accept_project_contract(p_collaboration_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_updated integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from public.collaborations c where c.id = p_collaboration_id
  ) then
    raise exception 'Project not found';
  end if;

  update public.collaboration_members
  set contract_accepted_at = now()
  where collaboration_id = p_collaboration_id
    and user_id = v_uid;

  get diagnostics v_updated = row_count;

  if v_updated = 0 then
    raise exception 'You are not on this project team. Join the team first, then sign the contract.';
  end if;
end;
$$;

grant execute on function public.accept_project_contract(uuid) to authenticated;
