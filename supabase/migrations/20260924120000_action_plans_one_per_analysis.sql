-- One action plan per analysis.
--
-- Plan generation was check-then-insert on the client, so the pipeline's
-- auto-generate and the idea screen's "Get your action plan" could both
-- pass the "no plan yet" check and each save a copy. The client now
-- single-flights generation per analysis; this index is the backstop (a
-- losing insert gets 23505 and the client adopts the existing plan).

-- Clear existing duplicates first. Keep the plan with the most completed
-- steps (the one the founder actually worked), oldest on a tie. Deleting a
-- plan cascades to its micro_actions and chapter_briefs.
with ranked as (
    select p.id,
           row_number() over (
               partition by p.analysis_id
               order by (select count(*) from micro_actions m
                         where m.action_plan_id = p.id and m.is_completed) desc,
                        p.created_at asc
           ) as rn
    from action_plans p
    where p.analysis_id is not null
)
delete from action_plans
where id in (select id from ranked where rn > 1);

drop index if exists idx_action_plans_analysis;
create unique index if not exists action_plans_analysis_id_key
    on action_plans (analysis_id);
