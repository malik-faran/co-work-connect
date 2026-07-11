-- 61: Fix signup/backfill failing on users_phone_unique
-- Run in Supabase SQL Editor. Safe to re-run.
--
-- Error:
--   duplicate key value violates unique constraint "users_phone_unique"
--   Key (phone)=() already exists.
--
-- Cause: a UNIQUE constraint on phone treats empty string '' as a real value,
-- so only one user can have a blank phone. Normal signups leave phone empty.

-- Allow multiple users with no phone (NULL is unique-friendly).
alter table public.users drop constraint if exists users_phone_unique;
drop index if exists users_phone_unique;
drop index if exists public.users_phone_unique;

-- Normalize blank phones to NULL.
update public.users
set phone = null
where phone is not null and trim(phone) = '';

-- Keep uniqueness only for real phone numbers (optional but useful).
create unique index if not exists users_phone_unique_nonempty
  on public.users (phone)
  where phone is not null and trim(phone) <> '';

-- Re-sync missing profiles (safe now that blank phones are NULL).
insert into public.users (id, email, name, phone, role, owner_approved)
select
  a.id,
  coalesce(a.email, ''),
  coalesce(
    nullif(trim(a.raw_user_meta_data->>'name'), ''),
    nullif(split_part(coalesce(a.email, ''), '@', 1), ''),
    'User'
  ),
  nullif(trim(coalesce(a.raw_user_meta_data->>'phone', '')), ''),
  case
    when lower(trim(coalesce(a.raw_user_meta_data->>'role', 'user'))) = 'owner' then 'owner'
    else 'user'
  end,
  case
    when lower(trim(coalesce(a.raw_user_meta_data->>'role', 'user'))) = 'owner' then null
    else true
  end
from auth.users a
where not exists (select 1 from public.users u where u.id = a.id)
on conflict (id) do nothing;

insert into public.user_wallets (user_id)
select u.id
from public.users u
where not exists (select 1 from public.user_wallets w where w.user_id = u.id)
on conflict (user_id) do nothing;

-- Signup trigger: store NULL instead of '' for missing phone.
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

  begin
    delete from public.users u
    where lower(u.email) = lower(coalesce(new.email, ''))
      and u.id <> new.id;

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
  exception
    when unique_violation then
      delete from public.users u
      where lower(u.email) = lower(coalesce(new.email, ''))
        and u.id <> new.id;

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
    when others then
      raise warning 'handle_new_user failed for %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
