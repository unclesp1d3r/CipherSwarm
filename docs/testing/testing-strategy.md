# Testing Strategy

CipherSwarm uses RSpec with FactoryBot across multiple test layers. Coverage is enforced by SimpleCov (minimum threshold) and undercover (change-based coverage against `origin/main`).

## Test Layers

### System Tests (`spec/system/`)

End-to-end browser tests using Capybara + Selenium WebDriver with Chrome.

- **Page Object Pattern** — page objects in `spec/support/page_objects/`
- Screenshots on failure saved to `tmp/capybara/`
- Key workflows: authentication, agent management, campaigns, file uploads, authorization
- Tests requiring tusd use testcontainers — `TusdHelper.ensure_tusd_running` in `before(:all)`
- See `docs/testing/system-tests-guide.md` for detailed patterns

### Model Tests (`spec/models/`)

- FactoryBot factories in `spec/factories/`
- Comprehensive validation and association testing
- State machine transition testing (see [GOTCHAS.md § State Machines](../GOTCHAS.md#state-machines) for edge cases)

### Request Tests (`spec/requests/`)

- API endpoint testing with authentication and authorization
- Generates Swagger documentation via RSwag
- Run `just docs-api` to regenerate OpenAPI spec from these tests

### View Tests (`spec/views/`) — planned

- Partial rendering tests (e.g., agent configuration tab)
- Use `render partial:` with locals, assert on `rendered`
- Stub `safe_can?` when the partial uses authorization checks

### JavaScript Tests

Vitest for JS unit tests:

```bash
just test-js    # or: npx vitest run
```

- Config: `vitest.config.js` with `environment: 'jsdom'`
- Setup: `spec/javascript/setup.js` initializes Stimulus Application
- Pagy JS is distributed via the gem's `javascripts/` directory, resolved via `NODE_PATH`
- Run `bin/rails stimulus:manifest:update` after adding/removing Stimulus controllers

## Non-Standard Spec Directories

| Directory           | Purpose                                      | Notes                                             |
| ------------------- | -------------------------------------------- | ------------------------------------------------- |
| `spec/performance/` | Page load benchmarks, query count efficiency | Uses `# rubocop:disable RSpec/DescribeClass`      |
| `spec/deployment/`  | Air-gapped deployment validation             | CDN-free assets, Docker config, offline readiness |
| `spec/coverage/`    | Coverage verification                        | Validates spec file existence across layers       |

## Conventions

- Maximum **20 lines** per RSpec example
- Maximum **5 expectations** per example
- Use **FactoryBot factories**, not fixtures
- Test both happy paths and edge cases
- Concerns tested via the host model (see `spec/models/concerns/`)

## Running Tests

```bash
just test                    # All tests with coverage (excludes system)
just test-system             # System tests (requires Docker for tusd)
just test-file spec/path.rb  # Single file
just test-api                # Request specs only
just test-js                 # JavaScript tests
just ci-check                # Full CI pipeline: pre-commit → brakeman → rspec → undercover → rswag
```

## Undercover (Change-Based Coverage)

Undercover checks that changed lines have test coverage relative to `origin/main`.

```bash
just undercover
```

- Requires `COVERAGE=true` RSpec run first (generates `coverage/lcov.info`)
- CI needs `fetch-depth: 0` in checkout
- To fix failures: add tests covering the flagged lines, then re-run `just ci-check`
- `retry_on`/`discard_on` block bodies are unreachable via `perform_now` — extract handler to a lambda constant and pass via `&CONSTANT`. See `ApplicationJob::TEMP_STORAGE_DISCARD_HANDLER`.

## CI Scope

- GitHub CI **excludes** `spec/system/` — system tests run locally via `just test-system`
- `continue-on-error: true` on undercover step for transitional periods
- JUnit XML: `rspec_junit_formatter` outputs `<testsuite>`; Mergify CI Insights requires `<testsuites>` — a CI step wraps it

> See [GOTCHAS.md § Testing](../GOTCHAS.md#testing) for test-specific gotchas (deadlocks, Turbo Streams, cache keys, state machine stubs, etc.)
