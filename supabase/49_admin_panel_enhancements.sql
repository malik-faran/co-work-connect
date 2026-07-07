-- 49: Admin panel enhancements — suspend users, wallet adjust, collab disputes, staff inbox support
-- Run AFTER 48_reports_and_account_enhancements.sql

-- -------------------------------------------------------------------------
-- 1) User suspension
-- -------------------------------------------------------------------------
alter table public.users
  add column if not exists suspended_at timestamptz;

alter table public.users
  add column if not exists suspended_reason text;

alter table public.users
  add column if not exists suspended_by uuid references public.users(id) on delete set null;

create index if not exists idx_users_suspended
  on public.users(suspended_at)
  where suspended_at is not null;

-- -------------------------------------------------------------------------
-- 2) Collaboration payments (if not created by earlier collab migrations)
-- -------------------------------------------------------------------------
create table if not exists public.collaboration_payments (
  id                uuid primary key default gen_random_uuid(),
  collaboration_id  uuid not null references public.collaborations(id) on delete cascade,
  milestone_id      uuid not null references public.collaboration_milestones(id) on delete cascade,
  payer_id          uuid not null references public.users(id) on delete cascade,
  payee_id          uuid references public.users(id) on delete set null,
  amount            numeric(12, 2) not null check (amount > 0),
  status            text not null default 'pending'
    check (status in ('pending', 'held', 'released', 'failed', 'refunded')),
  payment_method    text not null default 'wallet',
  created_at        timestamptz not null default now(),
  released_at       timestamptz
);

create unique index if not exists idx_collab_payments_milestone
  on public.collaboration_payments(milestone_id);

create index if not exists idx_collab_payments_status
  on public.collaboration_payments(status, created_at desc);

-- -------------------------------------------------------------------------
-- 3) Staff suspend / unsuspend
-- -------------------------------------------------------------------------
create or replace function public.staff_suspend_user(
  p_user_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reason text := trim(coalesce(p_reason, ''));
  v_target public.users%rowtype;
  v_actor_role text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can suspend users';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Cannot suspend yourself';
  end if;

  if char_length(v_reason) < 5 then
    raise exception 'Suspension reason must be at least 5 characters';
  end if;

  select * into v_target from public.users where id = p_user_id;
  if not found then
    raise exception 'User not found';
  end if;

  if v_target.role in ('admin', 'moderator') then
    raise exception 'Cannot suspend staff accounts';
  end if;

  if v_target.deleted_at is not null then
    raise exception 'User account is already deleted';
  end if;

  update public.users
  set
    suspended_at = now(),
    suspended_reason = v_reason,
    suspended_by = auth.uid(),
    collaboration_enabled = false,
    updated_at = now()
  where id = p_user_id;

  update public.workspaces
  set is_available = false, updated_at = now()
  where owner_id = p_user_id;

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    'user_suspended',
    'user',
    p_user_id,
    'User suspended',
    jsonb_build_object('reason', v_reason)
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    p_user_id,
    'Account suspended',
    'Your account has been suspended: ' || v_reason || '. Contact support if you believe this is a mistake.',
    'general',
    jsonb_build_object('suspended', true)
  );
end;
$$;

create or replace function public.staff_unsuspend_user(
  p_user_id uuid,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_role text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can unsuspend users';
  end if;

  update public.users
  set
    suspended_at = null,
    suspended_reason = null,
    suspended_by = null,
    updated_at = now()
  where id = p_user_id
    and suspended_at is not null;

  if not found then
    raise exception 'User is not suspended';
  end if;

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    'user_unsuspended',
    'user',
    p_user_id,
    'User unsuspended',
    jsonb_build_object('note', p_note)
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    p_user_id,
    'Account restored',
    coalesce(p_note, 'Your account suspension has been lifted. You can use CWC again.'),
    'general',
    jsonb_build_object('unsuspended', true)
  );
end;
$$;

grant execute on function public.staff_suspend_user(uuid, text) to authenticated;
grant execute on function public.staff_unsuspend_user(uuid, text) to authenticated;

