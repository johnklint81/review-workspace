# Review Workspace — Milestone 3 (PostgreSQL foundation)

This adds **only the database design**, not the Flutter/Supabase connection. Keep the Milestone 2 Flutter `lib/` files unchanged.

## Apply it

1. Create a new Supabase project (region close to your team), and store your database password securely.
2. In **SQL Editor**, open `supabase/migrations/20261122000100_initial_review_schema.sql` and execute it **once** on a new project. Alternatively, track and apply it with the Supabase CLI migrations workflow.
3. Confirm the seven tables exist in Database → Tables.
4. In Authentication → Users, create/invite the three authors. Do **not** disable Row Level Security.
5. Using the SQL editor (privileged admin context), add a project and its three memberships (see `docs/initial_setup.sql`). Replace placeholders with actual `auth.users.id` values.
6. Test with a **signed-in nonmember** before uploading real review data. Nonmembers must not see the project/articles; members must see only their project. Read `docs/security_checklist.md`.

## Schema design

- `projects`: review project
- `project_members`: permitted authors (links to Supabase Auth accounts)
- `articles`: one row per imported unique record
- `article_assignments`: exactly two intended reviewers per article; **at most two** enforced in DB, exactly two checked by importer
- `screening_decisions`: each assigned reviewer submits one immutable vote
- `conflict_messages`: discussion about genuinely conflicting articles
- `conflict_resolutions`: immutable final conflict outcome; original reviewer records consensus, unassigned reviewer records arbitration

The article-level final status can later be derived in the backend: fewer than two votes = incomplete; two matching votes = agreement; two different votes without resolution = conflict; resolution row = finalized. Don't count 2 votes as 2 unique articles.

### Important constraints

- The browser application has **read access only** to projects, members, articles, and assignments. It cannot create article imports/assignments; those require a trusted import pathway designed in the next milestone.
- Authenticated authors can insert only *their own assigned* screening decisions and *their own* conflict comments/resolutions. No editing/deleting original votes.
- The two-vote limit trigger is appropriate for the three-person workflow but bulk assignment/import logic must still handle duplicate/retry safely.
- Imported vote handling needs its own trusted, validated API or SQL transaction; existing decisions are immutable through the user-facing API.
- This is an **initial schema**, not a complete production system. Before real screening data: test RLS, import deduplication, concurrent writes, correction policy, backups, and the application's conflict status rules.

Do not commit your Supabase service role/secret key, database connection URL/password, or `.env` files to GitHub. Flutter Web can use the public/publishable key with authenticated sessions and RLS; never expose the service-role key.

## What to commit

Copy the `supabase/` and `docs/` folders into your existing project, then:

```sh
git add supabase docs
git commit -m "Add PostgreSQL schema and access controls"
git push
```

Official references: https://supabase.com/docs/guides/database/postgres/row-level-security and https://supabase.com/docs/guides/local-development/database-migrations
