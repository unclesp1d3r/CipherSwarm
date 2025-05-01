# Commit Message Convention

This project follows the [Conventional Commits](https://www.conventionalcommits.org) specification.

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types

- `feat`: A new feature (MINOR version)
- `fix`: A bug fix (PATCH version)
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `chore`: Changes to the build process or auxiliary tools and libraries

## Scopes

- `(auth)`: Authentication and authorization
- `(api)`: API endpoints and routes
- `(cli)`: Command-line interface
- `(models)`: Data models and schemas
- `(docs)`: Documentation
- `(deps)`: Dependencies

## Description Guidelines

- Use imperative mood ("add" not "added")
- Capitalize first word
- No period at the end
- Keep it concise (under 72 characters)
- Be specific about the change

## Breaking Changes

Indicate breaking changes in one of two ways:

1. With a `!` before the colon:

```
feat(api)!: remove deprecated endpoints
```

2. In the footer:

```
feat(api): add new authentication flow

BREAKING CHANGE: old authentication endpoints are removed
```

## Examples

### Feature with Multiple Changes

```
feat(auth): add OAuth2 support

- Add OAuth2 authentication flow
- Support token refresh
- Add token validation
- Update documentation with OAuth2 setup
- Add OAuth2 configuration options

Closes #123
```

### Bug Fix

```
fix(api): handle null values in response

- Add null checks for all response fields
- Set default values for optional fields
- Update error handling for null cases
- Add test cases for null value handling
- Update API documentation

Fixes #456
```

### Documentation Update

```
docs: update README with installation instructions

- Add detailed steps for setting up the development environment
- Include MongoDB setup instructions
- Add troubleshooting section
- Update dependency installation steps
- Add environment variable configuration guide
```

### Breaking Change

```
feat(api)!: remove deprecated endpoints

- Remove /api/v1/old-auth endpoint
- Remove /api/v1/legacy-users endpoint
- Update API documentation
- Add migration guide for affected clients

BREAKING CHANGE: The following endpoints are removed:
- /api/v1/old-auth
- /api/v1/legacy-users
```

## Key Rules

1. Use itemized lists for multiple changes
2. Reference issues in footer (e.g., "Fixes #123")
3. Use present tense
4. Be specific and concise
5. Capitalize first word
6. No period at the end
7. Use `!` for breaking changes in type/scope
8. Use `BREAKING CHANGE:` in footer for detailed breaking changes
9. Each commit should be a single logical change
10. Include tests and documentation updates in the same commit when relevant
