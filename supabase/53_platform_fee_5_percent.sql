-- 53: Platform fee 5% on bookings + collaboration releases (not on wallet top-ups)
-- Run AFTER 52_payments_method_check_fix.sql (or anytime after 23 + 41 + 47 + 49)

-- -------------------------------------------------------------------------
-- 1) Set platform fee to 5%
-- -------------------------------------------------------------------------
insert into public.platform_settings (key, value)
values ('platform_fee_percent', '5')
on conflict (key) do update set value = excluded.value, updated_at = now();

create or replace function public.get_platform_fee_percent()
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select value::numeric from public.platform_settings where key = 'platform_fee_percent'),
    5::numeric
  );
$$;

-- -------------------------------------------------------------------------
-- 2) Collaboration payment fee columns
-- -------------------------------------------------------------------------
alter table public.collaboration_payments
  add column if not exists platform_fee_amount numeric(12, 2),
  add column if not exists net_payee_amount numeric(12, 2);

-- -------------------------------------------------------------------------
-- 3) Credit collaboration payee after deducting platform fee
-- -------------------------------------------------------------------------
create or replace function public.credit_collaboration_payee_earning(
  p_payment_id uuid,
  p_payee_id uuid,
  p_collaboration_id uuid,
  p_milestone_id uuid,
  p_gross_amount numeric,
  p_reason_label text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fee_percent numeric;
  v_fee numeric;
  v_net numeric;
begin
  if p_payee_id is null or p_gross_amount is null or p_gross_amount <= 0 then
    return;
  end if;

  if exists (
    select 1 from public.collaboration_payments
    where id = p_payment_id and status = 'released' and net_payee_amount is not null
  ) then
    return;
  end if;

  v_fee_percent := public.get_platform_fee_percent();
  v_fee := round(p_gross_amount * v_fee_percent / 100, 2);
  v_net := round(p_gross_amount - v_fee, 2);

  if v_net <= 0 then
    raise exception 'Net payee amount must be positive after platform fee';
  end if;

  insert into public.user_wallets (user_id, balance, updated_at)
  values (p_payee_id, 0, now())
  on conflict (user_id) do nothing;

  update public.user_wallets
  set balance = balance + v_net,
      updated_at = now()
  where user_id = p_payee_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, collaboration_id, milestone_id, created_by
  ) values (
    p_payee_id,
    v_net,
    'credit',
    p_reason_label || ' (platform fee ' || v_fee_percent::text || '% deducted)',
    p_collaboration_id,
    p_milestone_id,
    auth.uid()
  );

  update public.collaboration_payments
  set platform_fee_amount = v_fee,
      net_payee_amount = v_net,
      status = 'released',
      released_at = now()
  where id = p_payment_id;
end;
$$;

-- -------------------------------------------------------------------------
-- 4) Milestone release — payee gets gross minus 5% platform fee
-- -------------------------------------------------------------------------
create or replace function public.release_collaboration_milestone_payment(p_milestone_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_m public.collaboration_milestones%rowtype;
  v_collab public.collaborations%rowtype;
  v_pay public.collaboration_payments%rowtype;
  v_project_title text;
  v_fee_percent numeric;
  v_net numeric;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_m from public.collaboration_milestones where id = p_milestone_id;
  if not found then
    raise exception 'Milestone not found';
  end if;

  select * into v_collab from public.collaborations where id = v_m.collaboration_id;
  if v_collab.user_id <> v_uid then
    raise exception 'Only the project owner can release payments';
  end if;

  if v_collab.payment_mode = 'none' then
    raise exception 'This project is set to non-paid collaboration';
  end if;

  if v_m.status <> 'done' then
    raise exception 'Complete the milestone before releasing payment';
  end if;

  select * into v_pay from public.collaboration_payments
  where milestone_id = p_milestone_id
  order by created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'No payment record found for this milestone. Fund it from your wallet first.';
  end if;

  if v_pay.status = 'released' then
    return;
  end if;

  if v_pay.status <> 'held' then
    raise exception 'Milestone payment is not in escrow (status: %). Fund it first.', v_pay.status;
  end if;

  if v_pay.payee_id is null then
    raise exception 'Assign a teammate to this milestone before releasing payment';
  end if;

  v_fee_percent := public.get_platform_fee_percent();
  v_net := round(v_pay.amount - round(v_pay.amount * v_fee_percent / 100, 2), 2);

  perform public.credit_collaboration_payee_earning(
    v_pay.id,
    v_pay.payee_id,
    v_m.collaboration_id,
    p_milestone_id,
    v_pay.amount,
    'Milestone payment released: ' || v_m.title
  );

  v_project_title := coalesce(v_collab.title, 'your project');

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_pay.payee_id,
    'Milestone payment released',
    'PKR ' || v_net::text || ' credited for "' || v_m.title || '" on "' || v_project_title
      || '" (after ' || v_fee_percent::text || '% platform fee).',
    'collaboration_milestone_payment_released',
    jsonb_build_object(
      'collaboration_id', v_m.collaboration_id,
      'milestone_id', p_milestone_id,
      'milestone_title', v_m.title,
      'gross_amount', v_pay.amount,
      'net_amount', v_net,
      'platform_fee', round(v_pay.amount * v_fee_percent / 100, 2)
    )
  );
