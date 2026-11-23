-- Milestone 7: project-scoped administration and backup support.
-- This does NOT create a global superuser. A user is an admin only within
-- the project row in public.project_members.

create type public.project_member_role as enum ('reviewer', 'admin');

alter table public.project_members
  add column role public.project_member_role not null default 'reviewer';

-- User 1 is the administrator for the existing C. elegans review project.
-- The UUID is the user ID already registered in project_members.
update public.project_members
set role = 'admin'
where user_id = '286fab74-c92d-413d-85c1-ea30c6e67c9e'::uuid;

-- Project-scoped admin check. This is a SECURITY DEFINER helper because
-- project_members is protected by RLS. The caller's identity is still checked.
create or replace function private.is_project_admin(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.user_id = (select auth.uid())
      and pm.role = 'admin'
  );
$$;

revoke all on function private.is_project_admin(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_project_admin(uuid) to authenticated;

-- Admins can manage the review project's administrative data.
grant update, delete on public.projects to authenticated;
grant insert, update, delete on public.project_members to authenticated;
grant insert, update, delete on public.articles to authenticated;
grant insert, delete on public.article_assignments to authenticated;

create policy projects_admin_update
on public.projects
for update to authenticated
using ((select private.is_project_admin(id)))
with check ((select private.is_project_admin(id)));

create policy projects_admin_delete
on public.projects
for delete to authenticated
using ((select private.is_project_admin(id)));

create policy members_admin_insert
on public.project_members
for insert to authenticated
with check ((select private.is_project_admin(project_id)));

create policy members_admin_update
on public.project_members
for update to authenticated
using ((select private.is_project_admin(project_id)))
with check ((select private.is_project_admin(project_id)));

create policy members_admin_delete
on public.project_members
for delete to authenticated
using ((select private.is_project_admin(project_id)));

create policy articles_admin_insert
on public.articles
for insert to authenticated
with check ((select private.is_project_admin(project_id)));

create policy articles_admin_update
on public.articles
for update to authenticated
using ((select private.is_project_admin(project_id)))
with check ((select private.is_project_admin(project_id)));

create policy articles_admin_delete
on public.articles
for delete to authenticated
using ((select private.is_project_admin(project_id)));

create policy assignments_admin_insert
on public.article_assignments
for insert to authenticated
with check ((select private.is_project_admin(project_id)));

create policy assignments_admin_delete
on public.article_assignments
for delete to authenticated
using ((select private.is_project_admin(project_id)));

-- Private Storage bucket for downloadable application-data backups.
-- The Edge Function uses its server-side secret and signed URLs; the browser
-- never receives Storage admin credentials.
insert into storage.buckets (id, name, public)
values ('review-backups', 'review-backups', false)
on conflict (id) do nothing;
