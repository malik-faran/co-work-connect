-- Collaboration payment mode (paid vs non-paid projects)
-- Run AFTER 41_collab_project_payments.sql

-- 1) Add project payment mode
alter table public.collaborations
  add column if not exists payment_mode text not null default 'escrow'
  check (payment_mode in ('escrow', 'none'));

-- Backfill legacy rows explicitly
update public.collaborations
set payment_mode = coalesce(payment_mode, 'escrow')
where payment_mode is null;

-- 2) Guard escrow RPCs for non-paid projects
create or replace function public.pay_collaboration_milestone_from_wallet(p_milestone_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_m public.collaboration_milestones%rowtype;
  v_collab public.collaborations%rowtype;
  v_balance numeric;
  v_payment_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_m from public.collaboration_milestones where id = p_milestone_id for update;
  if not found then
    raise exception 'Milestone not found';
  end if;

  select * into v_collab from public.collaborations where id = v_m.collaboration_id;
  if v_collab.user_id <> v_uid then
    raise exception 'Only the project owner can fund milestones';
  end if;

  if v_collab.payment_mode = 'none' then
    raise exception 'This project is set to non-paid collaboration';
  end if;

  if v_m.amount is null or v_m.amount <= 0 then
    raise exception 'Set a payment amount on this milestone first';
  end if;

  if v_m.assigned_to is null then
    raise exception 'Assign the milestone to a teammate before payment';
  end if;

  if exists (
    select 1 from public.collaboration_payments
    where milestone_id = p_milestone_id and status in ('held', 'released')
  ) then
    raise exception 'This milestone is already funded';
  end if;

  select balance into v_balance
  from public.user_wallets
  where user_id = v_uid
  for update;

  if v_balance is null or v_balance < v_m.amount then
    raise exception 'Insufficient wallet balance. Top up your wallet first.';
  end if;

  update public.user_wallets
  set balance = balance - v_m.amount,
      updated_at = now()
  where user_id = v_uid;

  insert into public.collaboration_payments (
    collaboration_id, milestone_id, payer_id, payee_id, amount, status, payment_method
  ) values (
    v_m.collaboration_id, p_milestone_id, v_uid, v_m.assigned_to, v_m.amount, 'held', 'wallet'
  )
  returning id into v_payment_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, collaboration_id, milestone_id, created_by
  ) values (
    v_uid, v_m.amount, 'debit',
    'Project milestone escrow: ' || v_m.title,
    v_m.collaboration_id, p_milestone_id, v_uid
  );

  return v_payment_id;
end;
$$;

grant execute on function public.pay_collaboration_milestone_from_wallet(uuid) to authenticated;

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
  where milestone_id = p_milestone_id and status = 'held'
  for update;

  if not found then
    raise exception 'No held payment found for this milestone';
  end if;

  insert into public.user_wallets (user_id)
  values (v_pay.payee_id)
  on conflict (user_id) do nothing;

  update public.user_wallets
  set balance = balance + v_pay.amount,
      updated_at = now()
  where user_id = v_pay.payee_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, collaboration_id, milestone_id, created_by
  ) values (
    v_pay.payee_id, v_pay.amount, 'credit',
    'Milestone payment released: ' || v_m.title,
    v_m.collaboration_id, p_milestone_id, v_uid
  );

  update public.collaboration_payments
  set status = 'released',
      released_at = now()
  where id = v_pay.id;
end;
$$;

grant execute on function public.release_collaboration_milestone_payment(uuid) to authenticated;
