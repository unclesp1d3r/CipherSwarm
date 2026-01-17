# Task Management Actions

## Overview

Implement task management capabilities allowing users to cancel, retry, reassign tasks, view logs, and download results. This ticket delivers the task detail investigation flow from spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad.

## Scope

**Included:**

- TasksController with actions: show, cancel, retry, reassign, logs, download_results
- Task detail page with task information and action buttons
- Agent compatibility validation for reassign
- CanCanCan authorization rules for task actions
- TaskActionsComponent for action buttons
- Routes for task actions
- Turbo Stream responses for inline updates

**Excluded:**

- Task creation (handled by Agent API)
- Task assignment logic (already exists in Agent#new_task)
- Bulk task operations (out of scope)

## Acceptance Criteria

### TasksController

**Show Action:**

- [ ] Route: `GET /tasks/:id`
- [ ] Displays task details: state, agent, attack, campaign, progress, timestamps
- [ ] Shows current status (from latest HashcatStatus)
- [ ] Shows action buttons (cancel, retry, reassign based on state)
- [ ] Authorization: project-based (can only view tasks in user's projects)

**Cancel Action:**

- [ ] Route: `POST /tasks/:id/cancel`
- [ ] Uses state machine event: `task.cancel`
- [ ] Only available for pending/running tasks
- [ ] Returns Turbo Stream response (update task + show toast)
- [ ] Authorization: project-based

**Retry Action:**

- [ ] Route: `POST /tasks/:id/retry`
- [ ] Uses state machine event: `task.retry` (failed → pending)
- [ ] Only available for failed tasks
- [ ] Increments retry_count, clears last_error
- [ ] Returns Turbo Stream response (update task + show toast)
- [ ] Authorization: project-based

**Reassign Action:**

- [ ] Route: `POST /tasks/:id/reassign`
- [ ] Validates agent compatibility (hash type, performance, project access)
- [ ] Updates task agent and resets to pending state
- [ ] Returns error if agent incompatible
- [ ] Returns Turbo Stream response (update task + show toast)
- [ ] Authorization: project-based

**Logs Action:**

- [ ] Route: `GET /tasks/:id/logs`
- [ ] Displays HashcatStatus history (last 100 records)
- [ ] Shows: timestamp, status, progress, hash_rate, temperature
- [ ] Paginated if > 50 records
- [ ] Authorization: project-based

**Download Results Action:**

- [ ] Route: `GET /tasks/:id/download_results`
- [ ] Generates CSV of cracked hashes for this task
- [ ] CSV columns: Hash, Plaintext, Cracked At
- [ ] Filename: `task_{id}_results_{timestamp}.csv`
- [ ] Authorization: project-based

### Agent Compatibility Validation

- [ ] Method `agent_compatible_with_task?(agent, task)` validates:

  - Agent supports task's hash type (check allowed_hash_types)
  - Agent meets performance threshold (check meets_performance_threshold?)
  - Agent has access to task's project (check project_ids)

- [ ] Reassign UI only shows compatible agents (filtered dropdown/select)

- [ ] Backend validation provides defense-in-depth

### Authorization Rules

- [ ] CanCanCan abilities added to app/models/ability.rb:
  - `can :read, Task, attack: { campaign: { project_id: user.project_ids } }`
  - `can :cancel, Task, attack: { campaign: { project_id: user.project_ids } }`
  - `can :retry, Task, attack: { campaign: { project_id: user.project_ids } }`
  - `can :reassign, Task, attack: { campaign: { project_id: user.project_ids } }`
  - `can :download_results, Task, attack: { campaign: { project_id: user.project_ids } }`
  - `can :manage, Task if user.admin?`

### Task Detail Page

- [ ] Task header shows: ID, state, agent, attack, campaign
- [ ] Progress section shows: percentage, ETA, status text
- [ ] Status history table shows recent HashcatStatus records
- [ ] Error section shows task errors (if any)
- [ ] Action buttons shown based on task state and permissions
- [ ] Links to related resources (agent, attack, campaign)

### Components

- [ ] `TaskActionsComponent` created with conditional button display
- [ ] Component shows cancel/retry/reassign/logs/download based on task state
- [ ] Component respects authorization (only show allowed actions)

### Testing

- [ ] Request specs for all TasksController actions
- [ ] System test: Cancel task, verify state change and toast
- [ ] System test: Retry failed task, verify state change
- [ ] System test: Reassign task to compatible agent
- [ ] System test: Reassign to incompatible agent, verify error
- [ ] System test: Download results CSV, verify content
- [ ] Authorization specs for task actions

## Technical References

- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (Flow 3: Task Detail Investigation)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (TasksController, State Machine Extensions, Authorization)

## Dependencies

**Requires:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[Database Schema & Model Extensions] - Needs Task retry event
- ticket:50650885-e043-4e99-960b-672342fc4139/[UI Components & Loading States] - Needs TaskActionsComponent, toast notifications

**Blocks:**

- None (other features can be implemented in parallel)

## Implementation Notes

- Create new controller: app/controllers/tasks_controller.rb
- Create new views directory: app/views/tasks/
- Use existing Task state machine events where possible
- Test agent compatibility validation with various scenarios
- Ensure CSV download works in air-gapped environment (no external dependencies)
- Use Turbo Stream responses for all actions (progressive enhancement)

## Estimated Effort

**2-3 days** (controller + views + validation + tests)
