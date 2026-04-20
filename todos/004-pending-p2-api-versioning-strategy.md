---
status: pending
priority: p2
issue_id: '004'
tags: [code-review, architecture, api, documentation]
dependencies: []
---

# Document API Versioning Strategy for Air-Gapped Fleet

## Problem Statement

The API is at `/api/v1/` but there is no documented strategy for how breaking changes will be handled when agents in the field cannot be updated simultaneously. In air-gapped environments, agents may run different versions for weeks or months. Recent breaking changes (e.g., `submit_benchmark` returning a receipt, `TaskStatus` renamed to `HashcatStatusUpdate`) could strand agents running older client versions.

## Findings

- **Source**: architecture-strategist agent, API design analysis
- **Evidence**: Commit `55a1297` (`feat(api)!:`) and this PR's schema rename are breaking changes with `!` markers
- **Impact**: Agents in air-gapped environments may fail after server-only upgrades

## Proposed Solutions

### Option A: Additive-only v1 policy + v2 namespace for breaks (Recommended)

- Document that v1 only accepts additive changes (new fields, new endpoints)
- Breaking changes require a new `/api/v2/` namespace
- Agents negotiate via `Accept: application/vnd.cipherswarm.v2+json` header
- Maintain v1 for at least one release cycle
- **Pros**: Clear contract, backward compatible, industry standard
- **Cons**: Maintaining two API versions is work
- **Effort**: Medium (policy is small, dual-version support is ongoing)
- **Risk**: Low

### Option B: Feature flags in API responses

- Server returns capability flags; agents adapt behavior based on flags
- **Pros**: Flexible, no version namespace needed
- **Cons**: Complex client logic, hard to test all combinations
- **Effort**: Medium
- **Risk**: Medium — combinatorial complexity

### Option C: Document and accept breakage

- Document that server and agents must be updated together
- Provide upgrade scripts and version compatibility matrix
- **Pros**: Simple, honest
- **Cons**: Doesn't solve the air-gap staggered upgrade problem
- **Effort**: Small
- **Risk**: Operational risk remains

## Recommended Action

_To be filled during triage_

## Technical Details

- **Affected files**: `config/routes/client_api.rb`, API controllers, CipherSwarmAgent Go client
- **Current version**: v1 (only version)
- **Known breaks**: `submit_benchmark` receipt return, `HashcatStatusUpdate` schema rename

## Acceptance Criteria

- [ ] API compatibility policy documented in CONTRIBUTING.md or dedicated doc
- [ ] Breaking changes require explicit review and version bump
- [ ] Agent client handles version negotiation gracefully
- [ ] Upgrade guide covers staggered fleet updates

## Work Log

| Date       | Action                           | Learnings                        |
| ---------- | -------------------------------- | -------------------------------- |
| 2026-04-01 | Created from architecture review | Found during API design analysis |

## Resources

- PR #830 architecture review
- `config/routes/client_api.rb`
- CipherSwarmAgent Go client repository
