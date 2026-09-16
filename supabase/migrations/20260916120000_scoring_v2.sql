-- Scoring v2: persist the evidence behind every viability score so the
-- distribution is measurable and each number is auditable.
--
-- Apply in the Supabase dashboard SQL editor (house pattern) AND keep this
-- file committed. The new swot_analyses columns MUST exist before an iOS
-- build that encodes them ships — the client inserts the whole struct.

-- 1. Display fields on the analysis row (written by the iOS client).
alter table public.swot_analyses
  add column if not exists scoring_version    integer,
  add column if not exists verdict_band       text,
  add column if not exists verdict_reason     text,
  add column if not exists dimension_evidence jsonb,   -- {problemSeverity: "...", ...}
  add column if not exists score_meta         jsonb,   -- weights, raw, mapped, caps[], adjustments[], hedged, bandMismatch
  add column if not exists evidence_strength  text,    -- none | thin | ok | rich
  add column if not exists fatal_flaw_reason  text,
  add column if not exists research_digest    jsonb,   -- snapshot used for this score
  add column if not exists score_audit_id     uuid;

-- 2. Server-written audit: one row per scoring call, independent of whether
--    the client ever saves the analysis. This is what calibration reads.
create table if not exists public.score_audits (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  created_at           timestamptz not null default now(),
  transcription_sha256 text not null,
  scoring_version      integer not null,
  viability_score      integer not null check (viability_score between 0 and 100),
  verdict_band         text,
  computed_band        text,
  dimension_scores     jsonb not null,      -- post-cap, what the app shows
  raw_dimension_scores jsonb not null,      -- pre-cap, as the model said
  dimension_evidence   jsonb not null,
  founder_evidence     jsonb,
  research_digest      jsonb,
  evidence_strength    text,
  score_meta           jsonb not null,
  model                text,
  is_pivot             boolean not null default false,
  is_calibration       boolean not null default false
);

alter table public.score_audits enable row level security;

drop policy if exists "own audits" on public.score_audits;
create policy "own audits" on public.score_audits
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists score_audits_created_at_idx
  on public.score_audits (created_at);
create index if not exists score_audits_version_calibration_idx
  on public.score_audits (scoring_version, is_calibration);

-- 3. Research digests keyed by transcript hash, so analyze-swot can pick up
--    the structured digest even when an older app build forwards only the
--    legacy prose fields.
create table if not exists public.research_digests (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  transcription_sha256 text not null,
  digest               jsonb not null,
  created_at           timestamptz not null default now()
);

alter table public.research_digests enable row level security;

drop policy if exists "own digests" on public.research_digests;
create policy "own digests" on public.research_digests
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists research_digests_lookup_idx
  on public.research_digests (user_id, transcription_sha256, created_at desc);

-- Both new tables cascade from auth.users, so delete_user_account() needs no change.
