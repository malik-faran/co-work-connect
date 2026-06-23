-- =========================================================================
-- Co-Work Connect — Collaboration Hub v2 (SINGLE-QUERY MIGRATION)
-- Run this ENTIRE file once in: Supabase Dashboard -> SQL Editor -> New query
-- Safe to re-run (idempotent). Works on the existing DB (chat table: messages).
-- =========================================================================

create extension if not exists "pgcrypto";

-- =========================================================================
-- 0) HELPER: random invite code generator
-- =========================================================================
create or replace function public.gen_invite_code()
returns text
language plpgsql
as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..8 loop
    result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return result;
end;
$$;

-- =========================================================================
-- 1) USERS — collaboration profile fields (Mode B: "Open to Collaborate")
-- =========================================================================
alter table public.users add column if not exists bio text;
alter table public.users add column if not exists collaboration_headline text;
alter table public.users add column if not exists availability text;
alter table public.users add column if not exists preferred_project_types text[] default '{}';

-- =========================================================================
-- 2) COLLABORATIONS — lifecycle + project hub columns
-- =========================================================================
alter table public.collaborations add column if not exists project_mode text not null default 'team_project';
alter table public.collaborations add column if not exists cover_image_url text;
alter table public.collaborations add column if not exists visibility text not null default 'public';
alter table public.collaborations add column if not exists meeting_link text;
alter table public.collaborations add column if not exists invite_code text;
alter table public.collaborations add column if not exists invite_link_enabled boolean not null default true;
alter table public.collaborations add column if not exists invite_code_rotated_at timestamptz;
alter table public.collaborations add column if not exists launched_at timestamptz;
alter table public.collaborations add column if not exists recruiting_closed_at timestamptz;

-- visibility check
alter table public.collaborations drop constraint if exists collaborations_visibility_check;
alter table public.collaborations
  add constraint collaborations_visibility_check
  check (visibility in ('public','invite_only'));

-- Drop the OLD status constraint FIRST so the migration updates below are
-- allowed (the legacy check only permitted open/in_progress/completed/cancelled).
alter table public.collaborations drop constraint if exists collaborations_status_check;

-- Migrate legacy status values -> new lifecycle
update public.collaborations set status = 'recruiting' where status = 'open';
update public.collaborations set status = 'active'     where status = 'in_progress';

-- Add the widened status constraint for the new lifecycle
alter table public.collaborations
  add constraint collaborations_status_check
  check (status in ('draft','recruiting','active','completed','cancelled'));
alter table public.collaborations alter column status set default 'recruiting';

-- collaboration_type is legacy now (kept for back-compat); make it optional
alter table public.collaborations alter column collaboration_type drop not null;

-- Backfill invite codes for existing rows + enforce uniqueness
update public.collaborations
   set invite_code = public.gen_invite_code()
 where invite_code is null;

create unique index if not exists uniq_collab_invite_code
  on public.collaborations(invite_code)
  where invite_code is not null;

-- Auto-assign an invite code to new rows that don't provide one
create or replace function public.collab_set_invite_code()
returns trigger
language plpgsql
as $$
begin
  if new.invite_code is null then
    loop
      new.invite_code := public.gen_invite_code();
      exit when not exists (select 1 from public.collaborations where invite_code = new.invite_code);
    end loop;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_collab_invite_code on public.collaborations;
create trigger trg_collab_invite_code
before insert on public.collaborations
for each row execute function public.collab_set_invite_code();

-- =========================================================================
-- 3) COLLABORATION ROLES (open positions on a project)
-- =========================================================================
create table if not exists public.collaboration_roles (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  title             text not null,
  description       text,
  required_skills   text[] not null default '{}',
  slots             integer,                 -- null = unlimited
  sort_order        integer not null default 0,
  created_at        timestamptz not null default now()
);
create index if not exists idx_collab_roles_collab on public.collaboration_roles(collaboration_id);

-- =========================================================================
-- 4) COLLABORATION MEMBERS (active team after launch)
-- =========================================================================
create table if not exists public.collaboration_members (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  user_id           uuid not null references public.users(id) on delete cascade,
  user_name         text not null,
  user_profile_image text,
  role              text not null default 'member' check (role in ('owner','member')),
  role_title        text,
  joined_via        text not null default 'discover' check (joined_via in ('discover','link','invite','owner')),
  joined_at         timestamptz not null default now(),
  unique (collaboration_id, user_id)
);
create index if not exists idx_collab_members_collab on public.collaboration_members(collaboration_id);
create index if not exists idx_collab_members_user  on public.collaboration_members(user_id);

