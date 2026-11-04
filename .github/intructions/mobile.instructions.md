---
applyTo: "mobile/**"
---

# APTraining Mobile Instructions

## Technology stack

The mobile application uses:

- Flutter
- Dart
- Riverpod
- GoRouter
- Drift
- SQLite
- HTTP/REST
- flutter_secure_storage
- Google Fonts / Inter

## Architecture

The mobile application is organized primarily by features.

Current features include:

- auth
- exercise
- planning
- workout

Common/shared functionality is located under:

- `lib/core/`
- `lib/shared/`

Respect the existing feature structure.

Do not automatically reorganize an existing feature just to make it match another feature.

## State management

Use Riverpod for application state.

Do not introduce another state-management solution unless explicitly requested.

Prefer the existing providers and controllers when extending a feature.

## Navigation

Use GoRouter for navigation.

Do not introduce an alternative navigation mechanism.

Inspect the existing router before adding or changing routes.

Remember that some existing features may not currently be registered in the router.

## Data access

The project uses a Repository Pattern.

The intended architecture separates:

- UI
- state management
- business/application logic
- repositories
- data sources

Drift/SQLite is used for local persistence.

The backend is accessed through REST APIs.

Some existing features may currently access the API more directly than the target architecture intends.

Do not refactor those existing implementations unless explicitly requested.

For new code, prefer the established repository/data separation when appropriate.

## Local database

Drift is used as the SQLite access layer.

Do not access SQLite directly from screens or widgets.

Keep database-specific logic inside the data/database layer.

## Design System

The project contains a custom Design System under `core/`.

Prefer existing:

- spacing constants
- radius constants
- sizes
- durations
- colors
- reusable widgets

Do not introduce arbitrary UI constants when an existing Design System value is appropriate.

Avoid unnecessary values such as:

`EdgeInsets.all(16)`

`SizedBox(height: 8)`

`BorderRadius.circular(12)`

when an equivalent Design System abstraction already exists.

Reuse existing widgets such as:

- AppScaffold
- AppPadding
- VSpace
- HSpace
- SearchField

before creating new equivalents.

## Typography

The application uses Inter through Google Fonts.

Prefer the existing typography/theme configuration rather than defining independent typography styles unnecessarily.

## UI

Follow the existing Material 3 configuration.

Prefer reusable widgets over duplicating UI structures.

Keep screens focused on composition and presentation.

Do not put large amounts of business logic directly inside widgets.

## API integration

Before implementing a new API integration:

1. Inspect the corresponding backend controller.
2. Inspect DTO/request/response models.
3. Inspect the service/business logic when relevant.
4. Identify the actual endpoint and HTTP method.
5. Identify request and response structures.
6. Check authentication requirements.
7. Check existing ApiClient behavior.

Do not invent endpoint names or JSON structures when the backend can be inspected.

## Authentication

The application uses access and refresh tokens.

Authentication-related changes must preserve the existing token management and refresh flow unless a different behavior is explicitly requested.

Do not expose tokens in logs or UI.

## Platform considerations

The Android development environment currently uses the local backend through the Android emulator.

The current development API configuration may use:

`10.0.2.2`

Do not assume that this address is valid for iOS, physical Android devices or production.

When changing API configuration, consider the target platform explicitly.

## Testing

When modifying mobile business logic, providers, controllers, repositories or database code, consider whether corresponding tests should be added or updated.

Before declaring a task complete, run the appropriate Flutter analysis/tests when practical.