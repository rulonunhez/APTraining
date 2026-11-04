# APTraining - AI Development Instructions

## Project overview

APTraining is a mobile application composed of two main projects:

- `mobile/`: Flutter/Dart mobile application.
- `backend/`: Java/Spring Boot REST API.

The projects are independent codebases that communicate through HTTP/JSON APIs.

When working on a feature that crosses the mobile/backend boundary, inspect both sides before proposing or implementing changes.

## General rules

- Preserve the existing architecture unless the user explicitly asks for a refactor.
- Do not reorganize existing folders or rename architectural layers without discussing it first.
- Prefer extending existing patterns over introducing new patterns.
- Reuse existing components, services, repositories, providers and utilities when appropriate.
- Do not introduce a new dependency unless it is necessary and the reason is clear.
- Before making significant changes, inspect the relevant existing implementation.
- For complex changes, explain the proposed approach before modifying files.
- Do not modify unrelated files.
- Keep changes focused on the requested feature.
- Do not invent APIs, models, fields or architectural conventions when they can be discovered from the existing code.
- When a feature involves both mobile and backend, verify the existing API contract before implementing the client side.

## Existing architecture vs target architecture

The codebase is evolving.

Some existing features may not perfectly follow the target architecture described in these instructions.

Do NOT automatically refactor existing code to make it conform.

For new code, follow the architectural conventions described in the relevant mobile or backend instructions.

If existing code follows a different pattern, preserve it unless the task explicitly requests a refactor or the new implementation requires a change.

## Code quality

- Prefer readable and maintainable code over clever solutions.
- Follow the existing naming conventions.
- Keep responsibilities separated.
- Avoid unnecessary duplication.
- Prefer small, focused classes and methods.
- Do not add abstractions merely for the sake of abstraction.

## Backend enum persistence

- Persist Java enums as strings with `@Enumerated(EnumType.STRING)` in `VARCHAR` columns.
- Do not use PostgreSQL native enum column types or `EnumType.ORDINAL` for application enums.
- Keep enum values constrained with a database `CHECK` constraint in a Flyway migration when the enum is persisted.
- Never edit an already-applied migration; add a new migration to change enum storage or allowed values.

## Safety

- Never expose, print, commit or modify secrets unnecessarily.
- Do not read or modify `.env` values unless explicitly required.
- Never place credentials, tokens, passwords or API keys directly into source code.
- Be careful when modifying authentication, security or database configuration.

## Communication

When asked to analyze something:

- Do not modify files unless explicitly requested.
- Clearly distinguish between:
  - current implementation
  - intended architecture
  - suggested improvements

When asked to implement something:

- First inspect the relevant existing code.
- Explain important architectural decisions when they are not obvious.
- Keep the implementation scoped to the requested change.