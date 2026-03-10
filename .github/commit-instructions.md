# Commit Message Style for project

Use Conventional Commits: `<type>(<scope>): <description>`

- **Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`
- **Scopes** (required): `mmap`, `io`, `lib`, `api`, `safety`, `docs`, `test`, `ci`, `deps`, `security`, etc.
- **Description**: imperative, capitalized, ≤72 chars, no period
- **Body** (optional): blank line, bullet list, explain what/why
- **Footer** (optional): blank line, issue refs (`Closes #123`) or `BREAKING CHANGE:`
- **Breaking changes**: add `!` after type/scope or use `BREAKING CHANGE:`

Examples:

- `feat(mmap): add pre-flight stat check before mapping`
- `fix(io): handle empty files gracefully in map_file`
- `docs(api): add rustdoc examples for FileData`
- `chore(deps): update memmap2 to v0.9 for security patches`
