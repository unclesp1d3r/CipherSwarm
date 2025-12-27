# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### 🎯 Features

- Implement comprehensive UI/UX testing with Capybara
  - Add system tests for authentication, agent management, campaigns, hash lists, navigation, and admin functionality
  - Implement Page Object Pattern for maintainable test architecture
  - Add 13 new system test files with extensive coverage

### 🐛 Bug Fixes

- Fix `HashType#to_s` to use instance attributes instead of class method
- Fix database pool size calculation to properly multiply integers instead of strings
  - **IMPORTANT**: This changes the database pool size calculation. Verify production `DB_POOL_MULTIPLIER` environment variable.
  - Old behavior: String multiplication (e.g., "5" * "2" = "52")
  - New behavior: Integer multiplication (e.g., 5 * 2 = 10)
- Configure Devise paranoid mode to prevent user enumeration attacks
- Update Devise navigational formats to support Turbo Stream requests

### ✨ Enhancements

- Allow users to create and destroy their own agents (non-admins)
- Standardize submit buttons across forms to display "Submit" for improved clarity
- Update CI/CD workflow with improved Chrome installation and better artifact handling
- Add webdrivers gem for automatic browser driver management (note: gem is deprecated, consider migration)

### 🧪 Testing

- Add Turbo/Hotwire wait helpers to prevent flaky tests
- Add comprehensive ability specs for agent permissions
- Configure Capybara with headless Chrome for system tests
- Add screenshot capture on test failures

### 📚 Documentation

- Add comprehensive system tests guide (docs/testing/system-tests-guide.md)
- Add test failures investigation documentation
- Update README with system test section and CI integration details

### ⚙️ Miscellaneous Tasks

- Restore pessimistic version constraints in Gemfile for stability
- Update PostgreSQL version to 17.0 and Redis to 7.2 in CI
- Update GitHub Actions checkout action to v5
- Add Vale configuration for documentation linting

## [0.6.7] - 2025-08-09

### 🐛 Bug Fixes

- Address critical bugs and performance issues in main branch

🚨 Critical Security & Race Condition Fixes:
- Fix race condition in submit_crack method by wrapping entire operation in transaction
- Add strong parameter filtering to submit_status method to prevent mass assignment vulnerabilities
- Ensure data consistency during concurrent hash submissions

⚡ Performance Optimizations:
- Optimize ProcessHashListJob with batch processing to prevent memory leaks on large files
- Improve uncracked_list method to eliminate unnecessary array operations
- Add critical database indexes for hash_items, agents, and tasks tables

🧹 Code Quality Improvements:
- Remove code duplication in JBuilder template for attack resources
- Add proper error handling and logging in batch processing
- Implement efficient bulk insert operations using insert_all/upsert_all

📊 Database Migration:
- Add composite indexes for frequent hash lookups (hash_value + hash_list_id)
- Add indexes for cracked hash queries and agent/task filtering
- Improve query performance for API endpoints

These changes maintain backward compatibility while significantly improving
system stability, security, and performance for production workloads.

- Improve upsert

- Enhance database configuration and entrypoint script

- Update database.yml to allow fallback to TEST_DATABASE_URL for test environment.
- Refactor docker-entrypoint script to improve argument handling for Rails server execution, ensuring proper database preparation before starting the server.

- Resolve Docker build failure with bootsnap precompile

- Move bootsnap precompile --gemfile command after application code is copied
- Fix BUNDLE_PATH environment variable issues by ensuring proper sequence
- Add separate bootsnap precompile steps for better error isolation
- This resolves exit code 7 errors during Docker build process

The issue was that bootsnap precompile --gemfile was running before the
application code (including Gemfile) was available in the container context.


### 🎨 Styling

- Fix RuboCop violations and improve code quality

- Auto-fix 30 style violations (symbol arrays, string literals, trailing whitespace, etc.)
- Add rake task description to routes.rake
- Improve thread safety in ApplicationConfig singleton pattern
- Add justification comments for intentional validation skipping in ProcessHashListJob
- Remove redundant RSpec type declarations in specs
- All RuboCop checks now pass (351 files inspected, no offenses detected)
- Security analysis with Brakeman still passes (no warnings found)


