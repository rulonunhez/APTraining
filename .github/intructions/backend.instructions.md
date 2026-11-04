---
applyTo: "backend/**"
---

# APTraining Backend Instructions

## Technology stack

The backend uses:

- Java 17
- Spring Boot 3.3.x
- Maven
- Spring Web
- Spring Security
- JWT authentication
- Spring Data JPA
- Hibernate
- PostgreSQL
- Flyway
- AWS S3

## Architecture

The backend follows a layered architecture.

Relevant layers include:

- controller
- service
- repository
- entity
- dto
- requests
- config

There are also domain-specific packages such as:

- auth
- catalogs

Respect the existing package organization.

## Controllers

Controllers expose the REST API.

Keep HTTP-specific concerns in controllers.

Do not move business logic into controllers.

Before adding an endpoint, inspect related existing controllers and follow their conventions.

## Services

Business logic belongs in services.

Reuse existing services where appropriate.

Do not duplicate business rules across controllers.

## Repositories

Repositories handle persistence through Spring Data JPA.

Do not place business logic inside repositories.

## Entities

Entities represent persisted domain objects.

Do not modify database entities casually.

Before changing an entity, inspect:

- existing relationships
- Flyway migrations
- DTOs
- services
- repositories
- API consumers

## DTOs and requests

Use DTO/request classes for API boundaries according to the existing project conventions.

Do not expose persistence entities unnecessarily through the REST API.

Inspect existing endpoints before deciding whether a new DTO is required.

## Database

PostgreSQL is the primary backend database.

Flyway manages schema migrations.

Database schema changes should be implemented through Flyway migrations following the existing migration conventions.

Do not modify an existing migration that may already have been applied.

Create a new migration when a schema change is required.

## Authentication and security

The backend uses Spring Security and JWT.

Authentication-related code requires particular care.

Do not:

- hard-code secrets
- expose tokens in responses unnecessarily
- log passwords or tokens
- weaken authentication rules to make development easier

Inspect the existing security configuration before modifying authentication behavior.

## API contract

The mobile application consumes this backend.

When changing an endpoint, consider the effect on:

`mobile/`

Before changing:

- endpoint paths
- HTTP methods
- request JSON
- response JSON
- authentication requirements
- multipart structures

inspect the corresponding Flutter implementation when possible.

## File uploads

Exercise/video functionality uses AWS S3.

Inspect the existing S3 service and related controller/service flow before implementing changes to file upload or retrieval behavior.

Do not expose credentials in source code.

## Development configuration

Development configuration may contain environment-specific values.

Do not commit secrets.

Do not modify `.env` values unless explicitly required.

## Testing

When modifying backend business logic, controllers, security or persistence, consider the appropriate automated tests.

Run the relevant Maven tests when practical.

## Logging and error handling

- Use SLF4J (`LoggerFactory`) for application logs; never use `System.out`, `System.err`, or `printStackTrace`.
- Log unexpected failures with the exception object so the stack trace is retained. Expected client errors should be logged at an appropriate lower level without noisy stack traces.
- Include the request correlation ID, HTTP method, and path when logging request failures. Return the correlation ID in error responses so clients can report it.
- Never log authorization headers, JWTs, passwords, request bodies, uploaded file contents, presigned URLs, or other secrets/PII.
- Keep request/access logging metadata-only; do not buffer or log multipart request bodies.
- Configure rolling log output and retention. Keep logs on stdout for container collection and use a configurable persistent log directory when file logs are required.
- Global exception handling must log server-side failures and return a safe message plus request ID; do not expose stack traces or infrastructure details to clients.
- Every log line that records an exception must include the exception class name and its message (`exception={} message={}`), so the cause is visible in the logs. For unexpected failures, also pass the exception object as the last argument so the stack trace is retained. Never include tokens, passwords or request bodies in those messages.
- Treat external service/storage failures as server-side errors, not client validation errors, and retain the original cause in the server log.
- Add or update tests for exception status, safe response shape, and request ID propagation when changing global error handling.