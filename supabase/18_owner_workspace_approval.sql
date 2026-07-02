-- =========================================================================
-- Owner CNIC + Workspace legal document approval
-- Run in Supabase SQL Editor after existing migrations.
-- =========================================================================

-- Workspace listing approval fields ---------------------------------------
alter table public.workspaces
  add column if not exists legal_document_url text,
  add column if not exists workspace_approved boolean;

-- Existing listings stay visible (grandfathered as approved)
update public.workspaces
set workspace_approved = true
where workspace_approved is null;

create index if not exists idx_workspaces_approval
  on public.workspaces(workspace_approved);

-- Storage bucket for workspace legal documents ----------------------------
insert into storage.buckets (id, name, public)
values ('workspace_documents', 'workspace_documents', true)
on conflict (id) do nothing;

-- Public read; owners upload under their uid folder
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'workspace_documents_read_public'
  ) then
    create policy "workspace_documents_read_public"
      on storage.objects for select
      using (bucket_id = 'workspace_documents');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'workspace_documents_write_self'
  ) then
    create policy "workspace_documents_write_self"
      on storage.objects for insert
      with check (
        bucket_id = 'workspace_documents'
        and auth.uid()::text = (storage.foldername(name))[1]
      );
  end if;
end $$;

-- CNIC bucket for owner registration (admin reads via public URL) ---------
insert into storage.buckets (id, name, public)
values ('cnic', 'cnic', true)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'cnic_read_public'
  ) then
    create policy "cnic_read_public"
      on storage.objects for select
      using (bucket_id = 'cnic');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'cnic_write_authenticated'
  ) then
    create policy "cnic_write_authenticated"
      on storage.objects for insert
      with check (bucket_id = 'cnic' and auth.role() = 'authenticated');
  end if;
end $$;