-- =========================================================================
-- 5) COLLABORATION APPLICATIONS (role-based applications)
-- =========================================================================
create table if not exists public.collaboration_applications (
  id                  uuid primary key default gen_random_uuid(),
  collaboration_id    uuid not null references public.collaborations(id) on delete cascade,
  role_id             uuid references public.collaboration_roles(id) on delete set null,
  role_title          text,
  user_id             uuid not null references public.users(id) on delete cascade,
  user_name           text not null,
  user_email          text not null,
  user_profile_image  text,
  user_skills         text[] default '{}',
  pitch_message       text not null,
  availability        text,
  proposed_rate       text,
  portfolio_item_ids  text[] default '{}',
  status              text not null default 'pending'
                      check (status in ('pending','shortlisted','accepted','rejected')),
  reject_reason       text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz,
  unique (collaboration_id, user_id)
);
create index if not exists idx_collab_apps_collab on public.collaboration_applications(collaboration_id);
create index if not exists idx_collab_apps_user   on public.collaboration_applications(user_id);

-- =========================================================================
-- 6) COLLABORATION MILESTONES
-- =========================================================================
create table if not exists public.collaboration_milestones (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  title             text not null,
  description       text,
  due_date          timestamptz,
  status            text not null default 'pending' check (status in ('pending','done')),
  assigned_to       uuid references public.users(id) on delete set null,
  assigned_to_name  text,
  sort_order        integer not null default 0,
  completed_by      uuid references public.users(id) on delete set null,
  completed_at      timestamptz,
  created_by        uuid references public.users(id) on delete set null,
  created_at        timestamptz not null default now()
);
create index if not exists idx_collab_milestones_collab on public.collaboration_milestones(collaboration_id);

-- =========================================================================
-- 7) COLLABORATION FILES (shared file metadata)
-- =========================================================================
create table if not exists public.collaboration_files (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  uploaded_by       uuid references public.users(id) on delete set null,
  uploader_name     text,
  file_name         text not null,
  file_url          text not null,
  file_type         text,
  file_size         bigint,
  created_at        timestamptz not null default now()
);
create index if not exists idx_collab_files_collab on public.collaboration_files(collaboration_id);

-- =========================================================================
-- 8) COLLABORATION ACTIVITY (feed)
-- =========================================================================
create table if not exists public.collaboration_activity (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  actor_id          uuid references public.users(id) on delete set null,
  actor_name        text,
  action            text not null,   -- e.g. 'joined','milestone_done','file_uploaded','launched','completed'
  detail            text,
  created_at        timestamptz not null default now()
);
create index if not exists idx_collab_activity_collab on public.collaboration_activity(collaboration_id, created_at desc);

-- =========================================================================
-- 9) COLLABORATION INVITES (profile-based, Mode B)
-- =========================================================================
create table if not exists public.collaboration_invites (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  collaboration_title text,
  role_id           uuid references public.collaboration_roles(id) on delete set null,
  role_title        text,
  invited_by        uuid not null references public.users(id) on delete cascade,
  invited_by_name   text,
  invited_user      uuid not null references public.users(id) on delete cascade,
  message           text,
  status            text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz,
  unique (collaboration_id, invited_user)
);
create index if not exists idx_collab_invites_user on public.collaboration_invites(invited_user);

-- =========================================================================
-- 10) COLLABORATION LINK JOINS (analytics for share-link joins)
-- =========================================================================
create table if not exists public.collaboration_link_joins (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  user_id           uuid not null references public.users(id) on delete cascade,
  joined_via        text not null default 'link',
  created_at        timestamptz not null default now()
);
create index if not exists idx_collab_link_joins_collab on public.collaboration_link_joins(collaboration_id);

-- =========================================================================
-- 11) USER PORTFOLIO ITEMS
-- =========================================================================
create table if not exists public.user_portfolio_items (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users(id) on delete cascade,
  title         text not null,
  description   text,
  image_url     text,
  project_url   text,
  skills        text[] default '{}',
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists idx_portfolio_user on public.user_portfolio_items(user_id);

-- =========================================================================
-- 12) CHAT ROOMS — group chat support (table for messages is "messages")
-- =========================================================================
alter table public.chat_rooms add column if not exists room_type text not null default 'direct';
alter table public.chat_rooms add column if not exists name text;

