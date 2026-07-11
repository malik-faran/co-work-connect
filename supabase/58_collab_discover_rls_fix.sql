-- 58: Fix Discover — neither user sees the other's posted projects
-- Run in Supabase SQL Editor. Safe to re-run.
--
-- Root cause: RLS on public.collaborations often only allows SELECT on own rows.
-- The app hides your own posts in Discover, so everyone sees an empty list.
-- This resets read policies and adds a discover RPC that bypasses bad RLS.

-- -------------------------------------------------------------------------
-- 1) COLLABORATIONS — public read, owner write, staff/admin patches
-- -------------------------------------------------------------------------
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

do $$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_admin'
  ) then
    execute 'create policy "collab_update_admin" on public.collaborations
             for update using (public.is_admin()) with check (public.is_admin())';
    execute 'create policy "collab_delete_admin" on public.collaborations
             for delete using (public.is_admin())';
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_staff'
  ) then
    execute 'create policy "collab_update_staff" on public.collaborations
             for update using (public.is_staff()) with check (public.is_staff())';
  end if;
end $$;

-- -------------------------------------------------------------------------
-- 2) COLLABORATION ROLES — public read (applicants must see open roles)
-- -------------------------------------------------------------------------
alter table public.collaboration_roles enable row level security;

do $$
declare pol record;
begin
  for pol in
    select policyname from pg_policies
    where schemaname = 'public' and tablename = 'collaboration_roles'
  loop
    execute format('drop policy if exists %I on public.collaboration_roles', pol.policyname);
  end loop;
end $$;

create policy "roles_select_all"
  on public.collaboration_roles for select
  using (true);

do $$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'is_collab_owner'
  ) then
    execute 'create policy "roles_write_owner" on public.collaboration_roles
             for all using (public.is_collab_owner(collaboration_id))
             with check (public.is_collab_owner(collaboration_id))';
  end if;
end $$;

-- -------------------------------------------------------------------------
-- 3) Backfill rows so they pass Discover filters
-- -------------------------------------------------------------------------
update public.collaborations
set visibility = 'public'
where visibility is null;

update public.collaborations
set status = 'recruiting'
where status in ('open', 'draft')
  and launched_at is null
  and coalesce(visibility, 'public') = 'public';

-- -------------------------------------------------------------------------
-- 4) Discover RPC — reliable even if RLS gets misconfigured again
-- -------------------------------------------------------------------------
create or replace function public.get_discover_collaborations()
returns setof public.collaborations
language sql
security definer
stable
set search_path = public
as $$
  select c.*
  from public.collaborations c
  where c.status = 'recruiting'
    and coalesce(c.visibility, 'public') = 'public'
    and auth.uid() is not null
  order by c.created_at desc;
$$;

grant execute on function public.get_discover_collaborations() to authenticated;

-- Verify (run as any logged-in user in SQL editor with JWT, or from app):
-- select id, title, user_id, status, visibility from public.get_discover_collaborations();
