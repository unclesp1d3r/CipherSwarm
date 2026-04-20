---
status: pending
priority: p2
issue_id: '003'
tags: [code-review, architecture, security, rails]
dependencies: []
---

# Consolidate Dual Admin Interface

## Problem Statement

The application has both Administrate-generated CRUD at `/admin/*` (with its own auth mechanism) and a custom `AdminController` handling `unlock_user`, `lock_user`, `create_user`, `new_user`. These use different authorization patterns — Administrate checks in its own `ApplicationController` override, while the custom admin controller uses CanCanCan's `:admin_dashboard` ability. This dual path increases the risk of one interface being more permissive than the other.

## Findings

- **Source**: architecture-strategist agent, security surface analysis
- **Evidence**: `app/controllers/admin_controller.rb` + `app/controllers/admin/` namespace (Administrate)
- **Impact**: Inconsistent access control, contributor confusion, increased auth surface area

## Proposed Solutions

### Option A: Extend Administrate with custom actions (Recommended)

- Move `unlock_user`, `lock_user`, `create_user` into Administrate's Users dashboard as custom actions
- Remove the standalone `AdminController`
- **Pros**: Single auth pattern, consistent UI, less code
- **Cons**: Administrate action customization can be awkward
- **Effort**: Medium
- **Risk**: Low

### Option B: Replace Administrate entirely

- Build a purpose-built admin namespace with CanCanCan authorization
- **Pros**: Full control, consistent auth
- **Cons**: Large effort, loses Administrate's auto-generated CRUD
- **Effort**: Large
- **Risk**: Medium — regression risk on existing admin features

### Option C: Unify authorization only

- Keep both controllers but ensure both use identical CanCanCan checks
- **Pros**: Minimal change
- **Cons**: Dual interface still confusing
- **Effort**: Small
- **Risk**: Low

## Recommended Action

_To be filled during triage_

## Technical Details

- **Affected files**: `app/controllers/admin_controller.rb`, `app/controllers/admin/*.rb`, `config/routes.rb`
- **Auth patterns**: Administrate's `ApplicationController` override vs CanCanCan `authorize!`

## Acceptance Criteria

- [ ] Single admin authorization pattern
- [ ] All admin actions use consistent access control
- [ ] No orphaned routes or controllers
- [ ] `just ci-check` passes

## Work Log

| Date       | Action                           | Learnings                              |
| ---------- | -------------------------------- | -------------------------------------- |
| 2026-04-01 | Created from architecture review | Found during security surface analysis |

## Resources

- PR #830 architecture review
- `app/controllers/admin_controller.rb`
- `app/controllers/admin/` (Administrate namespace)
