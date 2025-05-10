# v2 Agent API Removal & v1 Decoupling Checklist

This checklist provides a step-by-step plan to fully decouple and remove the v2 Agent API implementation from CipherSwarm, while ensuring the v1 Agent API remains fully functional and strictly compliant with the legacy OpenAPI specification (`swagger.json`).

---

## Context

-   The v1 Agent API (endpoints under `/api/v1/client/*`) is a strict compatibility layer for legacy agents and must match `swagger.json` exactly.
-   The current v1 compatibility endpoints are thin wrappers around v2 endpoint logic and service functions.
-   The v2 Agent API is not in use and is inconsistent with project direction.
-   The goal is to:
    -   Decouple v1 from v2 by duplicating or refactoring shared service logic. The priority should be given to to preserving the v1 API and functionality.
    -   Remove all v2 endpoints and v2-only service code.
    -   Ensure v1 remains fully functional and compliant.

---

## Checklist

### 1. Decouple v1 Compatibility Endpoints from v2 Logic

-   [ ] For each v1 compatibility endpoint in `app/api/v1/endpoints/client_compat.py`:
    -   [ ] Replace all direct calls to v2 endpoint functions (e.g., `v2_register_agent`, `v2_agent_heartbeat`, etc.) with direct calls to service-layer functions.
    -   [ ] If the service logic is not unique to v2 (i.e., it is version-agnostic), rename the function to remove the `_v2` suffix and update all references accordingly.
    -   [ ] If the service logic is v2-specific, duplicate and adapt it for v1, ensuring:
        -   [ ] All request/response schemas match `swagger.json`.
        -   [ ] All business logic, error handling, and side effects are preserved.
    -   [ ] For endpoints with no suitable service function, implement new service logic as needed, matching v1 requirements.
-   [ ] Move all v1 Agent API endpoints to resource- and interface-specific subfolders under `app/api/v1/endpoints/` as described in the rules (e.g., `agent/`, `tasks/`, `attacks/`, `crackers/`).
-   [ ] Remove all imports of `app.api.v2.endpoints.client` from v1 code.
-   [ ] Update or add tests to cover the decoupled v1 endpoints.
-   [ ] Run all v1 endpoint tests and verify:
    -   [ ] All endpoints function as expected.
    -   [ ] All responses match `swagger.json` (fields, types, status codes).

### 2. Remove v2 Agent API Endpoints

-   [ ] Delete `app/api/v2/router.py` and `app/api/v2/endpoints/client.py`.
-   [ ] Remove v2 API router registration from `app/main.py`.
-   [ ] Remove v2-specific endpoint tests (e.g., `tests/integration/v2/agent/`, etc.).
-   [ ] Ensure all shared service logic required by v1 remains intact.
-   [ ] Run all v1 endpoint tests and verify full functionality and compliance.

### 3. Remove v2-Only Service Functions

-   [ ] Identify all service functions in `app/core/services/client_service.py` and related modules that are used exclusively by v2 endpoints.
-   [ ] Remove these v2-only service functions and any associated helpers.
-   [ ] Remove v2-specific service tests.
-   [ ] Run all v1 endpoint tests and verify full functionality and compliance.

### 4. Refactor v1 Type Adapters for Swagger Compliance

-   [ ] Identify all v1-specific request/response types (e.g., `TaskOutV1`, `AttackOutV1`) that exist solely to ensure `swagger.json` compliance.
-   [ ] Refactor these types to become the canonical request/response types for the v1 Agent API.
-   [ ] Remove or rename any redundant wrappers or adapters.
-   [ ] Update all v1 endpoints and service logic to use these types directly.
-   [ ] Run all v1 endpoint tests and verify strict compliance with `swagger.json`.

### 5. Cleanup Lingering Unused Code and Tests

-   [ ] Remove any unused types, endpoints, or test files that are no longer referenced after the refactor.
-   [ ] Run all v1 endpoint tests and verify no regressions or compliance issues.

---

## Final Validation

-   [ ] Run a full test suite (`just test` or equivalent) and ensure all tests pass.
-   [ ] Run contract/API schema validation against `swagger.json` to confirm:
    -   [ ] All v1 Agent API endpoints match the OpenAPI spec exactly (fields, enums, status codes, error envelopes).
-   [ ] Review code for any lingering references to v2 endpoints, routers, or service logic.
-   [ ] Confirm that the v1 Agent API is fully functional, stable, and ready for production use.

---

**Note:**

-   Each checklist item should be completed and validated before proceeding to the next.
-   The highest priority is to maintain strict v1 compatibility and avoid regressions during the removal of v2 logic.
-   As the items are completed, run `just test` to verify functionality and compliance. If all tests pass, the next item can be checked off. If any tests fail, fix the issue and verify the tests pass before checking off the item.
