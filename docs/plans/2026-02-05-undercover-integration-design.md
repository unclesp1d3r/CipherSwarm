# Undercover Integration Design

## Goal

Integrate [undercover](https://github.com/grodowski/undercover) to identify modified code that lacks test coverage, both locally for developer feedback and in CI to gate PRs.

## Decisions

- **CI gatekeeper + local dev feedback**: both modes
- **Hard fail with escape hatch**: CI fails on untested changes; `# :nocov:` comments acknowledge intentional gaps
- **Compare against PR target branch**: `origin/main` by default, `github.base_ref` in CI

## Changes

### 1. Gem Setup

Add to `Gemfile` `:development, :test` group:

```ruby
gem "undercover", "~> 0.5", require: false
gem "simplecov-lcov", "~> 0.3", require: false
```

### 2. SimpleCov Configuration

Update `spec/spec_helper.rb` to enable branch coverage and LCOV output:

```ruby
require "simplecov"
require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = "coverage/lcov.info"
end

SimpleCov.start "rails" do
  enable_coverage(:branch)
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ])
end
```

### 3. Undercover Config

Create `.undercover` in project root:

```text
--compare origin/main
--lcov coverage/lcov.info
```

### 4. Local Workflow

Add `justfile` recipes:

```just
# Check test coverage for changed code
undercover:
    {{mise_exec}} bundle exec undercover

# Check test coverage against a specific branch
undercover-compare ref="origin/main":
    {{mise_exec}} bundle exec undercover --compare {{ref}}
```

Typical workflow: `just test` then `just undercover`.

### 5. CI Integration

Add step to `.github/workflows/CI.yml` after "Run tests":

```yaml
  - name: Check coverage of changed code
    run: bin/bundle exec undercover --compare origin/${{ github.base_ref || 
      'main' }}
```

## What Doesn't Change

- Existing HTML coverage report still generated
- Code Climate upload still works
- No changes to test suite or application code
- `just ci-check` unaffected

## Risk

Enabling branch coverage may slightly slow test runs (typically less than 5%). LCOV file adds a few hundred KB to coverage output.
