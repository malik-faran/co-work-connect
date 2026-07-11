-- 59: Make signup trigger resilient to profile-table issues
-- Run in Supabase SQL Editor. Safe to re-run.
--
-- Why:
-- - Some projects see "Database error saving new user" during auth signup when
--   downstream profile/wallet writes fail.
-- - This migration prevents auth signup from failing hard; it logs and returns
--   NEW so account creation can complete, while profile sync can be retried.

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
    -- Remove stale profile if same email was left from a failed/partial signup.
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
  exception
    when others then
      raise warning 'handle_new_user failed for %: %', new.id, sqlerrm;
      -- Do not block auth signup if profile sync fails.
      return new;
  end;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