-- -------------------------------------------------------------------------
-- 4) Staff wallet adjustment
-- -------------------------------------------------------------------------
create or replace function public.staff_adjust_wallet(
  p_user_id uuid,
  p_amount numeric,
  p_direction text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount numeric(12, 2);
  v_reason text := trim(coalesce(p_reason, ''));
  v_balance numeric(12, 2);
  v_actor_role text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can adjust wallets';
  end if;

  if p_direction not in ('credit', 'debit') then
    raise exception 'Direction must be credit or debit';
  end if;

  v_amount := round(p_amount::numeric, 2);
  if v_amount <= 0 then
    raise exception 'Amount must be greater than zero';
  end if;

  if char_length(v_reason) < 5 then
    raise exception 'Reason must be at least 5 characters';
  end if;

  if not exists (select 1 from public.users where id = p_user_id and deleted_at is null) then
    raise exception 'User not found';
  end if;

  insert into public.user_wallets (user_id, balance, updated_at)
  values (p_user_id, 0, now())
  on conflict (user_id) do nothing;

  select balance into v_balance
  from public.user_wallets
  where user_id = p_user_id
  for update;

  if p_direction = 'debit' and v_balance < v_amount then
    raise exception 'Insufficient wallet balance';
  end if;

  update public.user_wallets
  set
    balance = case
      when p_direction = 'credit' then balance + v_amount
      else balance - v_amount
    end,
    updated_at = now()
  where user_id = p_user_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, created_by
  ) values (
    p_user_id,
    v_amount,
    p_direction,
    'Staff adjustment: ' || v_reason,
    auth.uid()
  );

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    case when p_direction = 'credit' then 'wallet_credit' else 'wallet_debit' end,
    'user_wallet',
    p_user_id,
    'Wallet ' || p_direction || ' PKR ' || v_amount::text,
    jsonb_build_object('amount', v_amount, 'reason', v_reason)
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    p_user_id,
    case when p_direction = 'credit' then 'Wallet credited' else 'Wallet debited' end,
    'PKR ' || v_amount::text || ' was ' ||
      case when p_direction = 'credit' then 'added to' else 'deducted from' end ||
      ' your wallet. Reason: ' || v_reason,
    'general',
    jsonb_build_object('wallet_adjustment', p_direction, 'amount', v_amount)
  );
end;
$$;

grant execute on function public.staff_adjust_wallet(uuid, numeric, text, text) to authenticated;

-- -------------------------------------------------------------------------
-- 5) Collaboration payment dispute actions
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

  insert into public.user_wallets (user_id, balance, updated_at)
  values (v_pay.payee_id, 0, now())
  on conflict (user_id) do nothing;

  update public.user_wallets
  set balance = balance + v_pay.amount, updated_at = now()
  where user_id = v_pay.payee_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, created_by
  ) values (
    v_pay.payee_id,
    v_pay.amount,
    'credit',
    'Collaboration milestone payment (staff release): ' || coalesce(v_m.title, 'milestone'),
    auth.uid()
  );

  update public.collaboration_payments
  set status = 'released', released_at = now()
  where id = p_payment_id;

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    'collab_payment_released',
    'collaboration_payment',
    p_payment_id,
    'Staff force-released collaboration payment',
    jsonb_build_object('reason', v_reason, 'amount', v_pay.amount)
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  values
    (
      v_pay.payee_id,
      'Milestone payment released',
      'PKR ' || v_pay.amount::text || ' released for "' || coalesce(v_m.title, 'milestone') || '".',
      'collaboration_milestone',
      jsonb_build_object('collaboration_id', v_pay.collaboration_id, 'milestone_id', v_pay.milestone_id)
    ),
    (
      v_pay.payer_id,
      'Milestone payment released',
      'Staff released PKR ' || v_pay.amount::text || ' for "' || coalesce(v_m.title, 'milestone') || '" in ' || coalesce(v_title, 'project') || '.',
      'collaboration_milestone',
      jsonb_build_object('collaboration_id', v_pay.collaboration_id, 'milestone_id', v_pay.milestone_id)
    );
end;
$$;

create or replace function public.staff_refund_held_collaboration_payment(
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
begin
  if not public.is_staff() then
    raise exception 'Only staff can refund collaboration payments';
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

  if v_pay.status = 'refunded' then
    return;
  end if;

  if v_pay.status <> 'held' then
    raise exception 'Only held payments can be refunded';
  end if;

  select * into v_m from public.collaboration_milestones where id = v_pay.milestone_id;
  select title into v_title from public.collaborations where id = v_pay.collaboration_id;

  insert into public.user_wallets (user_id, balance, updated_at)
  values (v_pay.payer_id, 0, now())
  on conflict (user_id) do nothing;

  update public.user_wallets
  set balance = balance + v_pay.amount, updated_at = now()
  where user_id = v_pay.payer_id;

  insert into public.wallet_transactions (
    user_id, amount, txn_type, reason, created_by
  ) values (
    v_pay.payer_id,
    v_pay.amount,
    'credit',
    'Collaboration payment refund (staff): ' || coalesce(v_m.title, 'milestone'),
    auth.uid()
  );

  update public.collaboration_payments
  set status = 'refunded', released_at = now()
  where id = p_payment_id;

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    'collab_payment_refunded',
    'collaboration_payment',
    p_payment_id,
    'Staff refunded held collaboration payment',
    jsonb_build_object('reason', v_reason, 'amount', v_pay.amount)
  );

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_pay.payer_id,
    'Collaboration payment refunded',
    'PKR ' || v_pay.amount::text || ' refunded for "' || coalesce(v_m.title, 'milestone') || '". ' || v_reason,
    'collaboration_milestone',
    jsonb_build_object('collaboration_id', v_pay.collaboration_id, 'milestone_id', v_pay.milestone_id)
  );
end;
$$;

grant execute on function public.staff_force_release_collaboration_payment(uuid, text) to authenticated;
grant execute on function public.staff_refund_held_collaboration_payment(uuid, text) to authenticated;

