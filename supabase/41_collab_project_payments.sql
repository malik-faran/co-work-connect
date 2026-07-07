-- Collaboration project payments (Fiverr-style escrow via wallet)
-- Run AFTER 40_collab_activity_log.sql

-- -------------------------------------------------------------------------
-- 1) Budget amount + milestone payment amounts
-- -------------------------------------------------------------------------
alter table public.collaborations
  add column if not exists budget_amount numeric(12, 2);

alter table public.collaboration_milestones
  add column if not exists amount numeric(12, 2) check (amount is null or amount > 0);

-- -------------------------------------------------------------------------
-- 2) Milestone payments (held in platform until owner releases)
-- -------------------------------------------------------------------------
create table if not exists public.collaboration_payments (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  milestone_id      uuid not null references public.collaboration_milestones(id) on delete cascade,
  payer_id          uuid not null references public.users(id) on delete cascade,
  payee_id          uuid references public.users(id) on delete set null,
  amount            numeric(12, 2) not null check (amount > 0),
  status            text not null default 'held'
    check (status in ('pending', 'held', 'released', 'failed')),
  payment_method    text not null default 'wallet'
    check (payment_method in ('wallet', 'manual', 'stripe', 'split')),
  created_at        timestamptz not null default now(),
  released_at       timestamptz,
  unique (milestone_id)
);

create index if not exists idx_collab_payments_collab
  on public.collaboration_payments(collaboration_id, created_at desc);

alter table public.wallet_transactions
  add column if not exists collaboration_id uuid references public.collaborations(id) on delete set null;

alter table public.wallet_transactions
  add column if not exists milestone_id uuid references public.collaboration_milestones(id) on delete set null;

alter table public.collaboration_payments enable row level security;

drop policy if exists "collab_payments_select_members" on public.collaboration_payments;
create policy "collab_payments_select_members"
  on public.collaboration_payments for select
  using (public.is_collab_member(collaboration_id));

-- -------------------------------------------------------------------------
-- 3) Pay milestone from client wallet (escrow / held)
-- -------------------------------------------------------------------------
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

-- -------------------------------------------------------------------------
-- 4) Release milestone payment to collaborator (after milestone done)
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
