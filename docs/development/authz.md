# CipherSwarm Authorization (RBAC) — Developer Guide

## What is Casbin?

[Casbin](https://casbin.org/) is a powerful, flexible access control library supporting role-based access control (RBAC), attribute-based access control (ABAC), and more. CipherSwarm uses Casbin for all user/project/role authorization logic.

## Where Do Policies Live?

- **Model file:** `config/model.conf`
- **Policy file:** `config/policy.csv`
- **Casbin wrapper:** `app/core/authz.py`
- **Permission helpers:** `app/core/permissions.py`

## How to Add a New Role, Object, or Action

1. **Add a new role:**
    - Add a new `g,` (role inheritance) or `p,` (policy) line to `policy.csv`.
2. **Add a new object:**
    - Use the format `project:{project_id}`, `campaign:{campaign_id}`, etc.
    - Add new `p,` lines for the object and allowed actions.
3. **Add a new action:**
    - Add a new `p,` line for the action (e.g., `p, project_admin, project:*, archive`).

## Usage Pattern

- **Never check user roles inline.**
- Always use the helpers in `permissions.py`:
  - `can_access_project(user, project, action)`
  - `can(user, resource, action)`

This ensures all RBAC logic is consistent, testable, and centrally managed.

---

For more details, see the Casbin docs or ask the core team.
