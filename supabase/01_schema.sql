-- =========================================================================
-- Co-Work Connect — Supabase Schema
-- Run this file FIRST (before 02_rls.sql and 03_storage.sql).
-- Paste into: Supabase Dashboard -> SQL Editor -> New query -> Run
-- =========================================================================

-- Required extensions -----------------------------------------------------
create extension if not exists "pgcrypto";

-- =========================================================================
-- 1) USERS (public profile mirroring auth.users)
-- =========================================================================
create table if not exists public.users (
  id                uuid primary key references auth.users(id) on delete cascade,
  email             text unique not null,
  name              text not null,
  phone             text default '',
  role              text not null default 'user' check (role in ('user','owner','admin')),
  profile_image_url text,
  city              text,
  profession        text,
  skills            text[],
  collaboration_enabled boolean default false,
  collaboration_requests text[],
  business_name     text,
  business_address  text,
  owner_approved    boolean,
  cnic_image_url    text,
  admin_approved    boolean,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz
);
create index if not exists idx_users_role on public.users(role);

-- Auto-create a public.users row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, name, phone, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'role', 'user')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- =========================================================================
-- 2) WORKSPACES (Booking.com-style listings)
-- =========================================================================
create table if not exists public.workspaces (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null references public.users(id) on delete cascade,
  name              text not null,
  description       text not null default '',
  address           text not null,
  city              text not null,
  state             text,
  country           text not null default 'Pakistan',
  latitude          double precision not null default 0,
  longitude         double precision not null default 0,
  price_per_day     numeric(10,2) not null default 0,
  price_per_hour    numeric(10,2) not null default 0,
  capacity          integer not null default 1,
  amenities         text[] not null default '{}',
  image_urls        text[] not null default '{}',
  is_available      boolean not null default true,
  workspace_type    text not null default 'shared' check (workspace_type in ('private','shared','meeting-room')),
  category_options  jsonb not null default '[]',
  time_slots        jsonb not null default '[]',
  opening_time      text not null default '09:00',
  closing_time      text not null default '18:00',
  phone             text,
  email             text,
  operating_hours   text[],
  rating            numeric(3,2) default 0,
  total_reviews     integer default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz
);
create index if not exists idx_workspaces_owner on public.workspaces(owner_id);
create index if not exists idx_workspaces_city  on public.workspaces(city);
create index if not exists idx_workspaces_available on public.workspaces(is_available);
create index if not exists idx_workspaces_price on public.workspaces(price_per_day);

-- =========================================================================
-- 3) BOOKINGS
-- =========================================================================
create table if not exists public.bookings (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete cascade,
  workspace_id      uuid not null references public.workspaces(id) on delete cascade,
  workspace_name    text not null,
  start_date        timestamptz not null,
  end_date          timestamptz not null,
  number_of_days    integer not null default 1,
  total_price       numeric(10,2) not null default 0,
  status            text not null default 'pending'
                    check (status in ('pending','confirmed','cancelled','completed')),
  is_hourly_booking boolean not null default false,
  booking_date      text,
  time_slot_id      uuid,
  time_slot_label   text,
  category_type     text,
  seat_count        integer not null default 1,
  price_per_hour    numeric(10,2),
  price_per_day     numeric(10,2),
  duration_hours    integer,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz
);
create index if not exists idx_bookings_user on public.bookings(user_id);
create index if not exists idx_bookings_workspace on public.bookings(workspace_id);
create index if not exists idx_bookings_status on public.bookings(status);

-- =========================================================================
-- 4) REVIEWS
-- =========================================================================
create table if not exists public.reviews (
  id                uuid primary key default gen_random_uuid(),
  booking_id        uuid not null references public.bookings(id) on delete cascade,
  workspace_id      uuid not null references public.workspaces(id) on delete cascade,
  user_id           uuid not null references public.users(id) on delete cascade,
  user_name         text not null,
  user_profile_image text,
  rating            numeric(2,1) not null check (rating >= 1 and rating <= 5),
  comment           text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz,
  unique (booking_id)
);
create index if not exists idx_reviews_workspace on public.reviews(workspace_id);

-- Keep workspaces.rating and total_reviews fresh
create or replace function public.refresh_workspace_rating(ws_id uuid)
returns void language sql as $$
  update public.workspaces
  set rating = coalesce((select round(avg(rating)::numeric, 2) from public.reviews where workspace_id = ws_id), 0),
      total_reviews = (select count(*) from public.reviews where workspace_id = ws_id),
      updated_at = now()
  where id = ws_id;
$$;

