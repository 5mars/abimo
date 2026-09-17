-- Per-user, per-function, per-UTC-day AI usage counters.
-- Consumed exclusively through consume_ai_credit(); no direct client access.
create table public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day     date not null default (now() at time zone 'utc')::date,
  fn      text not null,
  count   int  not null default 0,
  primary key (user_id, day, fn)
);

alter table public.ai_usage enable row level security;
-- No policies: the table is invisible to PostgREST clients; only the
-- SECURITY DEFINER function below touches it.

-- Atomically consume one credit. Returns true if under the limit (and
-- increments), false once the daily budget for this function is spent.
-- Single statement => concurrent calls cannot race past the limit.
create or replace function public.consume_ai_credit(p_fn text, p_limit int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int;
begin
  if v_uid is null then
    return false;
  end if;

  insert into ai_usage as u (user_id, day, fn, count)
  values (v_uid, (now() at time zone 'utc')::date, p_fn, 1)
  on conflict (user_id, day, fn)
    do update set count = u.count + 1
    where u.count < p_limit
  returning u.count into v_count;

  -- NULL means the ON CONFLICT update was blocked by the WHERE => over limit.
  return v_count is not null;
end;
$$;

revoke all on function public.consume_ai_credit(text, int) from public;
revoke all on function public.consume_ai_credit(text, int) from anon;
grant execute on function public.consume_ai_credit(text, int) to authenticated;
