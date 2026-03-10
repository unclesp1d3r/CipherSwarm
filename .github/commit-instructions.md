# Commit Message Style for project

Use Conventional Commits: `<type>(<scope>): <description>`

- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`
- **Scopes** (required): `campaign`, `task`, `agent`, `attack`, `api`, `job`, `auth`, `ui`, `docs`, `deps`, `ci`, `docker`, etc.
- **Description**: imperative, capitalized, ≤72 chars, no period
- **Body** (optional): blank line, bullet list, explain what/why
- **Footer** (optional): blank line, issue refs (`Closes #123`) or `BREAKING CHANGE:`
- **Breaking changes**: add `!` after type/scope or use `BREAKING CHANGE:`

Examples:

- `feat(campaign): add priority-based task preemption on priority change`
- `fix(task): handle abandoned tasks gracefully in assignment service`
- `docs(api): add OpenAPI examples for task submission endpoints`
- `chore(deps): update sidekiq to v7.3 for performance improvements`
