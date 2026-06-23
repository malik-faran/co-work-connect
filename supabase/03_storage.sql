-- =========================================================================
-- Co-Work Connect — Storage Buckets + Policies
-- Run this file AFTER 02_rls.sql.
-- Buckets: profile_images (public), workspace_images (public), chat_files (private).
-- =========================================================================

-- Create buckets (idempotent) ---------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('profile_images',   'profile_images',   true),
  ('workspace_images', 'workspace_images', true),
  ('chat_files',       'chat_files',       false)
on conflict (id) do nothing;

-- Clean existing policies for re-runs -------------------------------------
do $$
declare r record;
begin
  for r in
    select policyname from pg_policies where schemaname = 'storage' and tablename = 'objects'
  loop
    execute format('drop policy if exists %I on storage.objects;', r.policyname);
  end loop;
end $$;

-- Profile images: public read, user writes to their own folder ------------
-- Expected path convention:  profile_images/{auth.uid}/<filename>
create policy "profile_images_read_public"
  on storage.objects for select
  using (bucket_id = 'profile_images');

create policy "profile_images_write_self"
  on storage.objects for insert
  with check (
    bucket_id = 'profile_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "profile_images_update_self"
  on storage.objects for update
  using (
    bucket_id = 'profile_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'profile_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "profile_images_delete_self"
  on storage.objects for delete
  using (
    bucket_id = 'profile_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Workspace images: public read, only workspace owner writes --------------
-- Expected path convention: workspace_images/{auth.uid}/<filename>
create policy "workspace_images_read_public"
  on storage.objects for select
  using (bucket_id = 'workspace_images');

create policy "workspace_images_write_self"
  on storage.objects for insert
  with check (
    bucket_id = 'workspace_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "workspace_images_update_self"
  on storage.objects for update
  using (
    bucket_id = 'workspace_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'workspace_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "workspace_images_delete_self"
  on storage.objects for delete
  using (
    bucket_id = 'workspace_images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Chat files: private; only the uploader can read/write ------------------
-- Expected path convention: chat_files/{auth.uid}/<filename>
create policy "chat_files_read_self"
  on storage.objects for select
  using (
    bucket_id = 'chat_files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "chat_files_write_self"
  on storage.objects for insert
  with check (
    bucket_id = 'chat_files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "chat_files_update_self"
  on storage.objects for update
  using (
    bucket_id = 'chat_files'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'chat_files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "chat_files_delete_self"
  on storage.objects for delete
  using (
    bucket_id = 'chat_files'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
