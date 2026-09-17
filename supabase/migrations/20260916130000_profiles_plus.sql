-- "Plus is the second chapter": the server learns who is a subscriber so it
-- can price-discriminate (daily AI caps, Plus-only functions) — and the
-- schema grows the two things Plus sells: more chapters and re-tastes.
--
-- Apply in the Supabase dashboard SQL editor (house pattern) AND keep this
-- file committed. Run BEFORE deploying the tier-aware edge functions.

-- 1. profiles — server-side entitlement mirror, written ONLY by the
--    verify-entitlement edge function (service role). Clients read their row.
create table if not exists public.profiles (
  user_id                 uuid primary key references auth.users(id) on delete cascade,
  is_premium              boolean not null default false,
  premium_expires_at      timestamptz,
  premium_product_id      text,
  original_transaction_id text,
  environment             text,             -- Production | Sandbox | Xcode
  freeze_bank             integer not null default 0,
  last_verified_at        timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select to authenticated
  using (auth.uid() = user_id);
-- No insert/update/delete policies: writes go through the service role.

-- Every auth user gets a row; backfill the ones that already exist.
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.handle_new_user_profile();

insert into public.profiles (user_id)
select id from auth.users
on conflict (user_id) do nothing;

-- 2. is_plus(uid): premium AND not expired (3-day grace for billing retry).
create or replace function public.is_plus(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.is_premium
        and (p.premium_expires_at is null or p.premium_expires_at > now() - interval '3 days')
     from public.profiles p where p.user_id = p_uid),
    false
  );
$$;

revoke all on function public.is_plus(uuid) from public;
grant execute on function public.is_plus(uuid) to authenticated, service_role;

-- 3. Tier-aware voice_notes backstop: free = 3 ACTIVE ideas (the in-app cap,
--    now enforced server-side); Plus keeps the 10/day abuse ceiling.
create or replace function public.check_voice_note_daily_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_plus(new.user_id) then
    if (select count(*) from voice_notes where user_id = new.user_id) >= 3 then
      raise exception 'idea_cap' using errcode = 'P0001';
    end if;
  end if;
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

-- 4. Plans grow in chapters; analyses keep a score history for re-tastes.
alter table public.micro_actions
  add column if not exists chapter integer not null default 1;

alter table public.swot_analyses
  add column if not exists score_history jsonb not null default '[]'::jsonb,   -- [{score, at, reason}]
  add column if not exists retaste_count integer not null default 0;

-- 5. Nightly: lapsed subscriptions lose Plus after the grace period even if
--    the app never reopens to re-sync. pg_cron may not be enabled on every
--    plan — skip quietly if it isn't.
do $$
begin
  perform 1 from pg_extension where extname = 'pg_cron';
  if found then
    perform cron.schedule(
      'expire-lapsed-plus',
      '17 3 * * *',
      $cron$
        update public.profiles
           set is_premium = false, updated_at = now()
         where is_premium
           and premium_expires_at is not null
           and premium_expires_at < now() - interval '3 days'
      $cron$
    );
  else
    raise notice 'pg_cron not installed — enable it and schedule expire-lapsed-plus manually';
  end if;
exception when others then
  raise notice 'pg_cron schedule skipped: %', sqlerrm;
end;
$$;
