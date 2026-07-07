-- 27: Wallet top-up RPC + chat message edit support

-- Wallet top-up: creates wallet if not exists, credits amount, logs transaction.
create or replace function public.top_up_wallet(p_user_id uuid, p_amount numeric)
returns void
language plpgsql security definer
as $$
begin
  if p_amount <= 0 then
    raise exception 'Amount must be greater than 0';
  end if;

  insert into public.user_wallets (user_id, balance, currency)
  values (p_user_id, p_amount, 'PKR')
  on conflict (user_id) do update
    set balance = user_wallets.balance + p_amount,
        updated_at = now();

  insert into public.wallet_transactions (id, user_id, amount, txn_type, reason, created_at)
  values (gen_random_uuid(), p_user_id, p_amount, 'credit', 'Wallet top-up', now());
end;
$$;

grant execute on function public.top_up_wallet(uuid, numeric) to authenticated;

-- Add is_edited flag and edited_at to messages table
alter table public.messages add column if not exists is_edited boolean default false;
alter table public.messages add column if not exists edited_at timestamptz;
