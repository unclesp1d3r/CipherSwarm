# Contributing to CipherSwarm

Thank you for your interest in contributing to CipherSwarm! We appreciate your efforts and value your time. This guide will help you understand how to contribute effectively to the project.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Gitflow Workflow](#gitflow-workflow)
3. [Conventional Commits](#conventional-commits)
4. [Running Tests](#running-tests)
5. [Submitting Contributions](#submitting-contributions)

## Getting Started

To get started with contributing to CipherSwarm, you'll need to:

1. Fork the repository from [CipherSwarm](https://github.com/unclesp1d3r/CipherSwarm).
2. Clone your fork to your local machine:
    ```sh
    git clone https://github.com/your-username/CipherSwarm.git
    ```
3. Set up the project dependencies:
    ```sh
    bundle install
    ```

## Gitflow Workflow

We use the Gitflow workflow to manage our development process. Here’s a brief overview:

- **Main Branches:**
  - `main`: This is the production branch. All releases are made from this branch.
  - `develop`: This is the main development branch where the latest development changes are merged.

- **Supporting Branches:**
  - `feature/*`: Feature branches are used to develop new features. They branch off from `develop` and are merged back into `develop` when complete.
  - `release/*`: Release branches support preparation of a new production release. They branch off from `develop` and are merged into both `develop` and `main`.
  - `hotfix/*`: Hotfix branches are used to quickly patch production releases. They branch off from `main` and are merged back into both `develop` and `main`.

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

By following these merge strategies, we ensure that all commits are properly captured and that our commit history remains clear and easy to follow.

## Conventional Commits

We use the Conventional Commits specification to streamline our commit messages. This ensures clarity in commit history and helps with automated versioning.

Here are the title maps we use for conventional commits along with their meanings:

- `feat`: **Features** - A new feature for the user.
- `fix`: **Bug Fixes** - A bug fix for the user.
- `perf`: **Performance Improvements** - Changes that improve performance.
- `refactor`: **Code Refactoring** - A code change that neither fixes a bug nor adds a feature.
- `ci`: **CI Changes** - Changes to our CI configuration files and scripts.
- `docs`: **Documentation** - Documentation only changes.
- `style`: **Style Changes** - Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc.).
- `test`: **Test Changes** - Adding missing tests or correcting existing tests.
- `chore`: **Chores** - Other changes that don't modify src or test files.
- `Bump`: **Dependency Bumps** - Updating dependencies.
- `Merge`: **Merge Commits** - Merging branches.
- `Added`: **Added Features** - Adding new features.

## Running Tests

All contributions must pass the rspec tests before they can be merged. You can run the tests using the `rake` command:

1. Run the tests:
    ```sh
    rake
    ```

Make sure all tests pass before submitting your contribution.

## Submitting Contributions

When you are ready to submit your changes, follow these steps:

1. Push your branch to your forked repository:
    ```sh
    git push origin feature/your-feature-name
    ```
2. Open a pull request (PR) from your branch to the `develop` branch of the main repository.

Please provide a clear and detailed description of your changes in the PR. Reference any relevant issues or discussions.

## Code of Conduct

Please note that we have a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

Thank you for contributing to CipherSwarm! We look forward to your pull requests.
