# 🧪 Addendum: Full Testing Architecture Implementation (Post-SSR Migration)

This document defines the three-layer test system for CipherSwarm, aligned to use **Python 3.13 + `uv`**, **Node + `pnpm`**, and **Docker**.

## Intent

As we transition the CipherSwarm frontend from a mocked SPA-style workflow to a server-rendered SvelteKit application backed by real API calls, it’s critical that our test architecture evolves in parallel. This task formalizes a three-tiered test strategy to ensure quality at every layer of the stack: fast backend tests for core logic, frontend tests with mocked APIs for UX and layout, and a new full-stack E2E test layer driven by Playwright against real Dockerized backend services. These tiers will be orchestrated via `just` recipes so developers can test only what they’re working on, while `just ci-check` runs the full suite to catch regressions before merge or release. We should implement this with flexibility, reusing existing patterns where possible, while ensuring each layer is isolated, deterministic, and fully automated.

---

## ✅ Test Architecture Layers

| Layer       | Stack                                      | Purpose                                  |
|-------------|--------------------------------------------|------------------------------------------|
| `test-backend`  | Python (`pytest`, `testcontainers`)        | Backend API/unit integration             |
| `test-frontend` | JS (`vitest`, `playwright` with mocks)     | Frontend UI and logic validation         |
| `test-e2e`      | Playwright E2E (full stack, Docker backend) | True user flows across real stack        |

Each layer is isolated and driven by `justfile` recipes.

---

## 🐍 Layer 1: Python Backend Tests (existing)

- [ ] Confirm Python 3.13 + `uv` setup:

```bash
uv venv .venv && uv sync --dev
```

- [ ] Ensure `conftest.py` cleanly manages:
  - `PostgreSQLContainer`
  - `MinioContainer`
  - FastAPI app with DB overrides

- [ ] Add or validate `just test-backend`:

```text
test-backend:
    cd backend && uv pip sync requirements-dev.txt && pytest --tb=short -q
```

---

## 🧪 Layer 2: Frontend Unit + Mocked Integration (existing)

- [ ] Validate:
  - Vitest runs with `pnpm run test:unit`
  - Mocked Playwright tests run via `webServer` in `playwright.config.ts`

- [ ] Add or validate `just test-frontend`:

```text
test-frontend:
    cd frontend && pnpm run test:unit && pnpm exec playwright test --project=chromium
```

---

## 🌐 Layer 3: Full End-to-End Tests (new)

- [ ] Create `docker-compose.e2e.yml` with:
  - FastAPI backend (existing Dockerfile)
  - PostgreSQL (v16+)
  - MinIO (latest)
  - Ensure accessible at `http://localhost:8000`

- [ ] Add `/health` endpoint for readiness polling.

- [ ] Add `scripts/seed_data.py`:
  - Create seeded user/project/campaign/attack/resource objects
  - Use internal service layer or SQLAlchemy + MinIO directly

- [ ] Create `playwright/global-setup.ts`:

```typescript
import { execSync } from "child_process";
import fetch from "node-fetch";

module.exports = async () => {
    execSync("docker compose -f docker-compose.e2e.yml up -d --wait");
    let ready = false;
    while (!ready) {
        try {
            const res = await fetch("http://localhost:8000/health");
            if (res.ok) ready = true;
        } catch { await new Promise(r => setTimeout(r, 1000)); }
    }
    execSync("docker compose -f docker-compose.e2e.yml exec backend python scripts/seed_data.py");
};
```

- [ ] Create `playwright/global-teardown.ts` (or use `posttest` script):

```typescript
import { execSync } from "child_process";
module.exports = async () => {
    execSync("docker compose -f docker-compose.e2e.yml down -v");
};
```

- [ ] Add `tests/e2e/*.spec.ts` with:
  - Login to seeded user
  - Dashboard loads seeded campaign
  - Interact with agent/task views, modals, SSE (if implemented)

- [ ] Add `just test-e2e`:

```text
test-e2e:
    cd frontend && pnpm exec playwright test --project=chromium --config=playwright.config.ts
```

---

## 🧩 Aggregate CI Task

- [ ] Add `just ci-check`:

```text
ci-check:
    just test-backend
    just test-frontend
    just test-e2e
```

- [ ] Add github actions workflow to run the CI check on every push to main.

- [ ] Confirm the entire test stack runs with only:
  - Python 3.13 + `uv`
  - Node + `pnpm`
  - Docker (with Compose plugin)
