-- 32: Optional rollback for WebRTC call system (run only if you want DB cleanup)
-- Safe to skip — unused call_sessions table does not affect the app.

drop function if exists public.append_call_ice(uuid, text, jsonb);

drop table if exists public.call_sessions cascade;

do $$ begin
  alter publication supabase_realtime drop table public.call_sessions;
exception when undefined_object then null;
  when undefined_table then null;
end $$;
