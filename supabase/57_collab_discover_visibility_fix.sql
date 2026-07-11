-- 57: Ensure public recruiting projects are discoverable
-- Run in Supabase SQL Editor. Safe to re-run.
--
-- Symptom: User A's project not visible to User B, but B's project visible to A.
-- Cause: app used to hide Discover posts when owner had collaboration_enabled = false.
-- This backfills legacy rows so public recruiting projects are consistent.

update public.collaborations
set visibility = 'public'
where visibility is null;

update public.collaborations
set status = 'recruiting'
where status = 'open';

-- Optional: users who already posted public projects should be discoverable as teammates too
update public.users u
set collaboration_enabled = true,
    updated_at = now()
where coalesce(u.collaboration_enabled, false) = false
  and exists (
    select 1
    from public.collaborations c
    where c.user_id = u.id
      and c.status = 'recruiting'
      and coalesce(c.visibility, 'public') = 'public'
  );
