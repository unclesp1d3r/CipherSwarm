# Phase 6: Monitoring, Testing & Documentation

This final phase ensures that CipherSwarm is well-tested, observable, and documented before public or operational deployment.

## 🧪 Testing

- [ ] Integration testing using `httpx` and `pytest-postgresql`
- [ ] Unit tests for business logic and attack models
- [ ] Split `/tests/unit` and `/tests/integration` as per guidelines
- [ ] Ensure every HTTP endpoint has integration coverage
- [ ] Run full `just ci-check` to enforce pre-commit + formatting

## 📊 Monitoring

- [ ] Add heartbeat timestamp tracking for agents
- [ ] Add performance metrics for tasks and campaign throughput
- [ ] Add Prometheus-compatible `/metrics` if possible
- [ ] Include logs via `loguru` throughout backend processes

## 📚 Documentation

- [ ] Developer onboarding (README + architecture overview)
- [ ] Admin instructions for configuring agents and launching campaigns
- [ ] Swagger or ReDoc integration for API browsing

## ⚙️ Seeding

- [ ] Create database seed scripts for:
  - Admin user
  - Example hashlist/project/campaign
  - Common wordlists and rules

## 🔁 UI Checklist

- [ ] Role-based access control works across all views
- [ ] All buttons work and pages load with valid data
- [ ] Toast notifications appear on crack events and fail gracefully when rate-limited
- [ ] SSE updates functional on campaign dashboard
