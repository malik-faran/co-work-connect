-- 47: Safer milestone payment release (idempotent + clearer errors)
-- Run AFTER 46_collab_milestone_submission_notes.sql

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

  v_project_title := coalesce(v_collab.title, 'your project');

  insert into public.notifications (user_id, title, message, type, metadata)
  values (
    v_pay.payee_id,
    'Milestone payment released',
    'Payment of Rs ' || trim(to_char(v_pay.amount, '999,999,999.99'))
      || ' for "' || v_m.title || '" on "' || v_project_title || '" has been released to your wallet.',
    'collaboration_milestone_payment_released',
    jsonb_build_object(
      'collaboration_id', v_m.collaboration_id,
      'milestone_id', p_milestone_id,
      'milestone_title', v_m.title,
      'amount', v_pay.amount
    )
  );
end;
$$;

grant execute on function public.release_collaboration_milestone_payment(uuid) to authenticated;
