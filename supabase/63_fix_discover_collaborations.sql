-- 63: Make all public collaborations discoverable for new & existing users
-- Run in Supabase SQL Editor. Safe to re-run.

-- 1) Enable RLS on collaborations table and grant public select policy
alter table public.collaborations enable row level security;

do $$
declare pol record;
begin
  for pol in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'collaborations'
  loop
    execute format('drop policy if exists %I on public.collaborations', pol.policyname);
  end loop;
end $$;

create policy "collab_select_public"
  on public.collaborations for select
  using (true);

create policy "collab_insert_self"
  on public.collaborations for insert
  with check (auth.uid() = user_id);

create policy "collab_update_self"
  on public.collaborations for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "collab_delete_self"
  on public.collaborations for delete
  using (auth.uid() = user_id);

-- 2) Backfill legacy rows with missing visibility or legacy status
update public.collaborations
set visibility = 'public'
where visibility is null or trim(visibility) = '';

update public.collaborations
set status = 'recruiting'
where status is null or trim(status) = '' or status = 'open' or status = 'draft';

-- 3) Ensure discover RPC returns all public collaborations (recruiting & active)
create or replace function public.get_discover_collaborations()
returns setof public.collaborations
language sql
security definer
stable
set search_path = public
as $$
  select c.*
  from public.collaborations c
  where coalesce(c.visibility, 'public') = 'public'
    and coalesce(c.status, 'recruiting') not in ('draft', 'cancelled')
  order by c.created_at desc;
$$;

grant execute on function public.get_discover_collaborations() to authenticated;
grant execute on function public.get_discover_collaborations() to anon;
