-- 51: Staff / admin chat monitoring RLS (admin panel Chat Monitoring page)
-- Run if chat rooms or messages show empty with no error, or permission denied.
-- Safe to re-run.

-- chat_rooms — staff read + delete for moderation
drop policy if exists "chat_rooms_select_staff" on public.chat_rooms;
create policy "chat_rooms_select_staff"
  on public.chat_rooms for select
  using (public.is_staff());

drop policy if exists "chat_rooms_delete_staff" on public.chat_rooms;
create policy "chat_rooms_delete_staff"
  on public.chat_rooms for delete
  using (public.is_staff());

-- messages table (primary app table)
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'messages'
  ) then
    execute 'drop policy if exists "messages_select_staff" on public.messages';
    execute 'create policy "messages_select_staff" on public.messages for select using (public.is_staff())';
    execute 'drop policy if exists "messages_delete_staff" on public.messages';
    execute 'create policy "messages_delete_staff" on public.messages for delete using (public.is_staff())';
  end if;
end $$;

-- legacy chat_messages table (older schema)
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'chat_messages'
  ) then
    execute 'drop policy if exists "chat_messages_select_staff" on public.chat_messages';
    execute 'create policy "chat_messages_select_staff" on public.chat_messages for select using (public.is_staff())';
    execute 'drop policy if exists "chat_messages_delete_staff" on public.chat_messages';
    execute 'create policy "chat_messages_delete_staff" on public.chat_messages for delete using (public.is_staff())';
  end if;
end $$;

-- Ensure admin policies still exist (from 05_existing_db_patch.sql)
drop policy if exists "chat_rooms_select_admin" on public.chat_rooms;
create policy "chat_rooms_select_admin"
  on public.chat_rooms for select
  using (public.is_admin());

drop policy if exists "chat_rooms_delete_admin" on public.chat_rooms;
create policy "chat_rooms_delete_admin"
  on public.chat_rooms for delete
  using (public.is_admin());

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'messages'
  ) then
    execute 'drop policy if exists "messages_select_admin" on public.messages';
    execute 'create policy "messages_select_admin" on public.messages for select using (public.is_admin())';
    execute 'drop policy if exists "messages_delete_admin" on public.messages';
    execute 'create policy "messages_delete_admin" on public.messages for delete using (public.is_admin())';
  end if;
end $$;