alter table public.chat_rooms drop constraint if exists chat_rooms_room_type_check;
alter table public.chat_rooms
  add constraint chat_rooms_room_type_check
  check (room_type in ('direct','group'));

-- group rooms only have one creator in user1_id; allow user2_id to be null
alter table public.chat_rooms alter column user2_id drop not null;

-- drop legacy "user1 <> user2" check (unnamed) so group rooms are allowed
do $$
declare c text;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.chat_rooms'::regclass and contype = 'c'
      and conname not in ('chat_rooms_room_type_check')
  loop
    execute format('alter table public.chat_rooms drop constraint %I', c);
  end loop;
end $$;

alter table public.chat_rooms
  add constraint chat_rooms_pair_check
  check (room_type = 'group' or (user2_id is not null and user1_id <> user2_id));

-- one group room per collaboration
create unique index if not exists uniq_group_room_per_collab
  on public.chat_rooms(collaboration_id)
  where room_type = 'group';

create table if not exists public.chat_room_members (
  id            uuid primary key default gen_random_uuid(),
  chat_room_id  uuid not null references public.chat_rooms(id) on delete cascade,
  user_id       uuid not null references public.users(id) on delete cascade,
  user_name     text,
  user_profile_image text,
  joined_at     timestamptz not null default now(),
  unique (chat_room_id, user_id)
);
create index if not exists idx_chat_room_members_room on public.chat_room_members(chat_room_id);
create index if not exists idx_chat_room_members_user on public.chat_room_members(user_id);

-- =========================================================================
-- 13) HELPER FUNCTIONS for RLS (security definer avoids recursive RLS)
-- =========================================================================
create or replace function public.is_collab_owner(p_collab uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.collaborations where id = p_collab and user_id = auth.uid());
$$;

create or replace function public.is_collab_member(p_collab uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.collaborations where id = p_collab and user_id = auth.uid())
      or exists (select 1 from public.collaboration_members where collaboration_id = p_collab and user_id = auth.uid());
$$;

create or replace function public.is_chat_room_member(p_room uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.chat_room_members where chat_room_id = p_room and user_id = auth.uid());
$$;

-- =========================================================================
-- 14) ENABLE RLS on new tables
-- =========================================================================
alter table public.collaboration_roles        enable row level security;
alter table public.collaboration_members      enable row level security;
alter table public.collaboration_applications enable row level security;
alter table public.collaboration_milestones   enable row level security;
alter table public.collaboration_files        enable row level security;
alter table public.collaboration_activity     enable row level security;
alter table public.collaboration_invites      enable row level security;
alter table public.collaboration_link_joins   enable row level security;
alter table public.user_portfolio_items       enable row level security;
alter table public.chat_room_members          enable row level security;

-- ---- ROLES : public read, owner writes -------------------------------------
drop policy if exists "roles_select_all" on public.collaboration_roles;
create policy "roles_select_all" on public.collaboration_roles for select using (true);
drop policy if exists "roles_write_owner" on public.collaboration_roles;
create policy "roles_write_owner" on public.collaboration_roles for all
  using (public.is_collab_owner(collaboration_id))
  with check (public.is_collab_owner(collaboration_id));

-- ---- MEMBERS : readable by anyone, owner manages, user can remove self ------
drop policy if exists "members_select_all" on public.collaboration_members;
create policy "members_select_all" on public.collaboration_members for select using (true);
drop policy if exists "members_insert_owner_or_self" on public.collaboration_members;
create policy "members_insert_owner_or_self" on public.collaboration_members for insert
  with check (public.is_collab_owner(collaboration_id) or auth.uid() = user_id);
drop policy if exists "members_update_owner" on public.collaboration_members;
create policy "members_update_owner" on public.collaboration_members for update
  using (public.is_collab_owner(collaboration_id)) with check (public.is_collab_owner(collaboration_id));
drop policy if exists "members_delete_owner_or_self" on public.collaboration_members;
create policy "members_delete_owner_or_self" on public.collaboration_members for delete
  using (public.is_collab_owner(collaboration_id) or auth.uid() = user_id);

-- ---- APPLICATIONS : visible to applicant + owner ---------------------------
drop policy if exists "apps_select_participants" on public.collaboration_applications;
create policy "apps_select_participants" on public.collaboration_applications for select
  using (auth.uid() = user_id or public.is_collab_owner(collaboration_id));
drop policy if exists "apps_insert_self" on public.collaboration_applications;
create policy "apps_insert_self" on public.collaboration_applications for insert
  with check (auth.uid() = user_id);
