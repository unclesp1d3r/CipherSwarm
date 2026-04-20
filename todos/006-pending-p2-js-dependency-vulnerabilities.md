---
status: pending
priority: p2
issue_id: '006'
tags: [code-review, security, dependencies, javascript]
dependencies: []
---

# Fix JavaScript Dependency Vulnerabilities

## Problem Statement

`bun audit` reports 4 vulnerabilities in JS dependencies, all in dev/build tooling (not shipped to production). While these don't affect runtime, they indicate stale transitive dependencies that should be updated.

## Findings

- **Source**: `bun audit` scan
- **High (2)**: `minimatch >=10.0.0 <10.2.3` (via nodemon) — ReDoS in matchOne() and nested extglobs
- **Moderate (2)**:
  - `yaml >=2.0.0 <2.8.3` (via postcss-cli -> postcss-load-config) — Stack Overflow via deeply nested YAML
  - `brace-expansion >=4.0.0 <5.0.5` (via nodemon -> minimatch) — Zero-step sequence hang
  - `picomatch <2.3.2` (via postcss-cli, sass, nodemon) — Method Injection in POSIX character classes

## Proposed Solutions

### Option A: Update nodemon and postcss-cli (Recommended)

- `bun update nodemon postcss-cli sass` to pull in patched transitive deps
- **Pros**: Fixes all 4 vulns, minimal effort
- **Cons**: May require testing CSS build pipeline
- **Effort**: Small
- **Risk**: Low — build tools only, not runtime

### Option B: Replace nodemon with chokidar-cli

- nodemon is the source of 3/4 vulns; replace with lighter watcher
- **Pros**: Removes root cause
- **Cons**: Changes dev workflow
- **Effort**: Small
- **Risk**: Low

## Technical Details

- **Affected files**: `package.json`, `bun.lockb`
- **Runtime impact**: None — all vulns are in build/dev tooling

## Acceptance Criteria

- [ ] `bun audit` reports 0 high/moderate vulnerabilities
- [ ] CSS build pipeline still works (`bun run build:css`)
- [ ] JS build still works (`bun run build`)
