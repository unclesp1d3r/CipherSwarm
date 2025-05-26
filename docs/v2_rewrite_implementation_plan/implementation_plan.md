# CipherSwarm Implementation Plan

This document outlines the phased implementation plan for rebuilding CipherSwarm with FastAPI, SvelteKit, and modern backend architecture. Each phase builds upon the last and ensures a modular, testable, and maintainable system.

---

## 🚀 Implementation Phases

### Phase 1: Core Infrastructure

👉 [Read Phase 1: Core Infrastructure Setup](phase-1-core-infrastructure.md)

-   [x] 👤 User Model
-   [x] 📁 Project Model
-   [x] 🧠 OperatingSystem Model
-   [x] 🤖 Agent Model
-   [x] ⚠️ AgentError Model
-   [x] 💥 Attack Model
-   [x] 🧾 Task Model

### Phase 2: API Implementation

👉 [Read Phase 2: API Implementation](phase-2-api-implementation.md)

-   [x] 🔐 Agent API (High Priority)
    -   [x] Agent Authentication & Session Management
    -   [x] Attack Distribution
-   [ ] 🧠 Web UI API
    -   [x] Campaign Management
    -   [x] Attack Management
    -   [ ] Agent Management
    -   [ ] Resource Browser
    -   [ ] Crackable Uploads
    -   [ ] Authentication & Profile
    -   [ ] UX Utility
    -   [ ] Live Svelte / WebSocket Feeds
-   [ ] Control API

### Phase 2b: Resource Management

👉 [Read Phase 2b: Resource Management](phase-2b-resource-management.md)
- [x] Add `minio-py` support to project
- [x] Add `MinioContainer` testcontainers support for integration tests
- [x] Add `StorageService` to handle MinIO operations
- [x] Migrate `resource_service` to use `StorageService`
- [x] Develop full suite of tests for `StorageService`
- [x] Develop full suite of tests for `resource_service`
- [x] Finalize Resource Management API and implement all endpoints

Phase 2b was fully completed and tested, allowing file-backed resources to be supported via the MinIO object storage.

### Phase 3: Web UI Development

👉 [Read Phase 3: Web UI Development](phase-3-web-ui.md)

### Phase 4: Containerization and Deployment

👉 [Read Phase 4: Containerization and Deployment](phase-4-containerization-deployment.md)

### Phase 5: Task Distribution System

👉 [Read Phase 5: Task Distribution System](phase-5-task-distribution.md)

### Phase 6: Monitoring, Testing & Documentation

👉 [Read Phase 6: Monitoring, Testing, Documentation](phase-6-monitoring-testing-documentation.md)

### Phase 7: TUI Development

👉 [Read Phase 7: TUI Development](phase-7-tui-development.md)

---

## 📝 Notes

-   [Core Algorithm Implementation Guide](core_algorithm_implementation_guide.md)
-   Phase 4 was moved up to phase 2b to allow for the resource management to be completed before the web UI is fully implemented. There's currently a TODO to reshuffle the phases to reflect this, but just move to 5 after 3 is completed.
-   As items in the various phases are completed, they are rolled up and added to this overview document.
