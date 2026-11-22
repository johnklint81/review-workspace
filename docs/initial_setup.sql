-- Run in the Supabase SQL Editor only, as a privileged admin.
-- Ensure users have already been invited/created in Supabase Auth.
-- Replace each placeholder UUID with actual auth.users.id values.
-- Execute once; do not commit real names/IDs into this example file.

insert into public.projects (title)
values ('My literature review')
returning id;

-- Copy the returned project UUID into the following SQL.
-- Un-comment after replacing placeholders:
-- insert into public.project_members (project_id, user_id, display_name) values
-- ('PROJECT_UUID', 'AUTHOR_1_AUTH_USER_UUID', 'Author A'),
-- ('PROJECT_UUID', 'AUTHOR_2_AUTH_USER_UUID', 'Author B'),
-- ('PROJECT_UUID', 'AUTHOR_3_AUTH_USER_UUID', 'Author C');

-- The application should NOT use a service role key in Dart/web.
