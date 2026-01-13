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
- **Dynamic Rebalancing**: Background job periodically checks for preemption opportunities
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
- **UpdateStatusJob**: Background rebalancing for high-priority attacks
- **Task Model**: Preemption tracking and preemptability checks

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

1. Running task receives `abandon` event
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

```json
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

```json
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
- [API Documentation](/api-docs)
- [Task Assignment Algorithm](../app/services/task_assignment_service.rb)
- [Preemption Service](../app/services/task_preemption_service.rb)
