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
- [ ] When reassigning a paused task from a paused attack, automatically resumes the attack
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
- [ ] Task pause/resume actions respect the grace period for reassignment
- [ ] Reassigning a paused task from a paused attack triggers attack resume
- [ ] Paused tasks can be reclaimed by their original agent without waiting for grace period
- [ ] Task state transitions properly set/clear the paused_at timestamp

## Related State Transitions

### Task Pause/Resume Mechanism

Tasks can be paused during agent shutdown or disconnection. The pause/resume mechanism tracks task state across agent lifecycle events:

**Pause Behavior:**

- The `pause` event sets `paused_at: Time.current` using `update_columns` to bypass optimistic locking
- Claim fields (`claimed_by_agent_id`, `claimed_at`, `expires_at`) are cleared during agent shutdown
- The `agent_id` column (NOT NULL) is retained, pointing to the original owning agent
- This prevents `StaleObjectError` during cascaded operations when multiple tasks are paused simultaneously

**Resume Behavior:**

- The `resume` event clears `paused_at: nil` and sets `stale: true`, also using `update_columns`
- `stale: true` ensures the resuming agent re-downloads crack data
- This bypasses optimistic locking to avoid concurrent update conflicts
- See Task State Machine Transitions documentation for full state machine details

**Grace Period for Reassignment:**

- After pausing, tasks use the `paused_at` timestamp to determine reassignment eligibility
- Within the grace period (`agent_considered_offline_time`, default 30 minutes), only the original agent can reclaim the task
- After the grace period expires, any compatible agent can claim the orphaned task
- Tasks from offline/stopped agents are available for reassignment immediately, bypassing the grace period
- This two-stage reclamation prevents tasks from being stolen during brief agent disconnections

**Task Assignment Priority:**

TaskAssignmentService uses two-stage task reclamation:

1. **Own paused tasks first**: Agents reclaim their own paused tasks to leverage restore files and minimize redundant work
2. **Orphaned tasks second**: After the grace period, agents can claim paused tasks from other agents

When reassigning a paused task from a paused attack (e.g., during shutdown cascade), the attack is automatically resumed to maintain consistent state.

### Agent Shutdown Impact

When an agent shuts down (via `agent.shutdown!` or agent disconnection), it triggers a cascade of state transitions:

**Task Pausing:**

- All running tasks are paused and their claim fields cleared
- The `paused_at` timestamp is set to track when the pause occurred
- The `agent_id` remains set to the original agent for reclamation

**Attack Pausing:**

- Attacks with no remaining active (non-paused) tasks are automatically paused during shutdown
- This updates the Activity page to reflect that work has stopped
- Paused attacks must be resumed when their tasks are reclaimed by other agents

**Reassignment Considerations:**

- Paused tasks from a paused attack require the attack to be resumed during reassignment
- TaskAssignmentService automatically resumes paused attacks when claiming their tasks
- This prevents inconsistent state where tasks are active but their attack remains paused
- Cross-reference the Agent Shutdown Cascade documentation for complete shutdown behavior

### State Machine Integration

Task state machine transitions use `update_columns` to avoid optimistic locking issues:

**Why `update_columns`:**

- The pause/resume events bypass ActiveRecord callbacks and validations
- This prevents `StaleObjectError` during cascaded operations (e.g., attack shutdown pausing multiple tasks)
- The `lock_version` counter is not incremented, avoiding version conflicts
- See StaleObjectError From Cascading Resume documentation for handling concurrent updates

**State Transition Sequence:**

```
pause event: task.update_columns(paused_at: Time.current)
resume event: task.update_columns(stale: true, paused_at: nil)
```

This approach ensures consistent state management across the task lifecycle without introducing race conditions during bulk operations.

## Technical References

- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (Flow 3: Task Detail Investigation)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (TasksController, State Machine Extensions, Authorization)
- **Task State Machine Transitions**: For detailed pause/resume behavior and `paused_at` timestamp management
- **Agent Shutdown Cascade**: For agent shutdown impact on task and attack state
- **StaleObjectError From Cascading Resume**: For handling concurrent updates during attack resume

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
