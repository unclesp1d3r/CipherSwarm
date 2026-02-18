# CipherSwarm User Guide

Welcome to the CipherSwarm User Guide. This documentation covers everything you need to know to use CipherSwarm effectively, from initial setup to advanced attack configuration and troubleshooting.

---

## Table of Contents

### Getting Started

- [Getting Started](getting-started.md) - First-time setup, dashboard overview, and your first campaign

### Core Operations

- [Campaign Management](campaign-management.md) - Creating, monitoring, and managing campaigns
- [Attack Configuration](attack-configuration.md) - Configuring dictionary, mask, brute force, and hybrid attacks
- [Understanding Results](understanding-results.md) - Viewing, interpreting, and exporting cracking results

### Agent Management

- [Agent Setup](agent-setup.md) - Installing, registering, and configuring agents
- [Agent Troubleshooting](troubleshooting-agents.md) - Detailed agent diagnostics and task lifecycle troubleshooting

### Resources

- [Resource Management](resource-management.md) - Managing wordlists, rule files, mask patterns, and charsets

### Troubleshooting and Reference

- [Troubleshooting](troubleshooting.md) - System diagnostics, common issues, and solutions
- [Common Issues](common-issues.md) - Quick fixes for frequently encountered problems
- [FAQ](faq.md) - Frequently asked questions

### Advanced Topics

- [Performance Optimization](optimization.md) - Hardware tuning, attack strategies, and system optimization
- [Web Interface](web-interface.md) - Complete web interface reference
- [Air-Gapped Deployment](air-gapped-deployment.md) - Deploying CipherSwarm in isolated environments

---

## Quick Navigation

| I want to...                          | Go to                                                                           |
| ------------------------------------- | ------------------------------------------------------------------------------- |
| Set up CipherSwarm for the first time | [Getting Started](getting-started.md)                                           |
| Create my first campaign              | [Getting Started](getting-started.md#your-first-campaign)                       |
| Register a new agent                  | [Agent Setup](agent-setup.md#agent-registration-administrator)                  |
| Configure an attack                   | [Attack Configuration](attack-configuration.md)                                 |
| View cracked hashes                   | [Understanding Results](understanding-results.md)                               |
| Upload wordlists or rules             | [Resource Management](resource-management.md)                                   |
| Fix a problem                         | [Troubleshooting](troubleshooting.md)                                           |
| Check system health                   | [Troubleshooting](troubleshooting.md#quick-diagnostics-system-health-dashboard) |
| Deploy in an air-gapped environment   | [Air-Gapped Deployment](air-gapped-deployment.md)                               |
| Optimize performance                  | [Performance Optimization](optimization.md)                                     |

---

## What's New in V2

CipherSwarm V2 introduces several new features for improved operational visibility and control:

### Agent Monitoring

Real-time agent status tracking with live hash rate monitoring, error badges, performance charts (8-hour trends), and detailed agent views with tabs for Overview, Errors, Configuration, and Capabilities. See [Agent Setup](agent-setup.md#agent-monitoring).

### Campaign Progress

Enhanced campaign visualization with an attack stepper, progress bars with ETA display, a recent cracks feed, campaign error logs, and real-time updates via Turbo Streams. See [Campaign Management](campaign-management.md#campaign-progress-monitoring).

### Task Management

New task detail views with inline actions for cancelling, retrying, and reassigning tasks directly from the web interface. Includes task status history and error handling. See [Agent Troubleshooting](troubleshooting-agents.md#task-management-actions).

### System Health Dashboard

A dedicated health monitoring page showing the status of PostgreSQL, Redis, MinIO, and the application itself. Includes real-time metrics, diagnostics information, and automatic refresh. See [Troubleshooting](troubleshooting.md#quick-diagnostics-system-health-dashboard).

---

## Documentation Conventions

Throughout this guide:

- **Bold text** indicates UI elements (buttons, menu items, labels)
- `Monospace text` indicates commands, file paths, or configuration values
- Indented code blocks show configuration examples or command output
- Links in square brackets reference other sections or guides

---

## Getting Help

If you cannot find an answer in this documentation:

1. Check the [FAQ](faq.md) for common questions
2. Review [Common Issues](common-issues.md) for quick fixes
3. Consult the [Troubleshooting](troubleshooting.md) guide for detailed diagnostics
4. Visit the [GitHub Issues](https://github.com/unclesp1d3r/CipherSwarm/issues) page to report bugs or request features
