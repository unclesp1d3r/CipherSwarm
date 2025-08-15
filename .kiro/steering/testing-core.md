---
inclusion: always
---

# CipherSwarm Core Testing Principles

## Testing Architecture

### Three-Tier Strategy

1. **Backend Tests** (`just test-backend`)

   - pytest + testcontainers + PostgreSQL
   - Service layer and API endpoint testing
   - Real database operations, no mocks

2. **Frontend Tests** (`just test-frontend`)

   - Vitest (unit) + Playwright (E2E with mocks)
   - SvelteKit 5 component testing
   - Fast feedback loop

3. **Full E2E Tests** (`just test-e2e`)

   - Playwright against Docker backend
   - Complete user workflows
   - Real database and API integration

## Core Testing Principles

- **Coverage**: Minimum 80% backend coverage
- **Isolation**: Each test independent, clean state
- **Real Data**: Use PostgreSQL for integration tests
- **Factories**: polyfactory for test data generation
- **Async**: All backend tests use async/await patterns

## Test Organization

### Directory Structure

**Backend**:

```
tests/
├── unit/           # Service and model tests
├── integration/    # API endpoint tests
├── factories/      # Test data factories
└── e2e/           # Full-stack E2E tests
```

**Frontend**:

```
frontend/
├── src/**/*.test.ts    # Unit tests alongside components
├── tests/             # Integration and E2E tests
└── e2e/              # Playwright E2E tests
```

### File Naming Conventions

- **Backend**: `test_{resource}_service.py`, `test_{resource}.py`
- **Frontend**: `{component}.test.ts`, `{feature}.e2e.ts`
- **Factories**: `{model_name}_factory.py`

## Test Execution Commands

```bash
# Development
just test-backend          # Backend tests only
just test-fast             # Quick backend feedback
just test-frontend         # Frontend unit + E2E with mocks

# Full validation
just test-e2e              # Full-stack E2E with Docker
just ci-check              # Complete CI pipeline
```

## Common Anti-Patterns to Avoid

> [!NOTE]
> For domain-specific anti-patterns, see the respective testing files: [testing-backend.md](testing-backend.md), [testing-frontend.md](testing-frontend.md), [testing-e2e.md](testing-e2e.md), [testing-factories.md](testing-factories.md).

### Universal Anti-Patterns

- Not testing error paths and edge cases
- Using `print()` statements instead of structured logging
- Hardcoded values that depend on external state
- Non-deterministic test data that causes flaky tests
- Testing implementation details instead of behavior
- Not properly isolating tests (shared state between tests)

## Performance and Debugging

### Performance Guidelines

- Keep unit tests fast (< 1s each)
- Use `just test-fast` for development feedback
- Avoid flaky tests with deterministic data
- Use proper async/await patterns throughout

### Debugging Strategies

**Backend**: Check testcontainers logs, verify async session handling
**Frontend**: Use DevTools Network tab, check console errors
**E2E**: Verify Docker service health, check container logs

## Test Coverage Requirements

### Backend Coverage

- Success and failure cases
- Status codes and response structure
- Pagination (`page`, `size` parameters)
- Validation errors (422), auth failures (403), not found (404)

### Frontend Coverage

- Component rendering with various props
- User interactions and event handling
- Form validation and submission
- Error states and loading states

### E2E Coverage

- Complete user workflows
- Cross-browser compatibility
- Authentication flows
- Data persistence verification

## Quality Standards

### Code Quality

- All tests must be deterministic and repeatable
- No hardcoded values that depend on external state
- Clear test names that describe the behavior being tested
- Proper setup and teardown for test isolation

### Documentation

- Complex test scenarios should include comments explaining the business logic
- Test data factories should document their purpose and constraints
- E2E tests should document the user workflow being tested

### Maintenance

- Tests should be updated when business logic changes
- Deprecated test patterns should be refactored consistently
- Test utilities should be shared and reused across test suites
