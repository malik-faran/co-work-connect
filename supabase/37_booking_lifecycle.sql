-- 37: Booking ending-soon reminders (10 min) + auto-complete when slot ends
-- Run in Supabase SQL Editor after 36_user_cancel_refund_request.sql
-- Optional: schedule via pg_cron every minute:
--   select cron.schedule('booking-lifecycle', '* * * * *', $$select public.process_booking_lifecycle()$$);

alter table public.bookings
  add column if not exists ending_soon_notified_at timestamptz,
  add column if not exists completed_notified_at timestamptz;

create or replace function public.booking_effective_end_at(b public.bookings)
returns timestamptz
language sql
stable
as $$
  select case
    when not b.is_hourly_booking
      and extract(hour from b.end_date) = 0
      and extract(minute from b.end_date) = 0
    then date_trunc('day', b.end_date) + interval '23 hours 59 minutes'
    else b.end_date
  end;
$$;

create or replace function public.process_booking_lifecycle()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.bookings%rowtype;
  v_owner_id uuid;
  v_end timestamptz;
  v_ending_soon int := 0;
  v_completed int := 0;
  v_unpaid_expired int := 0;
begin
  -- Cancel pending bookings whose slot ended without payment
  for v_b in
    select *
    from public.bookings
    where status = 'pending'
  loop
    v_end := public.booking_effective_end_at(v_b);
    if now() >= v_end
       and not exists (
         select 1 from public.payments p
         where p.booking_id = v_b.id and p.status = 'completed'
       ) then
      update public.bookings
      set status = 'cancelled',
          updated_at = now()
      where id = v_b.id;

      update public.payments
      set status = 'expired',
          updated_at = now(),
          failure_reason = coalesce(failure_reason, 'Slot time passed without payment')
      where booking_id = v_b.id
        and status = 'pending';

      v_unpaid_expired := v_unpaid_expired + 1;
    end if;
  end loop;

  -- 10-minute warning (user + owner)
  for v_b in
    select *
    from public.bookings
    where status = 'confirmed'
      and ending_soon_notified_at is null
  loop
    v_end := public.booking_effective_end_at(v_b);
    if v_end > now()
       and v_end <= now() + interval '10 minutes' then
      select w.owner_id into v_owner_id
      from public.workspaces w
      where w.id = v_b.workspace_id;

      insert into public.notifications (user_id, title, message, type, metadata)
      values (
        v_b.user_id,
        'Booking ending soon',
        'Your booking at "' || v_b.workspace_name || '" ends in 10 minutes.',
        'booking_ending_soon',
        jsonb_build_object(
          'booking_id', v_b.id,
          'workspace_id', v_b.workspace_id,
          'workspace_name', v_b.workspace_name,
          'ends_at', v_end
        )
      );

      if v_owner_id is not null then
        insert into public.notifications (user_id, title, message, type, metadata)
        values (
          v_owner_id,
          'Booking ending soon',
          'A booking at "' || v_b.workspace_name || '" ends in 10 minutes.',
          'booking_ending_soon',
          jsonb_build_object(
            'booking_id', v_b.id,
            'workspace_id', v_b.workspace_id,
            'workspace_name', v_b.workspace_name,
            'ends_at', v_end
          )
        );
      end if;

      update public.bookings
      set ending_soon_notified_at = now(),
          updated_at = now()
      where id = v_b.id;

      v_ending_soon := v_ending_soon + 1;
    end if;
  end loop;

  -- Mark completed after slot end
  for v_b in
    select *
    from public.bookings
    where status = 'confirmed'
  loop
    v_end := public.booking_effective_end_at(v_b);
    if now() >= v_end then
      select w.owner_id into v_owner_id
      from public.workspaces w
      where w.id = v_b.workspace_id;

      update public.bookings
      set status = 'completed',
          updated_at = now()
      where id = v_b.id;

      if v_b.completed_notified_at is null then
        insert into public.notifications (user_id, title, message, type, metadata)
        values (
          v_b.user_id,
          'Booking completed',
          'Your booking at "' || v_b.workspace_name || '" has ended. See it under Completed in My Bookings.',
          'booking_completed',
          jsonb_build_object(
            'booking_id', v_b.id,
            'workspace_id', v_b.workspace_id,
            'workspace_name', v_b.workspace_name
          )
        );

        if v_owner_id is not null then
          insert into public.notifications (user_id, title, message, type, metadata)
          values (
            v_owner_id,
            'Booking completed',
            'Booking at "' || v_b.workspace_name || '" has ended.',
            'booking_completed',
            jsonb_build_object(
              'booking_id', v_b.id,
              'workspace_id', v_b.workspace_id,
              'workspace_name', v_b.workspace_name
            )
          );
        end if;

        update public.bookings
        set completed_notified_at = now()
        where id = v_b.id;
      end if;

      v_completed := v_completed + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'ending_soon_notified', v_ending_soon,
    'completed', v_completed,
    'unpaid_expired', v_unpaid_expired
  );
end;
$$;

-- Notification types (normalize legacy rows, then re-add constraint)
do $$
declare
  v_allowed text[] := array[
    'general',
    'registration_approved','registration_rejected',
    'owner_approved','owner_rejected',
    'workspace_approved','workspace_rejected',
    'collaboration_response','collaboration_accepted','collaboration_rejected',
    'collaboration_application','collaboration_shortlisted',
    'collaboration_launched','collaboration_invite','collaboration_join_request',
    'collaboration_completed','collaboration_milestone','collaboration_milestone_missed',
    'collaboration_added','collaboration_removed',
    'chat_message',
    'booking_confirmed','booking_cancelled','booking_ending_soon','booking_completed',
    'payment_receipt','payment_receipt_submitted',
    'payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected',
    'wallet_topup_approved','wallet_topup_rejected'
  ];
begin
  update public.notifications
  set type = 'payment_receipt'
  where type = 'payment_receipt_submitted';

  update public.notifications
  set type = 'collaboration_response'
  where type in ('collaboration_added', 'collaboration_removed');

  update public.notifications
  set type = 'payment_verified'
  where type = 'wallet_topup_approved';

  update public.notifications
  set type = 'payment_rejected'
  where type = 'wallet_topup_rejected';

  update public.notifications
  set type = 'general'
  where type is null or not (type = any (v_allowed));
end;
$$;

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'general',
    'registration_approved','registration_rejected',
    'owner_approved','owner_rejected',
    'workspace_approved','workspace_rejected',
    'collaboration_response','collaboration_accepted','collaboration_rejected',
    'collaboration_application','collaboration_shortlisted',
    'collaboration_launched','collaboration_invite','collaboration_join_request',
    'collaboration_completed','collaboration_milestone','collaboration_milestone_missed',
    'collaboration_added','collaboration_removed',
    'chat_message',
    'booking_confirmed','booking_cancelled','booking_ending_soon','booking_completed',
    'payment_receipt','payment_receipt_submitted',
    'payment_rejected','payment_verified','payment_approved',
    'refund_approved','refund_rejected',
    'report_received','report_under_review','report_resolved','report_dismissed',
    'owner_earning_credited','owner_payout_approved','owner_payout_rejected',
    'wallet_topup_approved','wallet_topup_rejected'
  ]::text[]));

grant execute on function public.process_booking_lifecycle() to authenticated;
grant execute on function public.booking_effective_end_at(public.bookings) to authenticated;
