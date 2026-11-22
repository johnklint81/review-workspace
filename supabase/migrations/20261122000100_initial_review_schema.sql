-- Review Workspace: initial database foundation.
-- Execute as the Supabase SQL editor's privileged database owner or via migrations.
-- App users cannot create projects, import articles, or manage assignments yet.
create extension if not exists pgcrypto;
create schema if not exists private;

create type public.screening_vote as enum ('include', 'exclude', 'maybe');
create type public.resolution_method as enum ('discussion', 'arbitration');

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 1 and 250),
  created_at timestamptz not null default now()
);

create table public.project_members (
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 100),
  created_at timestamptz not null default now(),
  primary key (project_id, user_id)
);
create index project_members_user_idx on public.project_members(user_id);

create table public.articles (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  source text not null check (source in ('rayyan', 'asreview', 'manual')),
  source_record_id text,
  doi text,
  title text not null check (length(btrim(title)) > 0),
  authors text,
  publication_year integer check (publication_year between 1800 and 2200),
  created_at timestamptz not null default now(),
  unique (project_id, id)
);
create unique index articles_source_record_unique on public.articles (project_id, source, source_record_id)
  where source_record_id is not null;
create index articles_project_idx on public.articles(project_id);
create index articles_doi_idx on public.articles(project_id, lower(doi)) where doi is not null;

create table public.article_assignments (
  project_id uuid not null,
  article_id uuid not null,
  reviewer_id uuid not null,
  assigned_at timestamptz not null default now(),
  primary key (article_id, reviewer_id),
  foreign key (project_id, article_id) references public.articles(project_id, id) on delete cascade,
  foreign key (project_id, reviewer_id) references public.project_members(project_id, user_id) on delete cascade
);
create index assignments_reviewer_idx on public.article_assignments(reviewer_id, project_id);

create table public.screening_decisions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  article_id uuid not null,
  reviewer_id uuid not null,
  vote public.screening_vote not null,
  submitted_at timestamptz not null default now(),
  source_import_id text,
  unique (article_id, reviewer_id),
  foreign key (project_id, article_id) references public.articles(project_id, id) on delete cascade,
  foreign key (article_id, reviewer_id) references public.article_assignments(article_id, reviewer_id)
);
create index decisions_project_article_idx on public.screening_decisions(project_id, article_id);
create index decisions_reviewer_idx on public.screening_decisions(reviewer_id);

create table public.conflict_messages (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  article_id uuid not null,
  author_id uuid not null,
  body text not null check (length(btrim(body)) between 1 and 10000),
  created_at timestamptz not null default now(),
  foreign key (project_id, article_id) references public.articles(project_id, id) on delete cascade,
  foreign key (project_id, author_id) references public.project_members(project_id, user_id)
);
create index conflict_messages_article_idx on public.conflict_messages(article_id, created_at);

create table public.conflict_resolutions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null,
  article_id uuid not null unique,
  method public.resolution_method not null,
  final_vote public.screening_vote not null,
  decided_by uuid not null,
  rationale text not null check (length(btrim(rationale)) between 1 and 10000),
  decided_at timestamptz not null default now(),
  foreign key (project_id, article_id) references public.articles(project_id, id) on delete cascade,
  foreign key (project_id, decided_by) references public.project_members(project_id, user_id)
);

-- Run cross-row validations server-side. No authenticated user can modify the
-- assignment table, so import/assignment operations must be handled as admin.
create function private.limit_two_reviewers() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select count(*) from public.article_assignments where article_id = new.article_id) >= 2 then
    raise exception 'An article may have at most two assigned reviewers';
  end if;
  return new;
end;
$$;
create trigger assignments_max_two before insert on public.article_assignments
for each row execute function private.limit_two_reviewers();

-- Verify decisions come from both assigned reviewers and differ. Only original
-- reviewers may record discussion consensus; only the third member may arbitrate.
create function private.validate_conflict_resolution() returns trigger
language plpgsql set search_path = '' as $$
declare
  total_votes integer;
  different_votes integer;
  is_assigned boolean;
begin
  select count(*), count(distinct vote) into total_votes, different_votes
  from public.screening_decisions where article_id = new.article_id;
  if total_votes <> 2 or different_votes < 2 then
    raise exception 'Resolution requires two conflicting screening decisions';
  end if;
  select exists(select 1 from public.article_assignments
       where article_id = new.article_id and reviewer_id = new.decided_by)
    into is_assigned;
  if new.method = 'discussion' and not is_assigned then
    raise exception 'Discussion outcome must be recorded by an original reviewer';
  end if;
  if new.method = 'arbitration' and is_assigned then
    raise exception 'Arbitration requires the third (unassigned) author';
  end if;
  return new;
end;
$$;
create trigger check_conflict_resolution before insert on public.conflict_resolutions
for each row execute function private.validate_conflict_resolution();

-- Avoid policy recursion on project_members by using a controlled helper.
create function private.is_project_member(p_project_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.project_members
    where project_id = p_project_id and user_id = (select auth.uid())
  );
$$;
revoke all on function private.is_project_member(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_project_member(uuid) to authenticated;

-- Explicit grants plus RLS: guests have no database privileges on these tables.
revoke all on public.projects, public.project_members, public.articles,
  public.article_assignments, public.screening_decisions,
  public.conflict_messages, public.conflict_resolutions from anon, authenticated;

grant select on public.projects, public.project_members, public.articles,
  public.article_assignments, public.screening_decisions,
  public.conflict_messages, public.conflict_resolutions to authenticated;
grant insert on public.screening_decisions, public.conflict_messages,
  public.conflict_resolutions to authenticated;

alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.articles enable row level security;
alter table public.article_assignments enable row level security;
alter table public.screening_decisions enable row level security;
alter table public.conflict_messages enable row level security;
alter table public.conflict_resolutions enable row level security;

create policy projects_read on public.projects for select to authenticated
  using ((select private.is_project_member(id)));
create policy members_read on public.project_members for select to authenticated
  using ((select private.is_project_member(project_id)));
create policy articles_read on public.articles for select to authenticated
  using ((select private.is_project_member(project_id)));
create policy assignments_read on public.article_assignments for select to authenticated
  using ((select private.is_project_member(project_id)));
create policy decisions_read on public.screening_decisions for select to authenticated
  using ((select private.is_project_member(project_id)));
create policy decisions_create on public.screening_decisions for insert to authenticated
  with check (
    reviewer_id = (select auth.uid())
    and (select private.is_project_member(project_id))
    and exists(select 1 from public.article_assignments a
      where a.article_id = screening_decisions.article_id
        and a.project_id = screening_decisions.project_id
        and a.reviewer_id = (select auth.uid()))
  );
create policy messages_read on public.conflict_messages for select to authenticated
  using ((select private.is_project_member(project_id)));
create policy messages_create on public.conflict_messages for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and (select private.is_project_member(project_id))
    and (select count(*) from public.screening_decisions d where d.article_id = conflict_messages.article_id) = 2
    and (select count(distinct d.vote) from public.screening_decisions d where d.article_id = conflict_messages.article_id) > 1
  );
create policy resolutions_read on public.conflict_resolutions for select to authenticated
  using ((select private.is_project_member(project_id)));
create policy resolutions_create on public.conflict_resolutions for insert to authenticated
  with check (decided_by = (select auth.uid()) and (select private.is_project_member(project_id)));

-- Note: no app-facing UPDATE/DELETE policies. Votes and resolutions are immutable;
-- a correction workflow will require an explicit audited migration/design.
