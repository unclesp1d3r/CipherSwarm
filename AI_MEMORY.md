## Library Workarounds

### PostgreSQL Binary Location on macOS

-   **Issue:** PostgreSQL binaries from `libpq` package are incomplete and don't support all options needed for testing
-   **Solution:** Always use binaries from Homebrew PostgreSQL installation at `/opt/homebrew/opt/postgresql@16/bin/`
-   **Date:** 2024-03-26

## Datetime Best Practices

-   Always use timezone-aware alternatives (e.g., datetime.now(datetime.UTC)) instead of datetime.utcnow() to prevent DTZ003 lint errors and ensure correct, portable time handling throughout the codebase.
-   All datetime fields in SQLAlchemy models and Alembic migrations must use `DateTime(timezone=True)`.
-   All test data and application code must use timezone-aware datetimes (e.g., `datetime.now(UTC)`).
-   This enforcement prevents offset-naive/aware errors and ensures compatibility with PostgreSQL and asyncpg.

### FastAPI Redundant response_model Linter Rule (FAST001)

-   **Issue:** The linter rule FAST001 flags redundant `response_model` arguments on FastAPI routes. Including unnecessary `response_model` can cause linter failures and is not required if the return type is already explicit or not needed for OpenAPI.
-   **Established Pattern:** Do not add `response_model` to FastAPI route decorators unless it is required for OpenAPI documentation or type validation. Remove `response_model` if flagged as redundant by FAST001.
-   **Date:** 2024-07-01

### v1/v2 API Compat Layer - Header Handling and File Routing

-   **Issue:** The v1 `/client` endpoints were handled by a compat layer (`client_compat.py`) that inherited header requirements from v2, specifically requiring a `User-Agent` header not present in the v1 OpenAPI contract. This caused 422/500 errors when the header was missing, and persistent test failures.
-   **Workaround:** Ensure that v1 compat endpoints do not require or validate headers not present in the v1 contract. Make all such headers optional and provide safe defaults when calling v2 logic. Always check which file actually handles a route in production, and remove unused/legacy files to avoid confusion during debugging.
-   **Date:** 2024-07-08

## Project Troubleshooting

### Debugging API Routing and Handler Execution

-   **Lesson:** Never assume a file or function is in use based on naming or directory structure. Always verify which handler is actually registered and executed by tracing imports and router registrations.
-   **Practice:** When debugging endpoint issues, add direct print/log statements at the start of handlers to confirm execution. If a handler is not entered, check router registration and imports before investigating logic bugs.
-   **Directive:** If persistent test failures occur, especially with status codes or handler entry, use explicit debug output and route registration checks before making code changes. Remove or rename unused files to prevent confusion.
-   **Date:** 2024-07-08
