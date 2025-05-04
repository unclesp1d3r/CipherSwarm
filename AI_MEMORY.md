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
