# User Guide Documentation

## Overview

Create comprehensive user guide documentation covering system usage, troubleshooting, and air-gapped deployment. This ticket addresses the documentation acceptance criteria from spec:50650885-e043-4e99-960b-672342fc4139/032658c4-43ca-40d4-adb4-682b6bca964a.

## Scope

**Included:**

- User guide markdown documentation
- Getting started guide
- Campaign management guide
- Agent management guide
- Resource management guide
- Understanding results guide
- Troubleshooting guide
- Air-gapped deployment validation checklist

**Excluded:**

- API documentation (already exists via Swagger)
- Developer documentation (separate concern)
- Video tutorials or screenshots (text-based only)

## Acceptance Criteria

### User Guide Structure

- [ ] Documentation created in: file:docs/user-guide/
- [ ] Table of contents with links to all sections
- [ ] Markdown format for easy editing and version control

### Getting Started

- [ ] First-time setup and configuration
- [ ] User account creation and login
- [ ] Project setup
- [ ] Agent registration process
- [ ] Basic navigation overview

### Campaign Management

- [ ] Creating campaigns (name, priority, hash list selection)
- [ ] Adding attacks to campaigns (dictionary, mask, hybrid)
- [ ] Monitoring campaign progress (progress bars, ETAs)
- [ ] Understanding campaign states (pending, running, completed)
- [ ] Viewing cracked hashes
- [ ] Exporting results

### Agent Management

- [ ] Registering agents (token generation, configuration)
- [ ] Monitoring agent status (online/offline, performance metrics)
- [ ] Troubleshooting agent connectivity issues
- [ ] Understanding agent errors
- [ ] Agent project assignment
- [ ] Agent benchmarking

### Resource Management

- [ ] Uploading word lists, rule lists, mask lists
- [ ] Managing hash lists
- [ ] Understanding resource complexity
- [ ] File format requirements
- [ ] Storage limits and best practices

### Understanding Results

- [ ] Viewing cracked hashes
- [ ] Exporting data (CSV download)
- [ ] Understanding hash types
- [ ] Interpreting attack results
- [ ] Progress tracking

### Troubleshooting

- [ ] Common issues and solutions:
  - Agent won't connect
  - Tasks stuck in pending state
  - Attacks failing
  - Slow performance
  - System health issues
- [ ] How to check logs
- [ ] How to use system health dashboard
- [ ] When to contact support

### Air-Gapped Deployment Checklist

- [ ] Pre-deployment validation checklist (10 items from Epic Brief):

  - All CSS/JS assets bundled
  - All fonts embedded or system fonts
  - All icons/images in asset pipeline
  - Docker compose works without Internet
  - All pages load without external requests
  - Asset precompilation successful
  - Health check endpoints work in isolated network
  - Agent API accessible from isolated agents
  - File uploads/downloads work with MinIO
  - Documentation accessible offline

- [ ] Deployment instructions for air-gapped environments

- [ ] Troubleshooting offline deployment issues

## Technical References

- **Epic Brief**: spec:50650885-e043-4e99-960b-672342fc4139/032658c4-43ca-40d4-adb4-682b6bca964a (Documentation acceptance criteria, Air-Gapped Deployment)
- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (All flows provide user journey context)

## Dependencies

**Requires:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[Agent Monitoring & Real-Time Updates] - Document new agent monitoring features
- ticket:50650885-e043-4e99-960b-672342fc4139/[Campaign Progress & ETA Display] - Document new campaign progress features
- ticket:50650885-e043-4e99-960b-672342fc4139/[Task Management Actions] - Document task management actions
- ticket:50650885-e043-4e99-960b-672342fc4139/[System Health Monitoring] - Document system health dashboard

**Blocks:**

- None (documentation can be written in parallel with implementation)

## Implementation Notes

- Create documentation in file:docs/user-guide/ directory
- Use markdown format for easy editing
- Include screenshots or ASCII diagrams where helpful (optional)
- Keep language simple and user-friendly (not technical)
- Test all documented procedures in air-gapped environment
- Ensure documentation is accessible offline (bundled in container or separate package)
- Link to existing API documentation (Swagger) where relevant
- Update README.md with link to user guide

## Estimated Effort

**2-3 days** (comprehensive documentation + validation)
