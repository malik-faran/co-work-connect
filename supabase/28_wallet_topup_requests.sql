-- 28: Wallet top-up requests table (manual payment verification flow)

create table if not exists public.wallet_topup_requests (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null check (amount > 0),
  platform_account_id uuid references public.platform_payment_accounts(id),
  receipt_url text,
  transfer_reference text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now()
);

alter table public.wallet_topup_requests enable row level security;

create policy "Users can view own topup requests"
  on public.wallet_topup_requests for select
  using (auth.uid() = user_id);

create policy "Users can insert own topup requests"
  on public.wallet_topup_requests for insert
  with check (auth.uid() = user_id);

-- RPC for admin/moderator to approve a top-up request.
create or replace function public.approve_topup_request(p_request_id uuid, p_reviewer_id uuid)
returns void
language plpgsql security definer
as $$
declare
  v_user_id uuid;
  v_amount numeric;
  v_status text;
begin
  select user_id, amount, status into v_user_id, v_amount, v_status
    from public.wallet_topup_requests where id = p_request_id;

  if v_user_id is null then
    raise exception 'Top-up request not found';
  end if;
  if v_status != 'pending' then
    raise exception 'Request already processed';
  end if;

  update public.wallet_topup_requests
    set status = 'approved', reviewed_by = p_reviewer_id,
        reviewed_at = now(), updated_at = now()
    where id = p_request_id;

  perform public.top_up_wallet(v_user_id, v_amount);
end;
$$;

grant execute on function public.approve_topup_request(uuid, uuid) to authenticated;
