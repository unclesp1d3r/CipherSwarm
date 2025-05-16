# Phase 5: Task Distribution System

This phase focuses on distributing attack workloads across available agents in the lab. It includes job scheduling, task generation, campaign-to-attack logic, and real-time synchronization with agent status.

!!! note

    This section seems to be completely unneeded. The task distribution system is now implemented in the agent API. We'll revisit this this phase to see what needs to be done after everything else is working. Perhaps we'll explore v2 of the agent API at this point. This may also become an improvement opportunity for various other parts of the system, including the task distribution system.

## ✅ Goals

-   Implement campaign execution engine
-   Assign attacks to agents based on priority and availability
-   Track task lifecycle from creation to completion
-   Package and serialize tasks to be sent to agents

## 📦 Implementation Tasks

-   [ ] Define task and attack schemas
-   [ ] Build a scheduler to:
    -   Monitor campaign queue
    -   Assign work to available agents
    -   Prioritize based on user control (power user/admin)
-   [ ] Create logic for packaging task into portable payload
-   [ ] Implement message protocol to dispatch jobs to agents
-   [ ] Track execution state (queued, dispatched, running, completed)
-   [ ] Handle failed jobs with retries or reassignment

## 🔧 Agent Sync

-   [ ] Implement agent polling endpoints (e.g., `/agent/heartbeat`, `/agent/pickup`)
-   [ ] Return task payloads securely
-   [ ] Support pausing or stopping campaigns via web UI

## 🔌 Dependencies

-   Campaigns
-   Agents
-   Attack resources
-   Agent status tracking
