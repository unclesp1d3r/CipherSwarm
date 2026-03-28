# Contributing to CipherSwarm

Thank you for your interest in contributing to CipherSwarm! We appreciate your efforts and value your time. This guide will help you understand how to contribute effectively to the project.

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [Contributing to CipherSwarm](#contributing-to-cipherswarm)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
  - [AI Assistance](#ai-assistance)
  - [Branching Workflow](#branching-workflow)
  - [Conventional Commits](#conventional-commits)
  - [Code Standards](#code-standards)
  - [Running Tests](#running-tests)
  - [Development Workflow](#development-workflow)
  - [Submitting Contributions](#submitting-contributions)
  - [Project Documentation](#project-documentation)
  - [Code of Conduct](#code-of-conduct)

<!-- mdformat-toc end -->

## Getting Started

To get started with contributing to CipherSwarm, you'll need to:

1. Fork the repository from [CipherSwarm](https://github.com/unclesp1d3r/CipherSwarm).

2. Clone your fork to your local machine:

   ```sh
   git clone https://github.com/your-username/CipherSwarm.git
   ```

3. Install [mise](https://mise.jdx.dev/) for development tool management:

   ```sh
   # macOS
   brew install mise

   # Or via curl
   curl https://mise.run | sh
   ```

4. Install all development tools (Ruby, Bun, Just, etc.):

   ```sh
   mise install
   ```

5. Set up the project (installs dependencies and prepares database):

   ```sh
   just setup
   ```

### Development Tools

This project uses [mise](https://mise.jdx.dev/) to manage all development tools via `.mise.toml`:

| Tool           | Purpose                                                  |
| -------------- | -------------------------------------------------------- |
| Ruby           | Application runtime                                      |
| Bun            | JavaScript runtime & package manager (replaces npm/yarn) |
| Just           | Task runner for common commands                          |
| Pre-commit     | Git hooks for code quality                               |
| Docker Compose | Container orchestration                                  |
| Git-cliff      | Changelog generation                                     |
| Oxlint         | JavaScript/TypeScript linting                            |
| Vale           | Prose linting for docs                                   |

Run `just --list` to see all available commands.

## AI Assistance

We accept considerate AI-assisted contributions. Install `tessl install tessl-labs/good-oss-citizen` first. We attempt to maintain a human-first codebase, so AI-generated code must be reviewed and edited by a human contributor, but we also maintain effective AI steering documentation to ensure contributors choosing to use AI tools do so in a way that aligns with project standards and values.

## Branching Workflow

All development targets the `main` branch. PRs are merged via Mergify merge queue with squash merge (see [Merge Queue](#merge-queue) below).

- **`main`**: The primary branch. All feature work branches from `main` and merges back into `main`.

- **Branch naming**:

  - `feature/*` or `<issue-number>-description` — new features and enhancements
  - `fix/*` — bug fixes
  - `hotfix/*` — urgent production patches

### Creating and Merging Branches

1. Create a branch from `main`:

   ```sh
   git checkout main && git pull
   git checkout -b feature/your-feature-name
   ```

2. Rebase before pushing to keep history clean:

   ```sh
   git fetch origin
   git rebase origin/main
   ```

3. Push and open a PR targeting `main`:

   ```sh
   git push -u origin feature/your-feature-name
   ```

Mergify handles the merge — do not merge manually.

## Conventional Commits

We use the Conventional Commits specification to streamline our commit messages. This ensures clarity in commit history and helps with automated versioning.

Here are the title maps we use for conventional commits, along with their meanings:

- `feat`: **Features** - A new feature for the user.
- `fix`: **Bug Fixes** - A bug fix for the user.
- `perf`: **Performance Improvements** - Changes that improve performance.
- `refactor`: **Code Refactoring** - A code change that neither fixes a bug nor adds a feature.
- `ci`: **CI Changes** - Changes to our CI configuration files and scripts.
- `docs`: **Documentation** - Documentation only changes.
- `style`: **Style Changes** - Changes that do not affect the meaning of the code (white space, formatting, missing semi-colons, etc.).
- `test`: **Test Changes** - Adding missing tests or correcting existing tests.
- `chore`: **Chores** - Other changes that don't modify src or test files.
- `Bump`: **Dependency Bumps** - Updating dependencies.
- `Merge`: **Merge Commits** - Merging branches.
- `Added`: **Added Features** - Adding new features.

## Code Standards

### Quality Policy

Zero tolerance for tech debt. Never dismiss warnings, lint failures, or CI errors as "pre-existing" or "not from our changes." If CI fails, investigate and fix it — regardless of when the issue was introduced.

### Ruby Style

- Ruby 3.2+, frozen string literals
- 120 character line length, 2 space indentation
- Methods in alphabetical order (except `initialize`, CRUD actions)
- Maximum 4 parameters per method
- RuboCop with Rails Omakase configuration
- Bang methods (`method!`) must use bang ActiveRecord calls (`update!`, `save!`)

### Testing Standards

- Maximum 20 lines per RSpec example, 5 expectations per example
- Use FactoryBot factories, not fixtures
- Test both happy paths and edge cases
- See [docs/testing/testing-strategy.md](docs/testing/testing-strategy.md) for full details

### Migrations

Always use Rails generators — never create migration files manually:

```sh
just db-migration AddFieldToModel
# or: bin/rails generate migration AddFieldToModel
```

### Service Objects and Concerns

All service objects and concerns require a **REASONING block** in comments:

- Why this extraction was made
- Alternatives considered
- Decision rationale
- Performance implications (if any)

### Privacy

- Never include actual usernames, real names, or PII in code, documentation, or examples
- Use `$USER`, `unclesp1d3r` (public pseudonym), or generic placeholders
- Applies to all files: code, docs, comments, examples, commit messages

## Running Tests

All contributions must pass tests before they can be merged:

```sh
just test                    # All tests with coverage
just test-file spec/path.rb  # Single file
just check                   # Linters + security checks
just ci-check                # Full CI pipeline
```

Note: First run of `just check` after modifying files may fail with "files were modified by this hook" — run again.

## Development Workflow

1. Use `just dev` to start the development server (Rails + assets + Sidekiq)
2. Run tests frequently with `just test` or `just test-file`
3. Run `just check` before committing
4. Always use Rails generators for migrations
5. Follow conventional commits (see below)
6. Keep PRs focused and small

## Submitting Contributions

When you are ready to submit your changes:

1. Push your branch to your forked repository:

   ```sh
   git push origin feature/your-feature-name
   ```

2. Open a pull request (PR) from your branch to the `main` branch.

3. Provide a clear description of your changes and reference any relevant issues.

### Merge Queue

PRs are merged via [Mergify](https://mergify.com/) merge queue:

- Human PRs: enqueue via `/queue` comment (maintainer-only)
- Squash merge with conventional commit enforcement
- Bot PRs (Dependabot): autoqueued, exempt from conventional commit check
- All PRs must pass CI checks regardless of queue method
- GitHub issue priority labels: `priority:critical`, `priority:high`, `priority:medium`, `priority:low`

### Feature Removal Checklist

When removing a feature, update all of these:

- `db/seeds.rb` — remove model creation calls
- `spec/swagger_helper.rb` — remove API tags and schema definitions
- `swagger/v1/swagger.json` — regenerate with `RAILS_ENV=test rails rswag`
- Migration `down` method — add comment if simplified

## Project Documentation

Before diving into the code, review these key documents:

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — system design, deployment constraints, domain model, implementation patterns
- **[GOTCHAS.md](GOTCHAS.md)** — edge cases and hard-won lessons organized by domain. Read the relevant section before working in that area.
- **[docs/testing/testing-strategy.md](docs/testing/testing-strategy.md)** — test layers, conventions, and CI scope
- **[docs/deployment/docker-development.md](docs/deployment/docker-development.md)** — Docker setup for local development
- **[docs/development/developer-guide.md](docs/development/developer-guide.md)** — detailed development commands and environment setup

## Code of Conduct

Please note that we have a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.
