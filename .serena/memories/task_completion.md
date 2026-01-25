# Task Completion Checklist

- Run relevant tests (targeted specs, JS tests, or `just test` for full). For system/UI work, run `bundle exec rspec spec/system/...`. For JS controllers, run `bun test:js`.
- If changes touch styles/components, check component specs and system specs. Ensure Turbo/Stimulus behaviors are covered.
- Lint/format if needed: `just format`, `just lint`, `just check` before PR.
- Ensure migrations are generated via Rails generators; verify schema and rollback path.
- Update documentation if behavior or endpoints change (README, docs/, swagger via `just docs-api`).
- Verify logging remains structured and no sensitive data leaks; include context.
- For PRs: keep changes small, follow conventional commits, ensure tests pass, and review coverage if toggled (`COVERAGE=true`).
- Confirm real-time broadcasts (Turbo Streams) are stable; use `perform_enqueued_jobs` in tests to avoid flakiness.
- Clean up: remove debug output, ensure factories and page objects updated, ensure seeds unaffected.
- Summarize changes and test commands in the final message.
