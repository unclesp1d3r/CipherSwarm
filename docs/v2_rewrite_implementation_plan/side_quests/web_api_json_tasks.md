## 🔢 Web API JSON Task List for SvelteKit Migration

This document defines the required `/api/v1/web/*` JSON endpoints to support the CipherSwarm SvelteKit frontend. It is broken into milestone-oriented task groups.

---

### 📜 Refactor Instructions (Required for Every Endpoint)

For each file migrated from HTMX to JSON:

1. **Return JSON only.** Remove all uses of `TemplateResponse`, `render()`, or Jinja/HTMX fragment logic.
2. **Use Pydantic schemas.** Ensure all endpoints return models defined via `@dataclass` or `BaseModel`. Inline them temporarily if needed.
3. **Use FastAPI parameter types.** Always define inputs with `Query`, `Path`, `Body`, or `Depends`.
4. **Do not manually parse inputs.** Let FastAPI/Pydantic handle 422s. Never raise or format them by hand.
5. **Update tests to expect JSON.** Replace old HTMX/HTML expectations with assertions against response JSON structures. Do not remove coverage.
6. **Do not add or modify unrelated functionality.** No extra logic, model tweaks, or guessing features.
7. **Annotate WS triggers.** Add a comment `# WS_TRIGGER: <desc>` to any route that causes live updates.
8. **Scaffold only what you need.** Use minimal `ResponseModel` if none exists. Prefer reuse.

🧪 **Definition of Done:**
- [x] All routes in the file return proper JSON
- [x] Jinja/template logic removed
- [x] HTMX-only behavior stripped
- [x] Pydantic-based request and response models used
- [x] Test file updated to match new JSON behavior (not deleted)
- [x] Commit is clean, isolated, and passes lint

Use this checklist as the canonical reference for all `/api/v1/web/` JSON endpoint refactors.

---

### 📌 Milestone 1: Authentication & User Context

- [ ] `POST /auth/login`
- [ ] `POST /auth/logout`
- [ ] `POST /auth/refresh`
- [ ] `GET /auth/me`
- [ ] `PATCH /auth/me`
- [ ] `POST /auth/change_password`
- [ ] `GET /auth/context`
- [ ] `POST /auth/context`

---

### 📌 Milestone 2: Admin User and Project Management

- [ ] `GET /users/`
- [ ] `POST /users/`
- [ ] `GET /users/{id}`
- [ ] `PATCH /users/{id}`
- [ ] `DELETE /users/{id}`
- [ ] `GET /projects/`
- [ ] `POST /projects/`
- [ ] `GET /projects/{id}`
- [ ] `PATCH /projects/{id}`
- [ ] `DELETE /projects/{id}`

---

### 📌 Milestone 3: Agent Management (CRUD + Performance)

- [ ] `GET /agents/`
- [ ] `POST /agents`
- [ ] `GET /agents/{id}`
- [ ] `PATCH /agents/{id}`
- [ ] `POST /agents/{id}/requeue`
- [ ] `GET /agents/{id}/benchmarks`
- [ ] `POST /agents/{id}/test_presigned`
- [ ] `PATCH /agents/{id}/config`
- [ ] `PATCH /agents/{id}/devices`
- [ ] `POST /agents/{id}/benchmark`
- [ ] `GET /agents/{id}/errors`
- [ ] `GET /agents/{id}/performance`
- [ ] `GET /agents/{id}/hardware`
- [ ] `PATCH /agents/{id}/hardware`
- [ ] `GET /agents/{id}/capabilities`

---

### 📌 Milestone 4: Campaign CRUD + Lifecycle

- [ ] `GET /campaigns/`
- [ ] `POST /campaigns/`
- [ ] `GET /campaigns/{id}`
- [ ] `PATCH /campaigns/{id}`
- [ ] `DELETE /campaigns/{id}`
- [ ] `POST /campaigns/{id}/start`
- [ ] `POST /campaigns/{id}/stop`
- [ ] `POST /campaigns/{id}/add_attack`
- [ ] `POST /campaigns/{id}/reorder_attacks`
- [ ] `GET /campaigns/{id}/progress`
- [ ] `GET /campaigns/{id}/metrics`
- [ ] `POST /campaigns/{id}/relaunch`

---

### 📌 Milestone 5: Attack CRUD + Preview & Tuning

- [ ] `GET /attacks/`
- [ ] `POST /attacks/`
- [ ] `GET /attacks/{id}`
- [ ] `PATCH /attacks/{id}`
- [ ] `DELETE /attacks/{id}`
- [ ] `POST /attacks/{id}/move`
- [ ] `POST /attacks/{id}/duplicate`
- [ ] `POST /attacks/{id}/disable_live_updates`
- [ ] `GET /attacks/{id}/performance`
- [ ] `POST /attacks/validate`
- [ ] `POST /attacks/estimate`

---

### 📌 Milestone 6: Resource Browser & Line Editing

- [ ] `GET /resources/`
- [ ] `POST /resources/`
- [ ] `GET /resources/{id}`
- [ ] `PATCH /resources/{id}`
- [ ] `DELETE /resources/{id}`
- [ ] `GET /resources/{id}/preview`
- [ ] `PATCH /resources/{id}/content`
- [ ] `POST /resources/{id}/refresh_metadata`
- [ ] `GET /resources/{id}/lines`
- [ ] `POST /resources/{id}/lines`
- [ ] `PATCH /resources/{id}/lines/{line_id}`
- [ ] `DELETE /resources/{id}/lines/{line_id}`

---

### 📌 Milestone 7: Crackable Uploads

- [ ] `POST /uploads/`
- [ ] `GET /uploads/{id}/status`
- [ ] `POST /uploads/{id}/launch_campaign`
- [ ] `GET /uploads/{id}/errors`
- [ ] `DELETE /uploads/{id}`

---

### 📌 Milestone 8: Dashboard & UX Utilities

- [ ] `GET /dashboard/summary`
- [ ] `GET /health/overview`
- [ ] `GET /health/components`
- [ ] `GET /options/agents`
- [ ] `GET /options/resources`
- [ ] `GET /modals/rule_explanation`
- [ ] `GET /fragments/validation`
- [ ] `GET /fragments/metadata_tag`
