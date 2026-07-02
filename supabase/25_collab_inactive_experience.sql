-- Inactive project posts + user experience field for collaboration profiles.

alter table public.users
  add column if not exists experience text;

alter table public.collaborations drop constraint if exists collaborations_status_check;

alter table public.collaborations
  add constraint collaborations_status_check
  check (status in ('draft','recruiting','inactive','active','completed','cancelled'));