create or replace function public.on_review_change()
returns trigger language plpgsql as $$
begin
  perform public.refresh_workspace_rating(coalesce(new.workspace_id, old.workspace_id));
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_reviews_change on public.reviews;
create trigger trg_reviews_change
after insert or update or delete on public.reviews
for each row execute function public.on_review_change();

-- =========================================================================
-- 5) COLLABORATIONS (Fiverr-style)
-- =========================================================================
create table if not exists public.collaborations (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.users(id) on delete cascade,
  user_name           text not null,
  user_email          text not null,
  user_profile_image  text,
  title               text not null,
  description         text not null,
  required_skills     text[] not null default '{}',
  collaboration_type  text not null check (collaboration_type in ('need_help','offering_help')),
  project_type        text,
  budget              text,
  timeline            text,
  status              text not null default 'open'
                      check (status in ('open','in_progress','completed','cancelled')),
  responses           text[] not null default '{}',
  accepted_user_id    uuid references public.users(id) on delete set null,
  deadline            timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz
);
create index if not exists idx_collab_user on public.collaborations(user_id);
create index if not exists idx_collab_status on public.collaborations(status);

create table if not exists public.collaboration_responses (
  id                  uuid primary key default gen_random_uuid(),
  collaboration_id    uuid not null references public.collaborations(id) on delete cascade,
  user_id             uuid not null references public.users(id) on delete cascade,
  user_name           text not null,
  user_email          text not null,
  user_profile_image  text,
  message             text not null,
  user_skills         text[],
  status              text not null default 'pending'
                      check (status in ('pending','accepted','rejected')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz,
  unique (collaboration_id, user_id)
);
create index if not exists idx_collab_resp_collab on public.collaboration_responses(collaboration_id);

-- =========================================================================
-- 6) CHAT ROOMS + MESSAGES
-- =========================================================================
create table if not exists public.chat_rooms (
  id                    uuid primary key default gen_random_uuid(),
  user1_id              uuid not null references public.users(id) on delete cascade,
  user2_id              uuid not null references public.users(id) on delete cascade,
  user1_name            text,
  user2_name            text,
  user1_profile_image   text,
  user2_profile_image   text,
  last_message          text,
  last_message_at       timestamptz,
  unread_count1         integer not null default 0,
  unread_count2         integer not null default 0,
  collaboration_id      uuid references public.collaborations(id) on delete set null,
  workspace_id          uuid references public.workspaces(id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz,
  check (user1_id <> user2_id)
);
create unique index if not exists uniq_chat_pair
  on public.chat_rooms (least(user1_id,user2_id), greatest(user1_id,user2_id),
                        coalesce(collaboration_id,'00000000-0000-0000-0000-000000000000'),
                        coalesce(workspace_id,'00000000-0000-0000-0000-000000000000'));

create table if not exists public.chat_messages (
  id                    uuid primary key default gen_random_uuid(),
  chat_room_id          uuid not null references public.chat_rooms(id) on delete cascade,
  sender_id             uuid not null references public.users(id) on delete cascade,
  sender_name           text not null,
  sender_profile_image  text,
  message               text not null,
  message_type          text not null default 'text' check (message_type in ('text','image','file')),
  image_url             text,
  file_url              text,
  is_read               boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz
);
create index if not exists idx_chat_messages_room on public.chat_messages(chat_room_id, created_at desc);

-- =========================================================================
-- 7) NOTIFICATIONS
-- =========================================================================
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  title       text not null,
  message     text not null,
  type        text not null,
  is_read     boolean not null default false,
  metadata    jsonb,
  created_at  timestamptz not null default now(),
  read_at     timestamptz
);
create index if not exists idx_notif_user on public.notifications(user_id, created_at desc);

-- =========================================================================
-- 8) PAYMENTS
-- =========================================================================
create table if not exists public.payments (
  id                         uuid primary key default gen_random_uuid(),
  booking_id                 uuid not null references public.bookings(id) on delete cascade,
  user_id                    uuid not null references public.users(id) on delete cascade,
  amount                     numeric(10,2) not null,
  currency                   text not null default 'PKR',
  status                     text not null default 'pending'
                             check (status in ('pending','processing','completed','failed','cancelled','expired')),
  payment_method             text not null default 'stripe',
  stripe_payment_intent_id   text,
  stripe_client_secret       text,
  expires_at                 timestamptz,
  failure_reason             text,
  metadata                   jsonb,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz
);
create index if not exists idx_payments_booking on public.payments(booking_id);
create index if not exists idx_payments_user on public.payments(user_id);

-- =========================================================================
-- 9) Realtime (optional but recommended for chat/notifications)
-- =========================================================================
alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.chat_rooms;
alter publication supabase_realtime add table public.notifications;
