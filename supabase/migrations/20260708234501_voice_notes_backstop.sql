-- Backstop for clients that bypass the in-app 3-idea cap and insert
-- voice_notes directly via PostgREST: hard ceiling of 10 notes per user
-- per UTC day, regardless of tier.
create or replace function public.check_voice_note_daily_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from voice_notes
    where user_id = new.user_id
      and created_at >= date_trunc('day', now() at time zone 'utc')
  ) >= 10 then
    raise exception 'daily_note_limit' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger voice_notes_daily_cap
  before insert on public.voice_notes
  for each row execute function public.check_voice_note_daily_cap();