drop policy if exists "apps_update_participants" on public.collaboration_applications;
create policy "apps_update_participants" on public.collaboration_applications for update
  using (auth.uid() = user_id or public.is_collab_owner(collaboration_id))
  with check (auth.uid() = user_id or public.is_collab_owner(collaboration_id));
drop policy if exists "apps_delete_self" on public.collaboration_applications;
create policy "apps_delete_self" on public.collaboration_applications for delete
  using (auth.uid() = user_id or public.is_collab_owner(collaboration_id));

-- ---- MILESTONES : members read, members write ------------------------------
drop policy if exists "milestones_select_members" on public.collaboration_milestones;
create policy "milestones_select_members" on public.collaboration_milestones for select
  using (public.is_collab_member(collaboration_id));
drop policy if exists "milestones_write_members" on public.collaboration_milestones;
create policy "milestones_write_members" on public.collaboration_milestones for all
  using (public.is_collab_member(collaboration_id))
  with check (public.is_collab_member(collaboration_id));

-- ---- FILES : members read + write ------------------------------------------
drop policy if exists "files_select_members" on public.collaboration_files;
create policy "files_select_members" on public.collaboration_files for select
  using (public.is_collab_member(collaboration_id));
drop policy if exists "files_insert_members" on public.collaboration_files;
create policy "files_insert_members" on public.collaboration_files for insert
  with check (public.is_collab_member(collaboration_id));
drop policy if exists "files_delete_members" on public.collaboration_files;
create policy "files_delete_members" on public.collaboration_files for delete
  using (public.is_collab_member(collaboration_id));

-- ---- ACTIVITY : members read, members insert -------------------------------
drop policy if exists "activity_select_members" on public.collaboration_activity;
create policy "activity_select_members" on public.collaboration_activity for select
  using (public.is_collab_member(collaboration_id));
drop policy if exists "activity_insert_members" on public.collaboration_activity;
create policy "activity_insert_members" on public.collaboration_activity for insert
  with check (public.is_collab_member(collaboration_id));

-- ---- INVITES : invited user + inviter --------------------------------------
drop policy if exists "invites_select_participants" on public.collaboration_invites;
create policy "invites_select_participants" on public.collaboration_invites for select
  using (auth.uid() = invited_user or auth.uid() = invited_by);
drop policy if exists "invites_insert_inviter" on public.collaboration_invites;
create policy "invites_insert_inviter" on public.collaboration_invites for insert
  with check (auth.uid() = invited_by);
drop policy if exists "invites_update_participants" on public.collaboration_invites;
create policy "invites_update_participants" on public.collaboration_invites for update
  using (auth.uid() = invited_user or auth.uid() = invited_by)
  with check (auth.uid() = invited_user or auth.uid() = invited_by);
drop policy if exists "invites_delete_participants" on public.collaboration_invites;
create policy "invites_delete_participants" on public.collaboration_invites for delete
  using (auth.uid() = invited_user or auth.uid() = invited_by);

-- ---- LINK JOINS : insert self, owner reads ---------------------------------
drop policy if exists "linkjoins_insert_self" on public.collaboration_link_joins;
create policy "linkjoins_insert_self" on public.collaboration_link_joins for insert
  with check (auth.uid() = user_id);
drop policy if exists "linkjoins_select_owner_or_self" on public.collaboration_link_joins;
create policy "linkjoins_select_owner_or_self" on public.collaboration_link_joins for select
  using (auth.uid() = user_id or public.is_collab_owner(collaboration_id));

-- ---- PORTFOLIO : public read, owner of profile writes ----------------------
drop policy if exists "portfolio_select_all" on public.user_portfolio_items;
create policy "portfolio_select_all" on public.user_portfolio_items for select using (true);
drop policy if exists "portfolio_write_self" on public.user_portfolio_items;
create policy "portfolio_write_self" on public.user_portfolio_items for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---- CHAT ROOM MEMBERS : members read, owner/self manage -------------------
drop policy if exists "crm_select_members" on public.chat_room_members;
create policy "crm_select_members" on public.chat_room_members for select
  using (auth.uid() = user_id or public.is_chat_room_member(chat_room_id));
drop policy if exists "crm_insert" on public.chat_room_members;
create policy "crm_insert" on public.chat_room_members for insert
  with check (auth.uid() = user_id or public.is_chat_room_member(chat_room_id));
drop policy if exists "crm_delete_self" on public.chat_room_members;
create policy "crm_delete_self" on public.chat_room_members for delete
  using (auth.uid() = user_id);