end;
$$;

-- -------------------------------------------------------------------------
-- 5) Staff force-release — same 5% fee
-- -------------------------------------------------------------------------
create or replace function public.staff_force_release_collaboration_payment(
  p_payment_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pay public.collaboration_payments%rowtype;
  v_m public.collaboration_milestones%rowtype;
  v_reason text := trim(coalesce(p_reason, ''));
  v_actor_role text;
  v_title text;
  v_fee_percent numeric;
  v_net numeric;
begin
  if not public.is_staff() then
    raise exception 'Only staff can release collaboration payments';
  end if;

  if char_length(v_reason) < 5 then
    raise exception 'Reason must be at least 5 characters';
  end if;

  select * into v_pay
  from public.collaboration_payments
  where id = p_payment_id
  for update;

  if not found then
    raise exception 'Payment not found';
  end if;

  if v_pay.status = 'released' then
    return;
  end if;

  if v_pay.status <> 'held' then
    raise exception 'Only held payments can be force-released';
  end if;

  if v_pay.payee_id is null then
    raise exception 'Payment has no payee';
  end if;

  select * into v_m from public.collaboration_milestones where id = v_pay.milestone_id;
  select title into v_title from public.collaborations where id = v_pay.collaboration_id;

  v_fee_percent := public.get_platform_fee_percent();
  v_net := round(v_pay.amount - round(v_pay.amount * v_fee_percent / 100, 2), 2);

  perform public.credit_collaboration_payee_earning(
    v_pay.id,
    v_pay.payee_id,
    v_pay.collaboration_id,
    v_pay.milestone_id,
    v_pay.amount,
    'Collaboration milestone payment (staff release): ' || coalesce(v_m.title, 'milestone')
  );

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    'collab_payment_released',
    'collaboration_payment',
    p_payment_id,
    'Staff force-released collaboration payment',
    jsonb_build_object('reason', v_reason, 'gross_amount', v_pay.amount, 'net_amount', v_net)
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  values
    (
      v_pay.payee_id,
      'Milestone payment released',
      'PKR ' || v_net::text || ' released for "' || coalesce(v_m.title, 'milestone')
        || '" (after ' || v_fee_percent::text || '% platform fee).',
      'collaboration_milestone',
      jsonb_build_object('collaboration_id', v_pay.collaboration_id, 'milestone_id', v_pay.milestone_id)
    ),
    (
      v_pay.payer_id,
      'Milestone payment released',
      'Staff released PKR ' || v_net::text || ' (from PKR ' || v_pay.amount::text || ' gross) for "'
        || coalesce(v_m.title, 'milestone') || '" in ' || coalesce(v_title, 'project') || '.',
      'collaboration_milestone',
      jsonb_build_object('collaboration_id', v_pay.collaboration_id, 'milestone_id', v_pay.milestone_id)
    );
end;
$$;

grant execute on function public.credit_collaboration_payee_earning(uuid, uuid, uuid, uuid, numeric, text) to authenticated;
grant execute on function public.release_collaboration_milestone_payment(uuid) to authenticated;
grant execute on function public.staff_force_release_collaboration_payment(uuid, text) to authenticated;

-- NOTE: Wallet top-ups (staff_verify_topup_request / top_up_wallet) credit the full amount — no platform fee.
