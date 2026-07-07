-- 36: User can withdraw a pending refund/cancellation request (undo mistaken cancel)
-- Run in Supabase SQL Editor after 35_refund_policy_24h.sql

create or replace function public.user_cancel_refund_request(p_refund_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_refund public.refund_requests%rowtype;
begin
  select * into v_refund
  from public.refund_requests
  where id = p_refund_id
  for update;

  if not found then
    raise exception 'Cancellation request not found';
  end if;

  if v_refund.user_id <> auth.uid() then
    raise exception 'Not your cancellation request';
  end if;

  if v_refund.status <> 'pending' then
    raise exception 'Only pending cancellation requests can be undone';
  end if;

  delete from public.refund_requests where id = p_refund_id;
end;
$$;

grant execute on function public.user_cancel_refund_request(uuid) to authenticated;
