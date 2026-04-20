---
status: pending
priority: p3
issue_id: '014'
tags: [code-review, performance, optimization]
dependencies: []
---

# Eliminate Redundant MD5 in ProcessHashListJob

## Problem Statement

`ProcessHashListJob` computes `Digest::MD5.hexdigest` 3 times per hash entry across `ingest_hash_items` and `process_batch`. For a 10M-entry hash list, that's 30M MD5 calls instead of 10M.

## Findings

- **Source**: performance-oracle agent
- **Evidence**: `app/jobs/process_hash_list_job.rb:84-103, 166-196`

## Proposed Solutions

### Option A: Build digest lookup map once per batch

- Compute digest once during batch construction, reuse for lookups and upserts
- **Effort**: Small
- **Risk**: Low

## Acceptance Criteria

- [ ] MD5 computed once per hash entry per batch
- [ ] Hash list ingestion specs still pass
