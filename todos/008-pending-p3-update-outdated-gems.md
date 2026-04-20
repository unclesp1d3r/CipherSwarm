---
status: pending
priority: p3
issue_id: '008'
tags: [code-review, dependencies, maintenance]
dependencies: []
---

# Update Outdated Gems

## Problem Statement

5 directly-depended gems have newer versions available. None have security advisories (`bundle audit` is clean), but staying current reduces future upgrade pain.

## Findings

- **Source**: `bundle outdated --only-explicit`

| Gem            | Current | Latest  | Pinned To  |
| -------------- | ------- | ------- | ---------- |
| rails          | 8.1.2.1 | 8.1.3   | ~> 8.1.2   |
| rubocop        | 1.85.1  | 1.86.0  | ~> 1.85.1  |
| view_component | 4.5.0   | 4.6.0   | ~> 4.5.0   |
| aws-sdk-s3     | 1.216.0 | 1.218.0 | ~> 1.216.0 |
| factory_trace  | 2.0.0   | 3.0.1   | ~> 2.0.0   |

## Proposed Solutions

### Option A: Batch update via Dependabot PRs (Recommended)

- Dependabot is already configured — these will come as automated PRs
- Review and merge each individually
- **Effort**: Trivial
- **Risk**: None — Dependabot PRs run CI

### Option B: Manual batch update

- `bundle update rails rubocop view_component aws-sdk-s3`
- `factory_trace` 3.0.1 is a major version bump — review changelog first
- **Effort**: Small
- **Risk**: Low for patch/minor, medium for factory_trace major

## Technical Details

- **Note**: `aws-sdk-s3` is only needed while Active Storage S3 backend exists. Removal tracked in #005.
- **Note**: `factory_trace` 3.x may have breaking changes — check changelog before updating pin.
