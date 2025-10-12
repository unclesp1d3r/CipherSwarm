# Phase 5: Task Distribution System

This phase focuses on distributing attack workloads across available agents in the lab. It includes job scheduling, task generation, campaign-to-attack logic, and real-time synchronization with agent status.

---

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [Phase 5: Task Distribution System](#phase-5-task-distribution-system)
  - [Table of Contents](#table-of-contents)
  - [Goals](#goals)
  - [Implementation Tasks](#implementation-tasks)
  - [Agent Sync](#agent-sync)
  - [Dependencies](#dependencies)

<!-- mdformat-toc end -->

---

## Goals

- Implement campaign execution engine
- Assign attacks to agents based on priority and availability
- Track task lifecycle from creation to completion
- Package and serialize tasks to be sent to agents

## Implementation Tasks

- [ ] Implement algorithms for splitting up an attack into tasks based on total keyspace and agent benchmarks
- [ ] Build a scheduler to:
  - Sort campaigns by priority
  - Sort attacks by when campaigns are equal priority
  - Create tasks from attacks, dividing them up into chunks based on total keyspace and agent benchmarks
  - Provide tasks to agents upon request
  - Monitor agent status and reassign tasks if agents become unavailable
  - Notify agents when they are assigned tasks for an attack that is no longer running
- [ ] Implement message protocol to dispatch tasks to agents
- [ ] Track execution state (queued, dispatched, running, completed)
- [ ] Handle failed tasks with retries or reassignment

## Agent Sync

- [ ] Implement agent polling endpoints (e.g., `/agent/heartbeat`, `/agent/pickup`)
- [ ] Return task payloads securely
- [ ] Support pausing or stopping campaigns via web UI

## Dependencies

- Campaigns
- Agents
- Attack resources
- Agent status tracking
