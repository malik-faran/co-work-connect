-- 35: 70% refund window + required cancellation reason
-- Cancel while >=70% of (created_at → start_date) remains. Min 10 min before start.
-- Run in Supabase SQL Editor.

create or replace function public.booking_cancellation_deadline(
  p_start timestamptz,
  p_created timestamptz default now()
)
returns timestamptz
language plpgsql
stable
as $$
declare
  v_total_mins integer;
  v_lead_mins integer;
begin
  v_total_mins := greatest(0, extract(epoch from (p_start - p_created))::integer / 60);
  if v_total_mins <= 0 then
    return p_start - interval '10 minutes';
  end if;
  -- 30% of booking window = must cancel before this (70% still remains at deadline)
  v_lead_mins := greatest(10, (v_total_mins * 0.30)::integer);
  return p_start - make_interval(mins => v_lead_mins);
end;
$$;

create or replace function public.booking_can_request_refund(p_booking_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
begin
  select * into v_booking from public.bookings where id = p_booking_id;
  if not found then return false; end if;
  if v_booking.status <> 'confirmed' then return false; end if;
  return now() < public.booking_cancellation_deadline(v_booking.start_date, v_booking.created_at);
end;
$$;

create or replace function public.enforce_refund_request_window()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
begin
  if trim(coalesce(new.reason, '')) = '' then
    raise exception 'Cancellation reason is required';
  end if;

  select * into v_booking from public.bookings where id = new.booking_id;
  if not found then
    raise exception 'Booking not found';
  end if;
  if v_booking.user_id <> new.user_id then
    raise exception 'Not your booking';
  end if;
  if v_booking.status <> 'confirmed' then
    raise exception 'Only confirmed bookings can be refunded';
  end if;
  if now() >= public.booking_cancellation_deadline(v_booking.start_date, v_booking.created_at) then
    raise exception 'Cancellation window closed for this booking';
  end if;
  return new;
end;
$$;

-- Drop legacy single-arg deadline (dynamic tiers from migration 24)
drop function if exists public.booking_cancellation_deadline(timestamptz);

drop trigger if exists trg_refund_request_window on public.refund_requests;
create trigger trg_refund_request_window
  before insert on public.refund_requests
  for each row execute function public.enforce_refund_request_window();

grant execute on function public.booking_cancellation_deadline(timestamptz, timestamptz) to authenticated;
grant execute on function public.booking_can_request_refund(uuid) to authenticated;
