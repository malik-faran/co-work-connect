-- =========================================================================
-- Co-Work Connect — FIX: public read access for collaborations
-- Run ONCE in Supabase Dashboard -> SQL Editor -> New query -> Run
--
-- Symptom this fixes:
--   * Public projects don't appear in other users' Discover tab
--   * Invited user opens a project -> "Project not found"
--   * After accepting an invite -> "Project not found"
--
-- Cause: an old/leftover RLS policy on public.collaborations restricts SELECT
-- to the owner only (e.g. using (auth.uid() = user_id)). This resets the
-- collaborations + collaboration_roles RLS to a known-good state where anyone
-- signed in can READ projects, while only the owner/admin can WRITE.
-- =========================================================================

-- 0) (Optional) See what policies currently exist — uncomment to inspect:
-- select tablename, policyname, cmd, qual
--   from pg_policies
--  where schemaname = 'public'
--    and tablename in ('collaborations','collaboration_roles')
--  order by tablename, cmd;

-- =========================================================================
-- 1) COLLABORATIONS — drop ALL existing policies, recreate clean set
-- =========================================================================
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

-- READ: any authenticated (or anon) caller can read every project.
create policy "collab_select_public"
  on public.collaborations for select
  using (true);

-- WRITE: only the author may create/update/delete their own project.
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

-- ADMIN write (only if the is_admin() helper exists)
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
end $$;

-- =========================================================================
-- 2) COLLABORATION ROLES — make sure roles are publicly readable too
--    (so invited users / applicants can see the open roles)
-- =========================================================================
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

-- Only the project owner can add/edit/remove roles (is_collab_owner from 09).
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

-- =========================================================================
-- 3) Backfill legacy rows so they pass the app''s Discover filter
-- =========================================================================
update public.collaborations set visibility = 'public' where visibility is null;
update public.collaborations set status = 'recruiting' where status = 'open';

-- =========================================================================
-- 4) VERIFY — these should now return rows when run as a NON-owner too:
-- select id, title, status, visibility from public.collaborations
--   where status in ('recruiting','open');
-- select tablename, policyname, cmd from pg_policies
--   where schemaname='public' and tablename='collaborations' order by cmd;
-- =========================================================================
