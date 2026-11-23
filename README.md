# Review Workspace

Collaborative web application for managing a literature review with three authors.

The current project is the **C. elegans review**.

## Overview

Review Workspace is a Flutter Web application designed to support a three-author literature review workflow.

The intended screening model is:

- Each article is independently screened by two authors.
- Disagreements are discussed by the original reviewers.
- A third author can arbitrate when consensus cannot be reached.
- Screening progress and reviewer activity are tracked centrally.
- Screening data can be imported from CSV exports from external screening platforms.

The application is currently in active development.

## Technology

### Frontend

- Flutter Web
- Dart
- Material 3

### Backend

- Supabase
- PostgreSQL
- Supabase Auth
- Supabase Edge Functions
- Supabase Storage

### Hosting

- Vercel

### Development and version control

- Android Studio
- GitHub
- Supabase CLI
- Vercel CLI

## Architecture

```text
Browser
   |
   v
Flutter Web
   |
   +--------------------+
   |                    |
   v                    v
Supabase Auth      Supabase API
                        |
                        v
                   PostgreSQL
                        |
          +-------------+-------------+
          |             |             |
       Projects      Articles     Screening
                                   decisions
                        |
                        v
                  Edge Functions
                        |
                        v
             Private Supabase Storage
```

The Flutter application is responsible for the user interface.

Supabase provides authentication, database access, Row Level Security, Edge Functions, and private backup storage.

Vercel hosts the compiled Flutter Web application.

## Database model

The current application data model includes:

- `projects`
- `project_members`
- `articles`
- `article_assignments`
- `screening_decisions`
- `conflict_messages`
- `conflict_resolutions`

Original screening decisions are kept separately from final consensus or arbitration decisions.

This allows us to preserve the screening audit trail and calculate reviewer agreement independently from conflict resolution.

## User roles

The current C. elegans review uses project-scoped roles.

### Administrator

The project administrator has additional administrative functionality, including backup management.

The current administrator is the first project member.

The administrator role is scoped to the C. elegans review project rather than being a global application-wide superuser.

### Reviewer

Reviewers can use the normal review workspace and screening functionality but do not have project administration privileges.

Administrative authorization is enforced by the backend and database policies. Hiding administrative navigation items in Flutter is not considered a security mechanism.

## Authentication

Users authenticate through Supabase Auth.

Public registration is disabled. Access is limited to invited project members.

The application checks project membership before exposing project data.

## Backup architecture

The application includes a project-scoped backup mechanism implemented with a Supabase Edge Function.

The backup is intentionally limited to review application data.

It does not attempt to export Supabase platform data such as:

- Supabase Auth
- unrelated projects
- system tables

The backup function verifies that the requesting user is an administrator for the requested project before generating a backup.

Privileged Supabase credentials remain server-side and are never placed in Flutter Web, Vercel client configuration, or source control.

The current backup scope includes the review application's core tables:

- `projects`
- `project_members`
- `articles`
- `article_assignments`
- `screening_decisions`
- `conflict_messages`
- `conflict_resolutions`

The backup is intended as an application-data backup, not as a full Supabase disaster-recovery backup.

## Current functionality

### Working

- Flutter Web application
- Responsive navigation
- Project dashboard
- Supabase authentication
- PostgreSQL integration
- Project and member retrieval
- PostgreSQL-side screening statistics
- Project-scoped administrator role
- Supabase Edge Function for application-data backup
- CSV file selection
- CSV parsing
- CSV preview
- CSV column mapping
- Vercel deployment

### In development

- CSV validation
- Duplicate detection
- Article collection import
- Reviewer assignment
- Screening-result import
- Conflict management UI
- Consensus and arbitration workflow
- Reviewer leaderboard based on real screening activity
- Automated Vercel deployments
- Additional application administration features

## Local development

### Requirements

Install:

- Flutter
- Dart
- Android Studio
- Node.js
- npm
- Git
- Supabase CLI
- Vercel CLI

The Supabase CLI and Vercel CLI may be installed locally through npm.

### Flutter dependencies

Install project dependencies:

```bash
flutter pub get
```

Analyze the project:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

### Running locally

The application requires the Supabase project URL and publishable key.

With fish shell:

```fish
set -x SUPABASE_URL 'https://YOUR_PROJECT.supabase.co'
set -x SUPABASE_PUBLISHABLE_KEY 'YOUR_PUBLISHABLE_KEY'
```

Then:

```fish
flutter run -d chrome \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY
```

### Important

Do not put Supabase secret keys, service-role keys, database passwords, or other privileged credentials into the Flutter application or GitHub repository.

## Supabase development

The repository contains version-controlled database migrations under:

```text
supabase/migrations/
```

Edge Functions are stored under:

```text
supabase/functions/
```

The local Supabase CLI project is linked to the hosted project.

Example:

```bash
npx supabase link --project-ref YOUR_PROJECT_REF
```

Deploy an Edge Function:

```bash
npx supabase functions deploy FUNCTION_NAME
```

Local Supabase CLI state and temporary files are intentionally excluded from Git.

## Vercel deployment

The production application is hosted on Vercel.

The current production domain is:

```text
https://review-workspace.vercel.app
```

Flutter is built locally before deployment:

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY
```

The resulting application is located in:

```text
build/web/
```

A prebuilt Vercel deployment can then be created with:

```bash
npx vercel build
npx vercel deploy --prebuilt --prod
```

## Security

This repository is public.

The repository therefore must never contain:

- Supabase secret keys
- Supabase service-role keys
- database passwords
- user passwords
- authentication tokens
- private backup files
- private research data

The Supabase publishable key may be present in a public client application. Database access is protected through authentication and PostgreSQL Row Level Security.

The `.gitignore` intentionally excludes:

```text
node_modules/
supabase/.temp/
.vercel/
.env
.env.*
```

## Current data policy

The repository contains application source code and development configuration.

Real review data should remain in the private Supabase environment and should not be committed to GitHub.

## Project roadmap

### Phase 1 — Foundation

- Flutter project
- GitHub repository
- Responsive UI
- Supabase integration
- Authentication

### Phase 2 — Review data

- PostgreSQL schema
- Screening statistics
- Reviewer activity
- Conflict management

### Phase 3 — Import workflow

- CSV preview
- Validation
- Duplicate detection
- Article import
- Screening-result import

### Phase 4 — Administration

- Project-scoped administrator role
- Backup management
- Audit and administrative tools

### Phase 5 — Production workflow

- Automated deployment
- Additional reliability checks
- Backup restoration testing
- Production data import

## Development principle

The application is intended for a small research team.

The design goal is to keep the workflow simple, transparent, and auditable while avoiding unnecessary duplication of functionality already provided by screening platforms such as Rayyan or ASReview.