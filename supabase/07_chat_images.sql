-- =========================================================================
-- Chat image messages — run in Supabase SQL Editor
-- Your app uses table: public.messages (not chat_messages)
-- =========================================================================

-- 1) Ensure messages table has image columns --------------------------------
alter table public.messages
  add column if not exists message_type text not null default 'text';

alter table public.messages
  add column if not exists image_url text;

alter table public.messages
  add column if not exists file_url text;

-- Optional: enforce allowed message types (skip if constraint already exists)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'messages_message_type_check'
  ) then
    alter table public.messages
      add constraint messages_message_type_check
      check (message_type in ('text', 'image', 'file'));
  end if;
end $$;

-- 2) Storage bucket for chat images (public read) ---------------------------
insert into storage.buckets (id, name, public)
values ('chat_images', 'chat_images', true)
on conflict (id) do update set public = true;

-- 3) Storage policies (path: chat_images/{chat_room_id}/{user_id}/file.jpg)
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

-- 4) Realtime (if not already enabled) --------------------------------------
-- alter publication supabase_realtime add table public.messages;
