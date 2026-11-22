# Milestone 4: authentication gate

This is a **patch**, not a complete Flutter project. Your existing app, Supabase initialization in `lib/main.dart`, `pubspec.yaml`, database and five screens stay in place.

## Files

- `lib/app/app.dart`: updated to put `AuthGate` in front of `WorkspaceShell`, and adds a sign-out button.
- `lib/app/auth_gate.dart`: new sign-in screen and project membership gate.
- `test/widget_test.dart`: replaces the old public-dashboard smoke test with data-model tests that do not require a live Supabase session.

## Install

1. Commit your working changes before copying files.
2. Copy `lib/app/app.dart` and `lib/app/auth_gate.dart` into your existing Flutter project's `lib/app/` directory.
3. Replace `test/widget_test.dart` with the file here.
4. Do **not** overwrite your existing `lib/main.dart`, which initializes Supabase.
5. Run `flutter analyze`, `flutter test`, then start Chrome with your `--dart-define` values.

## Account and project setup

In the Supabase Dashboard, create your author accounts with Authentication > Users > Add user (or invite them). Disable public signup under Authentication settings if you want invite-only accounts; not displaying signup in the UI does not disable the underlying signup endpoint.

**Do not paste credentials into SQL or GitHub.** After creating accounts, copy their UUIDs from Authentication > Users and execute the following SQL in the privileged Supabase SQL Editor, replacing all placeholder UUIDs and the project title:

```sql
with p as (
  insert into public.projects (title)
  values ('Our literature review')
  returning id
)
insert into public.project_members (project_id, user_id, display_name)
select p.id, v.user_id, v.display_name
from p
cross join (values
  ('AUTHOR_ONE_AUTH_UUID'::uuid, 'Author A'),
  ('AUTHOR_TWO_AUTH_UUID'::uuid, 'Author B'),
  ('AUTHOR_THREE_AUTH_UUID'::uuid, 'Author C')
) as v(user_id, display_name);
```

Do not execute the example SQL until all three accounts exist and the placeholders have been replaced. This inserts one project and registers its three authors in one transaction. If you need to add members to an existing project instead, use its actual UUID rather than creating a duplicate project.

## Test

- Unauthenticated user: sees only login.
- Authenticated author without `project_members` entry: sees 'No project access yet'.
- Authenticated member: sees the existing **demo** dashboard and can sign out.
- Confirm that an authenticated user who is not a member cannot SELECT project data through the Supabase API. The UI gate is not a substitute for RLS.

**No data import, password reset, invitations, or database-driven statistics are included yet.** This is a prototype step; verify backend privileges and RLS before using real research data.
