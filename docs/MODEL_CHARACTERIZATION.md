# Model characterization — first implementation

This is a **first working extraction form**, not yet a complete systematic-review extraction system. It supports separate author-attributed drafts and structured information for the six review questions.

## Install

Copy the two Dart files into `lib/screens/` and `lib/services/`, and the SQL migration into `supabase/migrations/`.

**Before applying to production:** test the migration against the local Supabase stack (`npx supabase start` then `npx supabase db reset`). Review RLS policies against your existing schema and confirm that project members cannot write into other projects. Then run `npx supabase db push --remote` after checking the target.

In `lib/app/app.dart`, add:

```dart
import '../screens/model_characterization_page.dart';
```

Extend the navigation titles/icons with `Model characterization` and `Icons.science_outlined`, and extend the `page` switch to render `const ModelCharacterizationPage()` for the new destination. **Keep the Administration index and admin-only visibility correct** when adding a new destination; use a named destination model rather than relying on an index that can change.

Then run:

```sh
dart format lib/screens/model_characterization_page.dart lib/services/model_characterization_service.dart
flutter analyze
flutter test
```

## Scope and caveats

- This initial version lists **all project articles**, because the existing schema has no verified full-text inclusion status. Do not interpret this as evidence that every listed article is eligible; only extract included studies after manual eligibility assessment.
- Each author has a separate record for each article. There is no adjudicated consensus extraction yet.
- The database uses row-level security: project members can read the project's extractions, but only edit their own.
- `Mark complete` is a workflow label, not a validated quality gate.
- `model_characterizations` is **not yet included** in the existing seven-table JSON backup. Extend the Edge Function and restore procedure before relying on backups for this data.
- For large reviews, add pagination and a study/model-level entity: one paper can describe several models.
- The schema stores notes and URLs as text; later iterations should add evidence-location and per-parameter structured records.
