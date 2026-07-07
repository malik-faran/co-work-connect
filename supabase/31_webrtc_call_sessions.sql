-- 31: WebRTC audio call signaling sessions
-- Realtime: run the ALTER PUBLICATION line below (or Database → Publications → supabase_realtime)

create table if not exists public.call_sessions (
  id uuid primary key,
  chat_room_id uuid not null references public.chat_rooms(id) on delete cascade,
  caller_id uuid not null references auth.users(id) on delete cascade,
  callee_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'ringing'
    check (status in ('ringing', 'accepted', 'rejected', 'ended', 'missed')),
  offer_sdp text,
  answer_sdp text,
  caller_ice jsonb not null default '[]'::jsonb,
  callee_ice jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz default now(),
  ended_at timestamptz
);

create index if not exists idx_call_sessions_callee_status
  on public.call_sessions (callee_id, status);
create index if not exists idx_call_sessions_caller_status
  on public.call_sessions (caller_id, status);
create index if not exists idx_call_sessions_chat_room
  on public.call_sessions (chat_room_id, created_at desc);

alter table public.call_sessions enable row level security;

drop policy if exists "Call participants can view sessions" on public.call_sessions;
create policy "Call participants can view sessions"
  on public.call_sessions for select
  using (auth.uid() in (caller_id, callee_id));

drop policy if exists "Caller can create call session" on public.call_sessions;
create policy "Caller can create call session"
  on public.call_sessions for insert
  with check (auth.uid() = caller_id);

drop policy if exists "Call participants can update sessions" on public.call_sessions;
create policy "Call participants can update sessions"
  on public.call_sessions for update
  using (auth.uid() in (caller_id, callee_id))
  with check (auth.uid() in (caller_id, callee_id));

-- Append ICE candidate without read-modify-write races
create or replace function public.append_call_ice(
  p_session_id uuid,
  p_side text,
  p_candidate jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_side not in ('caller', 'callee') then
    raise exception 'Invalid ICE side';
  end if;

  if not exists (
    select 1 from public.call_sessions
    where id = p_session_id
      and auth.uid() in (caller_id, callee_id)
  ) then
    raise exception 'Not allowed';
  end if;

  if p_side = 'caller' then
    update public.call_sessions
    set caller_ice = caller_ice || jsonb_build_array(p_candidate),
        updated_at = now()
    where id = p_session_id;
  else
    update public.call_sessions
    set callee_ice = callee_ice || jsonb_build_array(p_candidate),
        updated_at = now()
    where id = p_session_id;
  end if;
end;
$$;

grant execute on function public.append_call_ice(uuid, text, jsonb) to authenticated;

-- Enable Supabase Realtime for incoming call + ICE updates
do $$ begin
  alter publication supabase_realtime add table public.call_sessions;
exception when duplicate_object then null;
end $$;
