-- 33: Per-user chat delete (soft hide) + message delete policies
-- Run in Supabase SQL Editor. Deleted chats stay hidden after refresh.

-- -------------------------------------------------------------------------
-- 1) Per-user deletion ledger — hide chat for the user who deleted it
-- -------------------------------------------------------------------------
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

drop policy if exists "crd_delete_self" on public.chat_room_deletions;
create policy "crd_delete_self"
  on public.chat_room_deletions for delete
  using (auth.uid() = user_id);

-- -------------------------------------------------------------------------
-- 2) messages — sender / direct-chat participant may delete messages
-- -------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'messages'
  ) then
    execute 'drop policy if exists "messages_delete_sender" on public.messages';
    execute $p$
      create policy "messages_delete_sender" on public.messages
      for delete using (auth.uid() = sender_id)
    $p$;

    execute 'drop policy if exists "messages_delete_direct_participant" on public.messages';
    execute $p$
      create policy "messages_delete_direct_participant" on public.messages
      for delete using (
        exists (
          select 1 from public.chat_rooms r
          where r.id = chat_room_id
            and r.room_type = 'direct'
            and (auth.uid() = r.user1_id or auth.uid() = r.user2_id)
        )
      )
    $p$;
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'chat_messages'
  ) then
    execute 'drop policy if exists "chat_messages_delete_sender" on public.chat_messages';
    execute $p$
      create policy "chat_messages_delete_sender" on public.chat_messages
      for delete using (auth.uid() = sender_id)
    $p$;

    execute 'drop policy if exists "chat_messages_delete_direct_participant" on public.chat_messages';
    execute $p$
      create policy "chat_messages_delete_direct_participant" on public.chat_messages
      for delete using (
        exists (
          select 1 from public.chat_rooms r
          where r.id = chat_room_id
            and r.room_type = 'direct'
            and (auth.uid() = r.user1_id or auth.uid() = r.user2_id)
        )
      )
    $p$;
  end if;
end $$;

-- -------------------------------------------------------------------------
-- 3) Hide chat for current user (does NOT delete for the other person)
-- -------------------------------------------------------------------------
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

  insert into public.chat_room_deletions (chat_room_id, user_id)
  values (p_room_id, auth.uid())
  on conflict (chat_room_id, user_id)
  do update set deleted_at = excluded.deleted_at;
end;
$$;

-- Restore visibility when user opens/sends a message again
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
