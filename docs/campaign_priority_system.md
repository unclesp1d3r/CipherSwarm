# Campaign Priority System

CipherSwarm uses a simplified 3-tier priority system to manage hash cracking campaigns efficiently. This system balances urgency with resource utilization through intelligent scheduling and task preemption.

## Priority Levels

The system supports three priority levels:

| Priority     | Value | Description                                            | Authorization                           |
| ------------ | ----- | ------------------------------------------------------ | --------------------------------------- |
| **High**     | 2     | Important campaigns requiring immediate attention      | Project admins/owners and global admins |
| **Normal**   | 0     | Default priority for regular campaigns                 | All project members                     |
| **Deferred** | -1    | Best-effort campaigns that run when capacity available | All project members                     |

## Authorization Requirements

### Setting High Priority

Only users with elevated permissions can create or update campaigns with high priority:

- **Project Admins**: Members with `admin` or `owner` role in the campaign's project
- **Global Admins**: System administrators with `admin` flag

Regular project members (viewers, editors, contributors) are restricted to `normal` and `deferred` priorities.

### Authorization Checks

When creating or updating a campaign with high priority:

1. System checks if user is a global admin
2. If not, system verifies user has admin/owner role in the campaign's project
3. Unauthorized attempts are rejected with an alert message

## Intelligent Scheduling Behavior

CipherSwarm uses priority-aware task distribution to maximize node utilization while respecting priority ordering.

### Task Assignment Algorithm

When an agent requests a new task:

1. **Priority Ordering**: Available attacks are ordered by campaign priority (high → normal → deferred), then by complexity
2. **Node Availability**: If nodes are available, tasks are assigned from the highest priority attacks
3. **Parallel Execution**: Multiple campaigns at the same priority level can run simultaneously on available nodes
4. **Preemption**: When all nodes are busy and a high-priority attack needs resources, the system may preempt lower-priority tasks

### Preemption Rules

Tasks are preempted based on intelligent criteria to minimize waste:

1. **Progress Protection**: Tasks >90% complete are never preempted
2. **Starvation Prevention**: Tasks preempted ≥2 times cannot be preempted again
3. **Least Impact**: System selects the least complete task from the lowest priority campaign
4. **Progress Preservation**: Preempted tasks return to pending state with progress saved

### Resource Utilization

The system ensures efficient resource usage:

- **No Idle Nodes**: All available agents work simultaneously when possible
- **Fair Distribution**: Lower priority campaigns run when capacity exists
- **Dynamic Rebalancing**: Task preemption is triggered automatically when campaign priority increases and periodically for non-deferred campaigns
- **Graceful Degradation**: Deferred campaigns wait naturally without preemption attempts

## Usage Scenarios

### Scenario 1: Routine Operations

**Setup**: 5 normal-priority campaigns, 5 available nodes

**Behavior**: All campaigns run simultaneously, maximizing throughput

### Scenario 2: Urgent Response

**Setup**: 2 normal-priority campaigns running, 2 nodes occupied, new high-priority campaign added

**Behavior**:

1. High-priority campaign needs resources
2. System preempts least-complete normal-priority task
3. High-priority task starts immediately
4. Remaining normal-priority campaign continues
5. Preempted task returns to pending and will resume when capacity available

### Scenario 3: Mixed Priorities

**Setup**: 1 high, 2 normal, 2 deferred campaigns; 3 available nodes

**Behavior**:

1. High-priority campaign gets first assignment
2. Both normal-priority campaigns get assignments
3. Deferred campaigns wait until capacity increases

### Scenario 4: Project-Specific Work

**Setup**: User creates campaign in project where they are not admin

**Behavior**:

- User can select `normal` or `deferred` priority only
- `high` priority option not shown in UI
- Attempting to set high priority via API returns authorization error

## Best Practices

### When to Use High Priority

- **Security Incidents**: Active breach response requiring immediate password analysis
- **Time-Sensitive Operations**: Critical deadlines with business impact
- **Small Targeted Attacks**: Quick, focused cracking jobs that benefit from immediate execution

