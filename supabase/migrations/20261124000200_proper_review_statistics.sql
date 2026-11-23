-- Comprehensive, project-scoped review statistics.
-- Counts are calculated in PostgreSQL so the Flutter client does not need
-- to download the review dataset just to calculate aggregates.

create or replace function public.get_review_statistics(p_project_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_total_articles integer := 0;
  v_fully_assigned_articles integer := 0;
  v_required_decisions integer := 0;
  v_completed_decisions integer := 0;
  v_fully_screened integer := 0;
  v_partially_screened integer := 0;
  v_not_started integer := 0;
  v_screened_with_two integer := 0;
  v_agreements integer := 0;
  v_disagreements integer := 0;
  v_unresolved_conflicts integer := 0;
  v_resolved_by_discussion integer := 0;
  v_resolved_by_arbitration integer := 0;
  v_decision_completion_rate numeric := 0;
  v_assignment_completion_rate numeric := 0;
  v_agreement_rate numeric := 0;
  v_reviewer_stats jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.user_id = v_user_id
  ) then
    raise exception 'Project membership required' using errcode = '42501';
  end if;

  select count(*)::int
    into v_total_articles
    from public.articles a
   where a.project_id = p_project_id;

  select count(*)::int
    into v_fully_assigned_articles
    from (
      select aa.article_id
      from public.article_assignments aa
      where aa.project_id = p_project_id
      group by aa.article_id
      having count(*) = 2
    ) assigned;

  select count(*)::int
    into v_required_decisions
    from public.article_assignments aa
   where aa.project_id = p_project_id;

  select count(distinct (sd.article_id, sd.reviewer_id))::int
    into v_completed_decisions
    from public.screening_decisions sd
   where sd.project_id = p_project_id
     and exists (
       select 1
       from public.article_assignments aa
       where aa.project_id = sd.project_id
         and aa.article_id = sd.article_id
         and aa.reviewer_id = sd.reviewer_id
     );

  with per_article as (
    select
      a.id,
      count(distinct sd.reviewer_id) filter (
        where exists (
          select 1
          from public.article_assignments aa2
          where aa2.project_id = sd.project_id
            and aa2.article_id = sd.article_id
            and aa2.reviewer_id = sd.reviewer_id
        )
      )::int as completed_reviewers
    from public.articles a
    left join public.screening_decisions sd
      on sd.project_id = a.project_id
     and sd.article_id = a.id
    where a.project_id = p_project_id
    group by a.id
  )
  select
    count(*) filter (where completed_reviewers >= 2)::int,
    count(*) filter (where completed_reviewers = 1)::int,
    count(*) filter (where completed_reviewers = 0)::int
  into v_fully_screened, v_partially_screened, v_not_started
  from per_article;

  v_screened_with_two := v_fully_screened;

  with two_decisions as (
    select
      sd.article_id,
      count(distinct sd.reviewer_id) as reviewer_count,
      count(distinct sd.vote::text) as distinct_votes
    from public.screening_decisions sd
    where sd.project_id = p_project_id
      and exists (
        select 1
        from public.article_assignments aa
        where aa.project_id = sd.project_id
          and aa.article_id = sd.article_id
          and aa.reviewer_id = sd.reviewer_id
      )
    group by sd.article_id
    having count(distinct sd.reviewer_id) = 2
  )
  select
    count(*) filter (where distinct_votes = 1)::int,
    count(*) filter (where distinct_votes > 1)::int
  into v_agreements, v_disagreements
  from two_decisions;

  select count(*)::int
    into v_unresolved_conflicts
    from (
      select sd.article_id
      from public.screening_decisions sd
      where sd.project_id = p_project_id
        and exists (
          select 1
          from public.article_assignments aa
          where aa.project_id = sd.project_id
            and aa.article_id = sd.article_id
            and aa.reviewer_id = sd.reviewer_id
        )
      group by sd.article_id
      having count(distinct sd.reviewer_id) = 2
         and count(distinct sd.vote::text) > 1
    ) conflicts
    where not exists (
      select 1
      from public.conflict_resolutions cr
      where cr.project_id = p_project_id
        and cr.article_id = conflicts.article_id
    );

  select
    count(*) filter (where cr.method = 'discussion')::int,
    count(*) filter (where cr.method = 'arbitration')::int
  into v_resolved_by_discussion, v_resolved_by_arbitration
  from public.conflict_resolutions cr
  where cr.project_id = p_project_id;

  v_decision_completion_rate := case
    when v_required_decisions = 0 then 0
    else round((v_completed_decisions::numeric / v_required_decisions::numeric) * 100, 1)
  end;

  v_assignment_completion_rate := case
    when v_total_articles = 0 then 0
    else round((v_fully_assigned_articles::numeric / v_total_articles::numeric) * 100, 1)
  end;

  v_agreement_rate := case
    when (v_agreements + v_disagreements) = 0 then 0
    else round(
      (v_agreements::numeric / (v_agreements + v_disagreements)::numeric) * 100,
      1
    )
  end;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'user_id', x.user_id,
        'display_name', x.display_name,
        'assigned', x.assigned,
        'completed', x.completed,
        'remaining', greatest(x.assigned - x.completed, 0),
        'completion_rate', case
          when x.assigned = 0 then 0
          else round((x.completed::numeric / x.assigned::numeric) * 100, 1)
        end
      )
      order by x.completed desc, x.display_name
    ),
    '[]'::jsonb
  )
  into v_reviewer_stats
  from (
    select
      pm.user_id,
      pm.display_name,
      count(distinct aa.article_id)::int as assigned,
      count(distinct (sd.article_id, sd.reviewer_id))::int as completed
    from public.project_members pm
    left join public.article_assignments aa
      on aa.project_id = pm.project_id
     and aa.reviewer_id = pm.user_id
    left join public.screening_decisions sd
      on sd.project_id = pm.project_id
     and sd.reviewer_id = pm.user_id
     and exists (
       select 1
       from public.article_assignments aa2
       where aa2.project_id = sd.project_id
         and aa2.article_id = sd.article_id
         and aa2.reviewer_id = sd.reviewer_id
     )
    where pm.project_id = p_project_id
    group by pm.user_id, pm.display_name
  ) x;

  return jsonb_build_object(
    'total_articles', v_total_articles,
    'fully_assigned_articles', v_fully_assigned_articles,
    'assignment_completion_rate', v_assignment_completion_rate,
    'required_decisions', v_required_decisions,
    'completed_decisions', v_completed_decisions,
    'decision_completion_rate', v_decision_completion_rate,
    'fully_screened_articles', v_fully_screened,
    'partially_screened_articles', v_partially_screened,
    'not_started_articles', v_not_started,
    'screened_with_two_decisions', v_screened_with_two,
    'agreements', v_agreements,
    'disagreements', v_disagreements,
    'agreement_rate', v_agreement_rate,
    'unresolved_conflicts', v_unresolved_conflicts,
    'resolved_by_discussion', v_resolved_by_discussion,
    'resolved_by_arbitration', v_resolved_by_arbitration,
    'reviewer_stats', v_reviewer_stats
  );
end;
$$;

revoke all on function public.get_review_statistics(uuid) from public;
grant execute on function public.get_review_statistics(uuid) to authenticated;
