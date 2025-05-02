## Library Workarounds

### PostgreSQL Binary Location on macOS

-   **Issue:** PostgreSQL binaries from `libpq` package are incomplete and don't support all options needed for testing
-   **Solution:** Always use binaries from Homebrew PostgreSQL installation at `/opt/homebrew/opt/postgresql@16/bin/`
-   **Date:** 2024-03-26
