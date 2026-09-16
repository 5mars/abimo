-- Score distribution checks — run in the Supabase dashboard SQL editor.
-- Rows without scoring_version are v1 (pre-2026-09 recipe).

-- 1. 10-point histogram per scoring version
select coalesce(scoring_version, 1)                 as version,
       width_bucket(viability_score, 0, 100, 10)    as bucket,   -- 1 = 0-9, 6 = 50-59
       count(*)                                      as n
from public.swot_analyses
where viability_score is not null
group by 1, 2
order by 1, 2;

-- 2. Spike check: most common exact values (a pile at 58/59 = the old band seam)
select coalesce(scoring_version, 1) as version, viability_score, count(*) as n
from public.swot_analyses
where viability_score is not null
group by 1, 2
order by 3 desc
limit 15;

-- 3. Mid-cluster share and spread per version
select coalesce(scoring_version, 1)                                  as version,
       count(*)                                                       as n,
       round(avg(viability_score), 1)                                 as mean,
       round(stddev(viability_score), 1)                              as sd,
       round(100.0 * count(*) filter (where viability_score between 50 and 65) / count(*), 1) as pct_mid
from public.swot_analyses
where viability_score is not null
group by 1;

-- 4. Audit-only: how often each evidence cap bites (v2, real users)
select cap ->> 'dim' as dim, cap ->> 'reason' as reason, count(*) as n
from public.score_audits,
     jsonb_array_elements(score_meta -> 'caps') as cap
where scoring_version = 2 and not is_calibration
group by 1, 2
order by 3 desc;

-- 5. How often the model's band disagrees with the computed band
select scoring_version,
       round(avg((score_meta ->> 'bandMismatch')::boolean::int), 3) as mismatch_rate,
       round(avg((score_meta ->> 'hedged')::boolean::int), 3)       as hedge_rate,
       count(*)                                                     as n
from public.score_audits
where not is_calibration
group by 1;

-- 6. Calibration runs only (from scripts/calibration-test.sh)
select transcription_sha256, scoring_version,
       count(*) as runs,
       round(avg(viability_score), 1) as mean,
       round(stddev(viability_score), 1) as sd,
       min(viability_score) as lo, max(viability_score) as hi
from public.score_audits
where is_calibration
group by 1, 2
order by 3 desc;
