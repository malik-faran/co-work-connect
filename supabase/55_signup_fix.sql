-- 55: Fix signup "Database error saving new user"
-- Run in Supabase SQL Editor. Safe to re-run.
-- Causes: handle_new_user trigger fail, missing user_wallets, invalid role, duplicate email.

-- Ensure wallet table exists (signup trigger chain depends on it)
create table if not exists public.user_wallets (
  user_id   uuid primary key references public.users(id) on delete cascade,
  balance   numeric(12, 2) not null default 0 check (balance >= 0),
  currency  text not null default 'PKR',
  updated_at timestamptz not null default now()
);

alter table public.user_wallets enable row level security;

-- Role constraint must allow signup roles
alter table public.users drop constraint if exists users_role_check;
alter table public.users
  add constraint users_role_check
  check (role in ('user', 'owner', 'admin', 'moderator'));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_name text;
  v_phone text;
  v_city text;
  v_business_name text;
  v_business_address text;
begin
  v_role := lower(trim(coalesce(new.raw_user_meta_data->>'role', 'user')));
  if v_role not in ('user', 'owner') then
    v_role := 'user';
  end if;

  v_name := trim(coalesce(new.raw_user_meta_data->>'name', split_part(coalesce(new.email, ''), '@', 1)));
  if v_name = '' then
    v_name := 'User';
  end if;

  v_phone := nullif(trim(coalesce(new.raw_user_meta_data->>'phone', '')), '');
  v_city := nullif(trim(coalesce(new.raw_user_meta_data->>'city', '')), '');
  v_business_name := nullif(trim(coalesce(new.raw_user_meta_data->>'business_name', '')), '');
  v_business_address := nullif(trim(coalesce(new.raw_user_meta_data->>'business_address', '')), '');

  -- Remove stale profile if same email was left from a failed/partial signup
  delete from public.users u
  where lower(u.email) = lower(coalesce(new.email, ''))
    and u.id <> new.id
    and not exists (select 1 from auth.users a where a.id = u.id);

  insert into public.users (
    id, email, name, phone, role, city, business_name, business_address, owner_approved
  )
  values (
    new.id,
    coalesce(new.email, ''),
    v_name,
    v_phone,
    v_role,
    v_city,
    v_business_name,
    v_business_address,
    case when v_role = 'owner' then null else true end
  )
  on conflict (id) do update set
    email = excluded.email,
    name = excluded.name,
    phone = coalesce(excluded.phone, public.users.phone),
    city = coalesce(excluded.city, public.users.city),
    business_name = coalesce(excluded.business_name, public.users.business_name),
    business_address = coalesce(excluded.business_address, public.users.business_address),
    updated_at = now();

  insert into public.user_wallets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep wallet trigger in sync (idempotent)
create or replace function public.ensure_user_wallet()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_wallets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_ensure_user_wallet on public.users;
create trigger trg_ensure_user_wallet
  after insert on public.users
  for each row execute function public.ensure_user_wallet();
