-- Author-attributed model characterization, scoped to a review project.
create table public.model_characterizations (
 id uuid primary key default gen_random_uuid(),
 project_id uuid not null,
 article_id uuid not null,
 extractor_id uuid not null,
 status text not null default 'draft' check (status in ('draft','complete')),
 components jsonb not null default '[]'::jsonb check (jsonb_typeof(components) = 'array'),
 coupling_architecture text not null default '',
 feedback_loop text not null default 'not_assessed' check (feedback_loop in ('not_assessed','none','open_loop','partial','closed_loop','unclear')),
 parameter_provenance jsonb not null default '[]'::jsonb check (jsonb_typeof(parameter_provenance) = 'array'),
 parameter_notes text not null default '',
 calibration_notes text not null default '',
 validation_notes text not null default '',
 independent_validation text not null default 'unclear' check (independent_validation in ('yes','no','unclear','not_applicable')),
 code_availability text not null default '',
 data_availability text not null default '',
 parameter_documentation text not null default '',
 workflow_reproducibility text not null default '',
 evidence_notes text not null default '',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(project_id,article_id,extractor_id),
 foreign key (article_id) references public.articles(id) on delete cascade,
 foreign key (project_id) references public.projects(id),
 foreign key (extractor_id) references auth.users(id)
);
create index model_characterizations_project_idx on public.model_characterizations(project_id,article_id);
alter table public.model_characterizations enable row level security;
create policy "members read characterizations" on public.model_characterizations
 for select to authenticated using (exists (select 1 from public.project_members pm where pm.project_id = model_characterizations.project_id and pm.user_id = (select auth.uid())));
create policy "authors insert characterizations" on public.model_characterizations
 for insert to authenticated with check (extractor_id = (select auth.uid()) and exists (select 1 from public.project_members pm where pm.project_id = model_characterizations.project_id and pm.user_id = (select auth.uid())) and exists (select 1 from public.articles a where a.id = model_characterizations.article_id and a.project_id = model_characterizations.project_id));
create policy "authors update characterizations" on public.model_characterizations
 for update to authenticated using (extractor_id = (select auth.uid()) and exists (select 1 from public.project_members pm where pm.project_id = model_characterizations.project_id and pm.user_id = (select auth.uid())))
 with check (extractor_id = (select auth.uid()) and exists (select 1 from public.project_members pm where pm.project_id = model_characterizations.project_id and pm.user_id = (select auth.uid())) and exists (select 1 from public.articles a where a.id = model_characterizations.article_id and a.project_id = model_characterizations.project_id));
grant select,insert,update on public.model_characterizations to authenticated;