### ⚙️ Miscellaneous Tasks

- Update Gemfile.lock and add new documentation rules

Bumped several gem versions in Gemfile.lock for improved stability and security, including active_storage_validations, aws-sdk-core, and rubocop. Additionally, added new documentation rules for core coding principles, memory management, Rails development guidelines, and implementation reasoning to enhance project standards and maintainability.

- Update Gemfile.lock and yarn.lock for dependency upgrades

Bumped aws-sdk-s3 to version 1.185.0 and updated several packages in yarn.lock, including @hotwired/turbo-rails to 8.0.13, autoprefixer to 10.4.21, and others for improved performance and security. Removed unused fields from HashListDashboard and updated documentation in various models for clarity and consistency.

- Update Rails documentation and tech stack requirements

Added instructions to use rbenv for Ruby 3.3.6 and included Docker for deployment in the tech stack requirements. Updated links to relevant Docker configuration files for better clarity and accessibility.

- Enhance Rails development guidelines

Added instructions for using rbenv to set up the Ruby environment and emphasized the importance of utilizing built-in Rails tools, specifically discouraging manual migration creation. These updates aim to improve development practices and maintain consistency across the project.

- Apply comprehensive code formatting and linting updates

- Update configuration files for code quality tools (.annotaterb.yml, .erb_lint.yml)
- Standardize indentation and formatting across all Ruby, ERB, and YAML files
- Apply SPDX license headers to ensure MPL-2.0 compliance
- Update development container and workflow configurations
- Improve code consistency and maintainability

This is a maintenance release focusing on code quality improvements.

- Update Ruby version in CircleCI configuration

Bumped Ruby version from 3.3.5 to 3.3.6 in the CircleCI configuration to ensure compatibility with the latest features and improvements. This change supports ongoing development and testing efforts.

- Update RuboCop configuration for improved linting

Modified .rubocop.yml to enhance plugin usage and formatting consistency. Changed 'require' to 'plugins' for clarity, updated exclusion patterns to use double quotes, and ensured proper alignment with Ruby style guidelines. These adjustments aim to streamline linting processes and maintain code quality.

- Enhance documentation standards across multiple files

Added new sections and improved formatting in core coding principles, memory management, Rails development guidelines, and implementation reasoning documentation. These updates aim to clarify expectations for code quality, testing standards, and documentation practices, ensuring consistency and maintainability throughout the project.

- Update Ruby version from 3.3.6 to 3.4.5 across codebase

- Update .ruby-version to 3.4.5
- Update Gemfile Ruby version specification
- Update Dockerfile and .devcontainer/Dockerfile Ruby versions
- Update CircleCI configuration to use Ruby 3.4.5 image
- Update documentation in .cursor/rules/rails.mdc
- Regenerate Gemfile.lock with new Ruby version
- Install missing system dependencies (PostgreSQL and YAML libraries)
- Verify all gems are compatible with Ruby 3.4.5

- Update Docker configuration and dependencies

- Refactor Dockerfile to use Alpine base image for reduced size and improved performance.
- Update .dockerignore to exclude additional sensitive files and directories.
- Modify Gemfile to upgrade view_component to version 4.0 and adjust related configurations.
- Enhance database.yml to support DATABASE_URL environment variable for test environment.
- Update initializers and application configuration for view_component compatibility.
- Adjust entrypoint script for better memory management and compatibility with jemalloc.
- Improve process_hash_list_job to handle hash items more efficiently.
- Update yarn.lock to reflect changes in package resolutions and versions.

- Update Gemfile.lock and add package-lock.json

- Remove outdated view_component-contrib dependency from Gemfile.lock.
- Upgrade view_component to version 4.0 in Gemfile.lock.
- Introduce package-lock.json to manage Node.js dependencies for the project.
- Add test_results.json to store the results of component tests, ensuring better tracking of test outcomes.


<!-- generated by git-cliff -->