**Note**: Reserve high priority for genuinely urgent work. Overuse diminishes effectiveness.

### When to Use Normal Priority

- **Regular Operations**: Standard hash cracking workflows
- **Scheduled Analysis**: Routine security assessments
- **Moderate Urgency**: Important work without immediate deadlines

**Note**: Normal priority is appropriate for 90%+ of campaigns.

### When to Use Deferred Priority

- **Research and Testing**: Experimental or exploratory work
- **Low-Priority Backlogs**: Nice-to-have analysis with no deadlines
- **Bulk Processing**: Large hash sets with no urgency

**Note**: Deferred campaigns make efficient use of spare capacity without impacting critical work.

## Monitoring and Management

### Manual Controls

Campaigns can be manually paused and resumed regardless of priority:

```ruby
campaign.pause   # Pauses all attacks
campaign.resume  # Resumes paused attacks
```

Manual controls are useful for:

- Temporarily stopping work for maintenance
- Adjusting execution without changing priority
- Emergency response situations

### Progress Tracking

Monitor campaign execution through:

- **Dashboard**: Real-time progress updates via Hotwire
- **ETAs**: Estimated completion times for running and pending attacks
- **Task Status**: Individual task progress and state
- **Preemption Logs**: Audit trail of preemption events

### Logs

Key log events for troubleshooting:

```
[TaskPreemption] Preempting task {id} (priority: {priority}, progress: {progress}%)
  for attack {attack_id} (priority: {priority})
```

Check logs to verify preemption behavior and identify potential issues.

### Operator View of Preemption

From an operator perspective, preemption looks like this:

- When you start a **high-priority** campaign while all nodes are busy with **normal/deferred** work, or when you raise an existing campaign's priority, one of the lower-priority tasks will move from **Running → Pending** and be marked **stale**.
- On the **dashboard**, you will see:
  - The new or newly-prioritized high-priority attack start running on at least one agent.
  - One or more lower-priority tasks transition to **Pending** with their last progress preserved.
- In **logs**, you will see a `[TaskPreemption] Preempting task ...` entry with the task ID, campaign priority, and progress percentage at the moment of preemption.
- When capacity frees up, preempted tasks will be rescheduled automatically. Because they are marked **stale**, agents will re-sync crack results before resuming.

If preemption is not happening when you expect it to:

- Confirm there is at least one **high-priority** campaign with remaining uncracked hashes.
- Verify all agents are already busy with **normal** or **deferred** campaigns in the same project.
- Check that the running tasks are not protected by the rules (e.g., >90% complete or preempted 2+ times).
- Review logs for `[TaskPreemption]`, `[TaskRebalance]`, and `[UpdateStatusJob]` entries to see why no candidate tasks were eligible.

## Migration from 7-Tier System

The previous system used 7 priority levels with hard pausing:

- `flash_override` (5), `flash` (4), `immediate` (3) → **high** (2)
- `urgent` (2), `priority` (1), `routine` (0) → **normal** (0)
- `deferred` (-1) → **deferred** (-1)

### Benefits of Simplified System

- ✅ **Clarity**: Easy-to-understand priority levels
- ✅ **Efficiency**: Maximizes node utilization
- ✅ **Fairness**: Lower priority work progresses when capacity exists
- ✅ **Control**: Clear authorization for high-priority campaigns
- ✅ **Flexibility**: Intelligent preemption balances urgency with waste reduction

## Technical Implementation

### Key Components

- **Campaign Model**: Priority enum and manual pause/resume methods
- **TaskAssignmentService**: Priority-aware attack ordering
- **TaskPreemptionService**: Intelligent task preemption logic
- **CampaignPriorityRebalanceJob**: Automatic task rebalancing when campaign priority increases
- **UpdateStatusJob**: Periodic task rebalancing for non-deferred campaigns
- **Task Model**: Preemption tracking and preemptability checks

### Automatic Priority-Based Rebalancing

When a campaign's priority is increased, the system automatically triggers task preemption to free up resources for the higher-priority work:

