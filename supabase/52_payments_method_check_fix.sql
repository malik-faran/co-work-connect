-- 52: Fix payments_payment_method_check constraint violation
-- Run this if migration 19 fails with:
--   check constraint "payments_payment_method_check" of relation "payments" is violated
-- Safe to re-run.

alter table public.payments drop constraint if exists payments_payment_method_check;

-- Normalize any legacy / unknown values before re-adding the constraint
update public.payments
set payment_method = case
  when payment_method is null then 'manual'
  when lower(trim(payment_method)) in ('stripe', 'manual', 'cash', 'wallet', 'split')
    then lower(trim(payment_method))
  when lower(trim(payment_method)) in ('card', 'online') then 'stripe'
  when lower(trim(payment_method)) in ('bank', 'easypaisa', 'jazzcash', 'bank_transfer') then 'manual'
  else 'manual'
end
where payment_method is null
   or lower(trim(payment_method)) not in ('stripe', 'manual', 'cash', 'wallet', 'split');

alter table public.payments
  add constraint payments_payment_method_check
  check (payment_method in ('stripe', 'manual', 'cash', 'wallet', 'split'));
