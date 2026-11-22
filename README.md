# Review Workspace — Milestone 2

Flutter Web UI prototype with five working navigation destinations: Dashboard, Import, Articles, Conflicts, Statistics. Fictional demo data only. Does not modify Supabase or upload files.

## Install into your existing project

1. Back up or commit your existing changes.
2. Copy the included `lib/` directory into the root of your existing Flutter project, replacing `lib/main.dart` and adding the other files.
3. Ensure `material_ui` is already included in your `pubspec.yaml` (it was installed in the prior milestone).
4. Run `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d chrome`.
5. If the old test expects widgets removed from the prototype, adapt the test.

No external package beyond `material_ui` is introduced by this deliverable.

## Architecture

- `lib/app/app.dart`: theme and responsive navigation
- `lib/screens/pages.dart`: pages, search filter, and UI-only placeholders
- `lib/widgets/summary_widgets.dart`: reusable cards, page frame, leaderboard
- `lib/data/demo_data.dart`: exclusively fictional sample articles and counts

## Next milestones

1. PostgreSQL/Supabase schema + RLS, authentication.
2. CSV column mapping and preview for Rayyan/ASReview, with export-specific validation.
3. Conflict discussion and third-author arbitration workflow.
4. Add tests, deployment to Vercel.