- **Trigger Mechanism**: The `Campaign` model includes an `after_commit` callback (`trigger_priority_rebalance_if_needed`) that fires after a priority change is committed to the database
- **Condition**: The callback only enqueues a job when priority increases (e.g., normal → high), not when it decreases or remains unchanged
- **Job Execution**: `CampaignPriorityRebalanceJob` is enqueued immediately (not scheduled) to provide responsive task preemption
- **Preemption Logic**: The job iterates through the campaign's incomplete attacks and calls `TaskPreemptionService.preempt_if_needed` for each attack with remaining uncracked hashes
- **Error Handling**: Errors during preemption of individual attacks are logged and skipped, allowing the job to process remaining attacks

This event-driven approach ensures that when an operator raises a campaign's priority, lower-priority tasks are preempted immediately without waiting for the next periodic rebalancing cycle.

### Periodic Background Rebalancing

In addition to event-driven rebalancing, the system performs periodic checks for preemption opportunities:

- **UpdateStatusJob**: Runs on a scheduled interval (configured via `config/schedule.yml` with sidekiq-cron, default: every 3 minutes) to perform various maintenance tasks
- **Rebalancing Scope**: Checks for incomplete attacks in **non-deferred** campaigns (both normal and high priority) that have no running tasks
- **Preemption Evaluation**: For each attack with remaining work, the job calls `TaskPreemptionService.preempt_if_needed` to evaluate whether lower-priority tasks should be preempted
- **Complementary Mechanisms**: Both automatic (priority increase) and periodic (scheduled job) rebalancing work together to ensure efficient resource allocation

The periodic rebalancing provides a safety net to handle edge cases and ensures that normal-priority campaigns can also benefit from preemption when appropriate.

### Database Schema

```ruby
# campaigns table
priority: integer, default: 0, null: false
# Comment: -1: Deferred, 0: Normal, 2: High

# tasks table
preemption_count: integer, default: 0, null: false
# Tracks number of times task has been preempted
```

### State Transitions

Tasks preserve progress when preempted:

1. Running task receives `preempt` event
2. Task transitions to `pending` state
3. `stale` flag set to indicate new cracks may exist
4. `preemption_count` incremented
5. Agent receives updated crack list on next assignment

## Troubleshooting

### Issue: High-Priority Campaign Not Starting

**Possible Causes**:

- No available agents in campaign's project
- All agents working on other high-priority campaigns
- No preemptable tasks (all >90% complete or preempted ≥2 times)

**Solutions**:

- Wait for running tasks to complete
- Add more agents to the project
- Manually pause lower-priority campaigns if truly urgent

### Issue: Tasks Being Preempted Repeatedly

**Expected Behavior**: Tasks should not be preempted more than 2 times

**Investigation**:

- Check task `preemption_count` in database
- Review preemption logs for patterns
- Verify preemptability logic is working correctly

### Issue: Deferred Campaigns Never Running

**Expected Behavior**: Deferred campaigns run when capacity available

**Investigation**:

- Check if higher-priority campaigns exist continuously
- Verify agents are available and not all assigned
- Review campaign project assignments

## API Integration

### Setting Priority via API

```http
POST /campaigns
{
  "campaign": {
    "name": "Urgent Analysis",
    "hash_list_id": 123,
    "priority": "high"
  }
}
```

**Response (unauthorized)**:

```json
{
  "error": "You are not authorized to set high priority"
}
```

### Checking Campaign Status

```http
GET /campaigns/{id}
{
  "id": 123,
  "name": "Urgent Analysis",
  "priority": "high",
  "paused": false,
  "current_eta": "2026-01-13T10:30:00Z"
}
```

## Further Reading

- [System Tests Guide](testing/system-tests-guide.md)
- [API Documentation](api-reference-agent-auth.md)
- [Task Assignment Algorithm](../app/services/task_assignment_service.rb)
- [Preemption Service](../app/services/task_preemption_service.rb)
- [Campaign Priority Rebalance Job](../app/jobs/campaign_priority_rebalance_job.rb)
