-- 54: Public landing page — Android APK release link (admin-managed)
-- Run in Supabase SQL Editor. Safe to re-run.

insert into public.platform_settings (key, value)
values
  ('android_apk_url', ''),
  ('android_apk_version', ''),
  ('android_apk_notes', '')
on conflict (key) do nothing;

-- Storage bucket for APK uploads (public download)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-releases',
  'app-releases',
  true,
  104857600,
  array['application/vnd.android.package-archive', 'application/octet-stream']
)
on conflict (id) do update
set public = true,
    file_size_limit = 104857600,
    allowed_mime_types = array['application/vnd.android.package-archive', 'application/octet-stream'];

drop policy if exists "app_releases_public_read" on storage.objects;
create policy "app_releases_public_read"
  on storage.objects for select
  using (bucket_id = 'app-releases');

drop policy if exists "app_releases_admin_insert" on storage.objects;
create policy "app_releases_admin_insert"
  on storage.objects for insert
  with check (bucket_id = 'app-releases' and public.is_admin());

drop policy if exists "app_releases_admin_update" on storage.objects;
create policy "app_releases_admin_update"
  on storage.objects for update
  using (bucket_id = 'app-releases' and public.is_admin())
  with check (bucket_id = 'app-releases' and public.is_admin());

drop policy if exists "app_releases_admin_delete" on storage.objects;
create policy "app_releases_admin_delete"
  on storage.objects for delete
  using (bucket_id = 'app-releases' and public.is_admin());

-- Admin updates APK metadata (url can be storage or external CDN link)
create or replace function public.admin_set_android_apk_release(
  p_url text,
  p_version text default null,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text := trim(coalesce(p_url, ''));
  v_version text := nullif(trim(coalesce(p_version, '')), '');
  v_notes text := nullif(trim(coalesce(p_notes, '')), '');
begin
  if not public.is_admin() then
    raise exception 'Only admins can update the Android APK release';
  end if;

  insert into public.platform_settings (key, value, updated_at)
  values ('android_apk_url', v_url, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();

  insert into public.platform_settings (key, value, updated_at)
  values ('android_apk_version', coalesce(v_version, ''), now())
  on conflict (key) do update set value = excluded.value, updated_at = now();

  insert into public.platform_settings (key, value, updated_at)
  values ('android_apk_notes', coalesce(v_notes, ''), now())
  on conflict (key) do update set value = excluded.value, updated_at = now();
end;
$$;

grant execute on function public.admin_set_android_apk_release(text, text, text) to authenticated;
