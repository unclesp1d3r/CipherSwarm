---
status: pending
priority: p2
issue_id: '005'
tags: [code-review, architecture, cleanup, technical-debt]
dependencies: []
---

# Complete Active Storage to tusd Migration

## Problem Statement

Active Storage is being phased out in favor of tusd + disk storage for attack resources, but dual code paths remain. `ProcessHashListJob` has a fallback path to `blob.open` when `temp_file_path` is missing. Active Storage tables, attachments, and service configuration still exist. This dual-path complexity adds maintenance burden and confusion about which upload path is canonical.

## Findings

- **Source**: architecture-strategist agent, technical debt inventory
- **Evidence**: `ProcessHashListJob` fallback path, Active Storage tables in schema, `aws-sdk-s3` gem still in Gemfile
- **Impact**: Maintenance burden, contributor confusion, unnecessary dependencies

## Proposed Solutions

### Option A: Remove Active Storage fallback paths (Recommended first step)

- Remove the `blob.open` fallback in `ProcessHashListJob`
- Require `temp_file_path` for all new uploads
- Keep Active Storage for legacy data access only
- **Pros**: Simplifies job logic, clear canonical path
- **Cons**: May break if any upload still uses Active Storage
- **Effort**: Small
- **Risk**: Medium — need to verify no uploads still use AS

### Option B: Full Active Storage removal

- Remove all AS tables, gems, config, and code paths
- Migrate any remaining AS blobs to disk storage
- **Pros**: Clean codebase, no dual paths
- **Cons**: Large effort, needs data migration
- **Effort**: Large
- **Risk**: Medium — data loss risk if migration incomplete

### Option C: Document and defer

- Mark Active Storage as deprecated in ARCHITECTURE.md
- Add deprecation warnings to AS code paths
- **Pros**: Low risk, communicates intent
- **Cons**: Debt persists
- **Effort**: Small
- **Risk**: None

## Recommended Action

_To be filled during triage_

## Technical Details

- **Affected files**: `app/jobs/process_hash_list_job.rb`, `Gemfile` (aws-sdk-s3), `config/storage.yml`, `db/schema.rb` (active_storage\_\* tables)
- **Related issue**: #577 (Replace MinIO with configurable storage)
- **Migration rake task**: `rails storage:migrate_from_active_storage`

## Acceptance Criteria

- [ ] Single canonical upload path (tusd + disk)
- [ ] No fallback to `blob.open` in job processing
- [ ] Active Storage tables removed or marked for removal
- [ ] `just ci-check` passes

## Work Log

| Date       | Action                           | Learnings                             |
| ---------- | -------------------------------- | ------------------------------------- |
| 2026-04-01 | Created from architecture review | Found during technical debt inventory |

## Resources

- PR #830 architecture review
- Issue #577 (storage replacement)
- `docs/solutions/infrastructure-issues/sidekiq-docker-tmp-exhaustion-and-large-upload-pipeline.md`
- Memory: project_tus_upload_747.md
