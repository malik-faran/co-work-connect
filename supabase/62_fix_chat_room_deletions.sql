-- 62: Fix chat room deletions update policy and resilience
-- Run in Supabase SQL Editor. Safe to re-run.

create table if not exists public.chat_room_deletions (
  chat_room_id uuid not null references public.chat_rooms(id) on delete cascade,
  user_id      uuid not null references public.users(id) on delete cascade,
  deleted_at   timestamptz not null default now(),
  primary key (chat_room_id, user_id)
);

create index if not exists idx_chat_room_deletions_user
  on public.chat_room_deletions(user_id, deleted_at desc);

alter table public.chat_room_deletions enable row level security;

drop policy if exists "crd_select_self" on public.chat_room_deletions;
create policy "crd_select_self"
  on public.chat_room_deletions for select
  using (auth.uid() = user_id);

drop policy if exists "crd_insert_self" on public.chat_room_deletions;
create policy "crd_insert_self"
  on public.chat_room_deletions for insert
  with check (
    auth.uid() = user_id
    and public.is_chat_room_member(chat_room_id)
  );

drop policy if exists "crd_update_self" on public.chat_room_deletions;
create policy "crd_update_self"
  on public.chat_room_deletions for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "crd_delete_self" on public.chat_room_deletions;
create policy "crd_delete_self"
  on public.chat_room_deletions for delete
  using (auth.uid() = user_id);

-- RPC Function for hiding/deleting a chat for current user
create or replace function public.delete_chat_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (select 1 from public.chat_rooms where id = p_room_id) then
    return;
  end if;

  if not public.is_chat_room_member(p_room_id) then
    raise exception 'Not allowed to delete this chat';
  end if;

  insert into public.chat_room_deletions (chat_room_id, user_id, deleted_at)
  values (p_room_id, auth.uid(), now())
  on conflict (chat_room_id, user_id)
  do update set deleted_at = now();
end;
$$;

-- Restore visibility when user sends a new message
create or replace function public.restore_chat_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return; end if;

  delete from public.chat_room_deletions
  where chat_room_id = p_room_id and user_id = auth.uid();
end;
$$;

grant execute on function public.delete_chat_room(uuid) to authenticated;
grant execute on function public.restore_chat_room(uuid) to authenticated;
