# Archived Testing Rules

This directory contains the original testing rule files that were consolidated into the new testing rules structure in `.cursor/rules/testing/`.

## Consolidation Summary

The following files were consolidated on **[Date]** to eliminate duplication and create a cleaner testing rules structure:

### Original Files (Archived)

- `test-guidelines.md` - Originally `.cursor/rules/code/test-guidelines.mdc`
- `testing-patterns.md` - Originally `.cursor/rules/code/testing-patterns.mdc`
- `ssr-migration-patterns.md` - Originally `.cursor/rules/frontend/ssr-migration-patterns.mdc`
- `timeout-patterns.md` - Originally `.cursor/rules/testing/timeout-patterns.mdc`
- `testing-patterns-old.md` - Originally `.cursor/rules/testing/testing-patterns.mdc`
- `e2e-docker-infrastructure.md` - Originally `.cursor/rules/testing/e2e-docker-infrastructure.mdc`

### New Consolidated Structure

The content from these files has been reorganized into four focused rule files:

1. **`.cursor/rules/testing/backend-testing.mdc`**

   - Backend testing patterns and infrastructure
   - Pytest, testcontainers, factories, service testing
   - API endpoint testing across all interfaces

2. **`.cursor/rules/testing/frontend-testing.mdc`**

   - Frontend testing patterns and best practices
   - SvelteKit 5 testing with runes and SSR
   - Component testing and Vitest configuration

3. **`.cursor/rules/testing/e2e-testing.mdc`**

   - End-to-end testing infrastructure and patterns
   - Docker setup, Playwright configuration, timeout handling
   - Three-tier testing architecture

4. **`.cursor/rules/testing/test-organization.mdc`**

   - Cross-cutting test organization standards
   - Directory structure, naming conventions, coverage requirements
   - CI integration and test command patterns

## Benefits of Consolidation

- **Eliminated Duplication**: Removed redundant content across multiple files
- **Improved Organization**: Grouped related concepts together logically
- **Better Discoverability**: Clearer file names and focused content
- **Easier Maintenance**: Single source of truth for each testing area
- **Comprehensive Coverage**: Ensured all essential patterns were preserved

## Archive Purpose

These files are preserved for historical reference and to ensure no valuable lessons learned or patterns were lost during the consolidation process. They should not be used for active development guidance - refer to the new consolidated files instead.
