# Contributing to CipherSwarm

Thank you for your interest in contributing to CipherSwarm! We appreciate your efforts and value your time. This guide will help you understand how to contribute effectively to the project.

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [Contributing to CipherSwarm](#contributing-to-cipherswarm)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
  - [Gitflow Workflow](#gitflow-workflow)
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

## Gitflow Workflow

We use the Gitflow workflow to manage our development process. Here’s a brief overview:

- **Main Branches:**

  - `main`: This is the production branch. All releases are made from this branch.
  - `develop`: This is the main development branch where the latest development changes are merged.

- **Supporting Branches:**

  - `feature/*`: Feature branches are used to develop new features. They branch off from `develop` and are merged back into `develop` when complete.
  - `release/*`: Release branches support the preparation of a new production release. They branch off from `develop` and are merged into both `develop` and `main`.
  - `hotfix/*`: Hotfix branches are used to patch production releases quickly. They branch off from `main` and are merged back into both `develop` and `main`.

### Using Gitflow Tools

To simplify the Gitflow workflow, you can use the `git-flow` tools. First, ensure you have `git-flow` installed:

- **macOS**: Install via Homebrew

  ```sh
  brew install git-flow
  ```

- **Windows**: Install via [chocolatey](https://chocolatey.org/)

  ```sh
  choco install gitflow-avh
  ```

- **Linux**: Install via your package manager

  ```sh
  sudo apt-get install git-flow
  ```

#### Creating and Merging Branches with Gitflow Tools

- **Feature Branches**:

  - Start a new feature:

    ```sh
    git flow feature start your-feature-name
    ```

  - Finish the feature (this will merge it into `develop` and delete the feature branch):

    ```sh
    git flow feature finish your-feature-name
    ```

- **Release Branches**:

  - Start a new release:

    ```sh
    git flow release start your-release-name
    ```

  - Finish the release (this will merge it into both `main` and `develop`, tag the release, and delete the release branch):

    ```sh
    git flow release finish your-release-name
    ```

- **Hotfix Branches**:

  - Start a new hotfix:

    ```sh
    git flow hotfix start your-hotfix-name
    ```

  - Finish the hotfix (this will merge it into both `main` and `develop`, tag the hotfix, and delete the hotfix branch):

    ```sh
    git flow hotfix finish your-hotfix-name
    ```

#### Manually Creating and Merging Branches

If you prefer to manage branches manually, you can follow these steps:

- **Feature Branches** (`feature/*`):

  - **Rebase**: Before merging a feature branch into `develop`, rebase it to ensure a clean, linear commit history.

    ```sh
    git checkout feature/your-feature-name
    git rebase develop
    ```

  - **Merge**: Once rebased, merge the feature branch into `develop` using a regular merge to capture all commits.

    ```sh
    git checkout develop
    git merge feature/your-feature-name
    ```

- **Release Branches** (`release/*`):

  - **Merge**: Use a regular merge to integrate changes from the release branch into both `develop` and `main`.

    ```sh
    git checkout main
    git merge release/your-release-name
    git checkout develop
    git merge release/your-release-name
    ```

- **Hotfix Branches** (`hotfix/*`):

  - **Merge**: Use a regular merge to quickly apply the hotfix to both `main` and `develop`.

    ```sh
    git checkout main
    git merge hotfix/your-hotfix-name
    git checkout develop
    git merge hotfix/your-hotfix-name
    ```

Following these merge strategies ensures that all commits are correctly captured and our commit history remains straightforward.

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
