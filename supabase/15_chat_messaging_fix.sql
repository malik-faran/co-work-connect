-- =========================================================================
-- Chat messaging fix — images + direct/group message access (safe to re-run)
-- Run in Supabase SQL Editor if chat images fail to send.
-- =========================================================================

-- 1) messages table columns (app uses public.messages)
alter table public.messages
  add column if not exists message_type text not null default 'text';

alter table public.messages
  add column if not exists image_url text;

alter table public.messages
  add column if not exists file_url text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'messages_message_type_check'
  ) then
    alter table public.messages
      add constraint messages_message_type_check
      check (message_type in ('text', 'image', 'file'));
  end if;
end $$;

-- 2) Direct + group chat room membership helper
create or replace function public.is_chat_room_member(p_room uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chat_room_members
    where chat_room_id = p_room and user_id = auth.uid()
  )
  or exists (
    select 1 from public.chat_rooms r
    where r.id = p_room
      and (auth.uid() = r.user1_id or auth.uid() = r.user2_id)
  );
$$;

-- 3) messages RLS (direct + group)
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'messages'
  ) then
    execute 'drop policy if exists "messages_select_participants" on public.messages';
    execute 'create policy "messages_select_participants" on public.messages for select using (public.is_chat_room_member(chat_room_id))';

    execute 'drop policy if exists "messages_insert_participants" on public.messages';
    execute 'create policy "messages_insert_participants" on public.messages for insert with check (auth.uid() = sender_id and public.is_chat_room_member(chat_room_id))';

    execute 'drop policy if exists "messages_update_sender" on public.messages';
    execute 'create policy "messages_update_sender" on public.messages for update using (auth.uid() = sender_id) with check (auth.uid() = sender_id)';
  end if;
end $$;

-- 4) chat_images storage bucket + policies
-- Path: chat_images/{chat_room_id}/{user_id}/file.jpg
insert into storage.buckets (id, name, public)
values ('chat_images', 'chat_images', true)
on conflict (id) do update set public = true;

drop policy if exists "chat_images_read_public" on storage.objects;
create policy "chat_images_read_public"
  on storage.objects for select
  using (bucket_id = 'chat_images');

drop policy if exists "chat_images_write_own_folder" on storage.objects;
create policy "chat_images_write_own_folder"
  on storage.objects for insert
  with check (
    bucket_id = 'chat_images'
    and auth.role() = 'authenticated'
    and auth.uid()::text = (storage.foldername(name))[2]
  );

drop policy if exists "chat_images_update_own_folder" on storage.objects;
create policy "chat_images_update_own_folder"
  on storage.objects for update
  using (
    bucket_id = 'chat_images'
    and auth.uid()::text = (storage.foldername(name))[2]
  )
  with check (
    bucket_id = 'chat_images'
    and auth.uid()::text = (storage.foldername(name))[2]
  );

drop policy if exists "chat_images_delete_own_folder" on storage.objects;
create policy "chat_images_delete_own_folder"
  on storage.objects for delete
  using (
    bucket_id = 'chat_images'
    and auth.uid()::text = (storage.foldername(name))[2]
  );

-- =========================================================================
-- DONE
-- =========================================================================