-- -------------------------------------------------------------------------
-- 6) Extend report staff actions + process_user_report
-- -------------------------------------------------------------------------
alter table public.user_reports drop constraint if exists user_reports_staff_action_check;
alter table public.user_reports
  add constraint user_reports_staff_action_check
  check (staff_action is null or staff_action in ('none', 'workspace_hidden', 'user_suspended'));

create or replace function public.process_user_report(
  p_report_id uuid,
  p_status text,
  p_note text default null,
  p_staff_action text default 'none'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.user_reports%rowtype;
  v_actor_role text;
  v_notif_type text;
  v_notif_title text;
  v_notif_message text;
begin
  if not public.is_staff() then
    raise exception 'Only staff can process reports';
  end if;

  if p_status not in ('under_review', 'resolved', 'dismissed') then
    raise exception 'Invalid status';
  end if;

  select * into v_report
  from public.user_reports
  where id = p_report_id
  for update;

  if not found then
    raise exception 'Report not found';
  end if;

  if v_report.status in ('resolved', 'dismissed') then
    raise exception 'Report already closed';
  end if;

  if p_staff_action = 'workspace_hidden' and v_report.workspace_id is not null then
    update public.workspaces
    set is_available = false, updated_at = now()
    where id = v_report.workspace_id;
  end if;

  if p_staff_action = 'user_suspended' and v_report.reported_user_id is not null then
    perform public.staff_suspend_user(
      v_report.reported_user_id,
      coalesce(p_note, 'Suspended following user report: ' || v_report.subject)
    );
  end if;

  update public.user_reports
  set status = p_status,
      staff_action = case
        when p_status in ('resolved', 'dismissed') then coalesce(p_staff_action, 'none')
        else staff_action
      end,
      processed_by = auth.uid(),
      processed_at = now(),
      resolution_note = coalesce(p_note, resolution_note),
      updated_at = now()
  where id = p_report_id;

  select role into v_actor_role from public.users where id = auth.uid();

  perform public.log_staff_action(
    auth.uid(),
    coalesce(v_actor_role, 'staff'),
    case
      when p_status = 'under_review' then 'report_under_review'
      when p_status = 'resolved' then 'report_resolved'
      else 'report_dismissed'
    end,
    'user_report',
    p_report_id,
    case
      when p_status = 'under_review' then 'Report marked under review'
      when p_status = 'resolved' then 'Report resolved'
      else 'Report dismissed'
    end,
    jsonb_build_object(
      'report_type', v_report.report_type,
      'subject', v_report.subject,
      'staff_action', coalesce(p_staff_action, 'none'),
      'note', p_note
    )
  );

  v_notif_type := case
    when p_status = 'under_review' then 'report_under_review'
    when p_status = 'resolved' then 'report_resolved'
    else 'report_dismissed'
  end;

  v_notif_title := case
    when p_status = 'under_review' then 'Report under review'
    when p_status = 'resolved' then 'Report resolved'
    else 'Report dismissed'
  end;

  v_notif_message := case
    when p_status = 'under_review' then
      'Your report "' || v_report.subject || '" is being reviewed by our team.'
    when p_status = 'resolved' then
      'Your report "' || v_report.subject || '" has been resolved.'
      || case when p_note is not null then ' Note: ' || p_note else '' end
    else
      'Your report "' || v_report.subject || '" was reviewed and closed.'
      || case when p_note is not null then ' Note: ' || p_note else '' end
  end;

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_report.reporter_id,
    v_notif_title,
    v_notif_message,
    v_notif_type,
    jsonb_build_object('report_id', p_report_id, 'status', p_status)
  );
end;
$$;

grant execute on function public.process_user_report(uuid, text, text, text) to authenticated;

-- -------------------------------------------------------------------------
-- 7) Staff read access for collaboration hub tables
-- -------------------------------------------------------------------------
alter table public.collaboration_milestones enable row level security;
alter table public.collaboration_payments enable row level security;

drop policy if exists "milestones_select_staff" on public.collaboration_milestones;
create policy "milestones_select_staff"
  on public.collaboration_milestones for select
  using (public.is_staff());

drop policy if exists "collab_payments_select_staff" on public.collaboration_payments;
create policy "collab_payments_select_staff"
  on public.collaboration_payments for select
  using (public.is_staff());

drop policy if exists "collab_payments_update_staff" on public.collaboration_payments;
create policy "collab_payments_update_staff"
  on public.collaboration_payments for update
  using (public.is_staff())
  with check (public.is_staff());

-- Staff can read their own inbox notifications (already via user_id = auth.uid())
drop policy if exists "notif_select_self" on public.notifications;
create policy "notif_select_self"
  on public.notifications for select
  using (auth.uid() = user_id);

drop policy if exists "notif_select_staff_all" on public.notifications;
create policy "notif_select_staff_all"
  on public.notifications for select
  using (public.is_staff());

drop policy if exists "notif_update_self" on public.notifications;
create policy "notif_update_self"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