-- =========================================================================
-- 15) EXTEND CHAT RLS for GROUP rooms (added policies are OR'd with existing)
--     Live message table is public.messages.
-- =========================================================================
drop policy if exists "chat_rooms_select_group_members" on public.chat_rooms;
create policy "chat_rooms_select_group_members" on public.chat_rooms for select
  using (room_type = 'group' and public.is_chat_room_member(id));

drop policy if exists "chat_rooms_update_group_members" on public.chat_rooms;
create policy "chat_rooms_update_group_members" on public.chat_rooms for update
  using (room_type = 'group' and public.is_chat_room_member(id))
  with check (room_type = 'group' and public.is_chat_room_member(id));

-- messages table (your DB names it "messages")
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='messages') then
    execute 'drop policy if exists "messages_select_group_members" on public.messages';
    execute 'create policy "messages_select_group_members" on public.messages for select using (public.is_chat_room_member(chat_room_id))';
    execute 'drop policy if exists "messages_insert_group_members" on public.messages';
    execute 'create policy "messages_insert_group_members" on public.messages for insert with check (auth.uid() = sender_id and public.is_chat_room_member(chat_room_id))';
  end if;
  -- also support installs that use chat_messages
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='chat_messages') then
    execute 'drop policy if exists "chat_messages_select_group_members" on public.chat_messages';
    execute 'create policy "chat_messages_select_group_members" on public.chat_messages for select using (public.is_chat_room_member(chat_room_id))';
    execute 'drop policy if exists "chat_messages_insert_group_members" on public.chat_messages';
    execute 'create policy "chat_messages_insert_group_members" on public.chat_messages for insert with check (auth.uid() = sender_id and public.is_chat_room_member(chat_room_id))';
  end if;
end $$;

-- =========================================================================
-- 16) ALLOW new notification types used by the collaboration hub
-- =========================================================================
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'general',
    'registration_approved','registration_rejected',
    'owner_approved','owner_rejected',
    'collaboration_response','collaboration_accepted','collaboration_rejected',
    'collaboration_application','collaboration_shortlisted',
    'collaboration_launched','collaboration_invite','collaboration_join_request',
    'collaboration_completed','collaboration_milestone',
    'chat_message','booking_confirmed','booking_cancelled'
  ]::text[]));

-- =========================================================================
-- 17) STORAGE BUCKETS for project covers + shared files
-- =========================================================================
insert into storage.buckets (id, name, public)
values ('project_covers','project_covers', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('collaboration_files','collaboration_files', true)
on conflict (id) do nothing;

-- project_covers : public read, authenticated write
drop policy if exists "project_covers_read" on storage.objects;
create policy "project_covers_read" on storage.objects for select
  using (bucket_id = 'project_covers');
drop policy if exists "project_covers_write" on storage.objects;
create policy "project_covers_write" on storage.objects for insert
  with check (bucket_id = 'project_covers' and auth.role() = 'authenticated');
drop policy if exists "project_covers_update" on storage.objects;
create policy "project_covers_update" on storage.objects for update
  using (bucket_id = 'project_covers' and auth.role() = 'authenticated');
drop policy if exists "project_covers_delete" on storage.objects;
create policy "project_covers_delete" on storage.objects for delete
  using (bucket_id = 'project_covers' and auth.role() = 'authenticated');

-- collaboration_files : public read, authenticated write
drop policy if exists "collab_files_read" on storage.objects;
create policy "collab_files_read" on storage.objects for select
  using (bucket_id = 'collaboration_files');
drop policy if exists "collab_files_write" on storage.objects;
create policy "collab_files_write" on storage.objects for insert
  with check (bucket_id = 'collaboration_files' and auth.role() = 'authenticated');
drop policy if exists "collab_files_delete" on storage.objects;
create policy "collab_files_delete" on storage.objects for delete
  using (bucket_id = 'collaboration_files' and auth.role() = 'authenticated');

-- =========================================================================
-- 18) REALTIME (optional, for live milestones / activity / group chat)
-- =========================================================================
do $$
begin
  begin execute 'alter publication supabase_realtime add table public.collaboration_milestones'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.collaboration_activity';   exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.collaboration_members';    exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.collaboration_applications'; exception when others then null; end;
  begin execute 'alter publication supabase_realtime add table public.chat_room_members';        exception when others then null; end;
end $$;

-- =========================================================================
-- DONE — Collaboration Hub v2 schema is ready.
-- =========================================================================
