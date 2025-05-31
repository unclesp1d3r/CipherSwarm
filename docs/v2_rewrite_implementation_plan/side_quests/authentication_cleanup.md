<!--
Context: This checklist was generated from a full audit of all @web endpoints in app/api/v1/endpoints/web/*. Endpoints listed here are missing authentication/authorization or have TODOs in code. When returning to this task:
- Re-audit for any new endpoints and check for consistent use of Depends(get_current_user) and permission checks.
- Reference the architecture/core-concepts and code/error-handling rules for required auth patterns.
- Mark off each item as you implement or verify auth.
- If unsure about an endpoint, check for project/user context and sensitive data exposure.
- This list is not exhaustive if new endpoints have been added since this audit.
- Last audit: 2024-06-21.
-->

# Authentication Cleanup Task List for Web API Endpoints

This checklist tracks endpoints in `app/api/v1/endpoints/web/` that require authentication/authorization review or fixes.

This should be mostly completed, but just needs to be verified and tests need to be updated or added to ensure that the authentication/authorization is working as expected.

---

## Attacks (`attacks.py`)

-   [ ] `/api/v1/web/attacks/{attack_id}/duplicate` — **TODO: Add authentication/authorization**
-   [ ] `/api/v1/web/attacks/bulk` (DELETE) — **TODO: Add authentication/authorization**
-   [ ] `/api/v1/web/attacks/{attack_id}/export` — **TODO: Add authentication/authorization**
-   [ ] `/api/v1/web/attacks/{attack_id}` (PATCH) — **TODO: Add authentication/authorization**
-   [ ] `/api/v1/web/attacks` (POST) — **TODO: Add authentication/authorization**

## Campaigns (`campaigns.py`)

-   [ ] `/api/v1/web/campaigns/{campaign_id}/export` — **TODO: Add authentication/authorization**

## Live Feeds (`live.py`)

-   [ ] All WebSocket endpoints (`/api/v1/web/live/*`) — **TODO: Implement real JWT/session check**

## General

-   [ ] Review all endpoints for consistent use of `Depends(get_current_user)` and project/user permission checks.
-   [ ] Ensure all endpoints that mutate or expose sensitive data are protected.

---

**How to use:**

-   Check off each item as authentication/authorization is implemented or verified.
-   Add new endpoints as needed during development.
-   Reference this file in PRs related to authentication fixes.
