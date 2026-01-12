# CipherSwarm Project Overview

- Purpose: Distributed hash cracking platform (Rails 8) inspired by Hashtopolis. Manages campaigns → attacks → tasks, with real-time UI via Hotwire and agent API.
- Status: Undergoing V2 upgrade (see docs/v2-upgrade-overview.md).
- Key domains: Campaigns (priority-driven), Attacks, Tasks (agent-assigned), Templates.
- AuthZ/AuthN: Devise + CanCanCan + Rolify for web UI; bearer tokens for agent API under /api/v1/client/\*.
- Real-time: Turbo Streams, Solid Cable. Background jobs via Sidekiq/sidekiq-cron.
- Storage: Active Storage (S3 prod, disk dev).
- Admin: Administrate dashboard /admin; Sidekiq web /sidekiq.
- Tests: RSpec (system/model/request), component tests (view_component), JS tests via Vitest.
- Architecture: Business logic mostly in models (no services dir). View components in app/components. Background jobs in app/jobs. API controllers in app/controllers/api/v1/.
- Repo owner: unclesp1d3r; default branch main; working branch 516-agent-monitoring-real-time-updates.
