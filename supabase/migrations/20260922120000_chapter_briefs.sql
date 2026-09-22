-- Chapters 2-5 are written for THIS builder: before each one the app asks
-- four questions (tech skill, hours per week, budget, goal) plus an optional
-- note. The answers are stored per plan+chapter so the next sheet can prefill
-- them, and the model's chapter title/summary — until now discarded — land
-- on the same row.

create table if not exists public.chapter_briefs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  action_plan_id  uuid not null references public.action_plans(id) on delete cascade,
  chapter         integer not null check (chapter between 2 and 5),
  tech_skill      text not null check (tech_skill in ('none', 'no_code', 'can_code')),
  hours_per_week  text not null check (hours_per_week in ('few', 'evenings', 'full_time')),
  budget          text not null check (budget in ('zero', 'under_500', 'under_5k', 'more')),
  goal            text not null check (goal in ('side_income', 'quit_job', 'sell_it', 'curious')),
  notes           text check (notes is null or char_length(notes) <= 300),
  title           text,
  summary         text,
  created_at      timestamptz not null default now(),
  unique (action_plan_id, chapter)
);

create index if not exists chapter_briefs_user_created_idx
  on public.chapter_briefs (user_id, created_at desc);

alter table public.chapter_briefs enable row level security;

create policy "read own chapter briefs"
  on public.chapter_briefs for select to authenticated
  using (user_id = auth.uid());

create policy "insert own chapter briefs"
  on public.chapter_briefs for insert to authenticated
  with check (user_id = auth.uid());

create policy "update own chapter briefs"
  on public.chapter_briefs for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Five chapters, full stop: the original plan plus four Plus chapters.
-- Mirrored by MAX_CHAPTER in _shared/chapters.ts and ChapterLadder.maxChapters.
alter table public.micro_actions
  drop constraint if exists micro_actions_chapter_range;
alter table public.micro_actions
  add constraint micro_actions_chapter_range check (chapter between 1 and 5);
