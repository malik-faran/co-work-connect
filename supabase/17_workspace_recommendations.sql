-- =========================================================================
-- Workspace interactions + recommendation support
-- Safe to re-run
-- =========================================================================

create table if not exists public.workspace_interactions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  workspace_id  uuid not null references public.workspaces(id) on delete cascade,
  action        text not null check (action in ('view', 'click', 'book')),
  created_at    timestamptz not null default now()
);

create index if not exists workspace_interactions_user_idx
  on public.workspace_interactions (user_id, created_at desc);

create index if not exists workspace_interactions_workspace_idx
  on public.workspace_interactions (workspace_id);

alter table public.workspace_interactions enable row level security;

drop policy if exists "workspace_interactions_insert_self" on public.workspace_interactions;
create policy "workspace_interactions_insert_self"
  on public.workspace_interactions for insert
  with check (auth.uid() = user_id);

drop policy if exists "workspace_interactions_select_self" on public.workspace_interactions;
create policy "workspace_interactions_select_self"
  on public.workspace_interactions for select
  using (auth.uid() = user_id);

-- =========================================================================
-- DONE
-- =========================================================================
