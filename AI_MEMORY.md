## Library Workarounds

### PostgreSQL Binary Location on macOS

-   **Issue:** PostgreSQL binaries from `libpq` package are incomplete and don't support all options needed for testing
-   **Solution:** Always use binaries from Homebrew PostgreSQL installation at `/opt/homebrew/opt/postgresql@16/bin/`
-   **Date:** 2024-03-26

## Linter False Positives in /test Tree

-   **Issue:** Linter reports errors like 'No parameter named "id"' or similar when instantiating models in test files, especially for models inheriting fields from external libraries (e.g., fastapi-users' SQLAlchemyBaseUserTableUUID).
-   **Workaround:** These are false positives and do not affect test correctness or runtime. Suppress with `# type: ignore # noqa` if needed, or simply disregard in the test space. User will address linter suppression later if required.
-   **Scope:** Applies to any similar errors that are known to be false positives **in the `/test` tree**.
-   **Date:** 2024-07-01
