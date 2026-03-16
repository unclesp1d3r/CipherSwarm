# Campaign Management Guide

This guide covers creating, monitoring, and managing campaigns in CipherSwarm v2.

---

## Table of Contents

- [Campaign Basics](#campaign-basics)
- [Creating Campaigns](#creating-campaigns)
- [Adding Attacks](#adding-attacks)
- [Campaign Progress Monitoring](#campaign-progress-monitoring)
- [Managing Running Campaigns](#managing-running-campaigns)
- [Campaign Quarantine](#campaign-quarantine)
- [Campaign Actions](#campaign-actions)
- [Priority-Based Execution](#priority-based-execution)
- [Best Practices](#best-practices)

---

## Campaign Basics

A **Campaign** is the top-level unit of work in CipherSwarm. Each campaign targets a single hash list and contains one or more attacks that are executed in priority order.

### Campaign States

Campaigns progress through the following states:

| State         | Description                                        | Badge Color |
| ------------- | -------------------------------------------------- | ----------- |
| **Pending**   | Created but no attacks have started                | Gray        |
| **Running**   | One or more attacks are actively being processed   | Purple      |
| **Paused**    | Temporarily stopped by user or priority preemption | Yellow      |
| **Completed** | All attacks finished successfully                  | Green       |
| **Failed**    | One or more attacks encountered errors             | Red         |

**Note:** Campaigns can also be flagged as **Quarantined** when agents encounter unrecoverable errors (e.g., hash format mismatches, invalid hash types). Quarantine is a separate flag that can occur alongside other states. See [Campaign Quarantine](#campaign-quarantine) for details.

### Campaign Hierarchy

```
Campaign
  |
  +-- Attack 1 (Dictionary)
  |     +-- Task 1.1 (assigned to Agent A)
  |     +-- Task 1.2 (assigned to Agent B)
  |
  +-- Attack 2 (Mask)
  |     +-- Task 2.1 (assigned to Agent A)
  |
  +-- Attack 3 (Brute Force)
        +-- Task 3.1 (pending)
```

Attacks within a campaign are executed based on their configured priority. Each attack is subdivided into tasks that are distributed across available agents.

---

## Creating Campaigns

### Step-by-Step

1. Navigate to **Campaigns** in the top menu

2. Click **New Campaign**

3. Fill in the required fields:

   - **Name**: A descriptive name for the campaign
     - Use clear naming conventions (e.g., "2026-Q1-Audit", "Client-Alpha-NTLM")
     - Names should be unique within a project
   - **Hash List**: Select an existing hash list or create a new one
   - **Priority**: Set the execution priority level

4. Optionally add a description

5. Click **Create Campaign**

### Priority Levels

CipherSwarm uses a priority system to manage campaign execution order:

| Priority     | Value | Use Case                                           |
| ------------ | ----- | -------------------------------------------------- |
| **Deferred** | -1    | Low-priority background work                       |
| **Normal**   | 0     | Standard operations (default)                      |
| **High**     | 2     | Time-sensitive campaigns requiring immediate focus |

When a higher-priority campaign needs resources, the system uses priority-based task preemption: running tasks belonging to lower-priority campaigns are transitioned back to pending state, freeing agents to pick up higher-priority work. Preemption is triggered asynchronously via `CampaignPriorityRebalanceJob` when a campaign's priority is raised.

### Project Assignment

Campaigns are automatically assigned to your currently selected project. Ensure you have the correct project selected before creating a campaign.

---

## Adding Attacks

After creating a campaign, add one or more attacks to define how the hashes will be cracked.

### From the Campaign Page

1. Open your campaign
2. Click **New Attack**
3. Select the attack type:
   - **Dictionary** - Use wordlists with optional rules
   - **Mask** - Pattern-based attack using mask syntax
   - **Brute Force** - Exhaustive search with character sets
   - **Hybrid** - Combined dictionary + mask approaches
4. Configure the attack parameters
5. Review the keyspace estimate
6. Click **Create Attack**

For detailed configuration of each attack type, see [Attack Configuration](attack-configuration.md).

### Attack Ordering

Attacks within a campaign run in priority order. You can reorder attacks to control execution sequence:

- Use the move up/down buttons on each attack row
- Higher-positioned attacks run first
- Completed attacks are skipped automatically

---

## Campaign Progress Monitoring

CipherSwarm V2 introduces enhanced campaign progress visualization with real-time updates.

### Attack Stepper

The attack stepper is a visual indicator at the top of the campaign page showing the progression through configured attacks:

```
[1. Dictionary] -----> [2. Mask] -----> [3. Brute Force]
   (completed)         (running)          (pending)
```

- **Completed** attacks show a checkmark
- **Running** attacks are highlighted with the active indicator
- **Pending** attacks are dimmed
- **Failed** attacks show an error indicator

### Progress Bars and ETA Display

Each attack shows:

- **Progress Bar**: Visual completion percentage based on keyspace processed
- **Percentage**: Exact numeric completion (e.g., "67.3%")
- **ETA**: Estimated time to completion based on current hash rate
- **Speed**: Current cracking speed (e.g., "1.2 GH/s")

The campaign-level progress bar aggregates all attacks to show overall completion.

### Recent Cracks Feed

A live feed appears on the campaign page showing recently cracked hashes:

- Displays the plaintext value and timestamp
- Updates in real time via Turbo Streams
- Shows which attack cracked each hash
- Rate-limited to prevent notification overload

### Campaign Error Log

If attacks encounter errors, they are displayed in the campaign error section:

- Error messages from failed tasks
- Agent-specific error details
- Timestamps for error correlation
- Links to affected tasks for further investigation

### Real-Time Updates

All campaign data updates automatically via Turbo Streams:

- No manual page refresh needed
- Progress bars update continuously
- State changes (running, paused, completed) reflect immediately
- New cracks appear in the feed as they happen

---

## Managing Running Campaigns

### Pausing a Campaign

To temporarily stop a campaign:

1. Open the campaign
2. Click **Pause**
3. All running tasks will be paused
4. Agents will release their current tasks
5. The campaign state changes to **Paused**

Paused campaigns retain their progress. No work is lost.

### Resuming a Campaign

To restart a paused campaign:

1. Open the paused campaign
2. Click **Resume**
3. Tasks will be reassigned to available agents
4. Processing continues from where it stopped

### Stopping a Campaign

To permanently stop a campaign:

1. Open the campaign
2. Click **Stop**
3. Confirm the action
4. All active tasks are cancelled
5. The campaign moves to a terminal state

Stopped campaigns cannot be resumed. To re-run, create a new campaign with the same configuration.

### Editing a Campaign

You can edit campaign details while it is running:

- **Name** and **Description**: Can be changed at any time
- **Priority**: Raising a campaign's priority enqueues a rebalance job that may trigger task preemption for lower-priority campaigns. Lowering priority has no immediate effect; the lowered campaign's tasks continue running until they complete or are preempted by higher-priority campaigns during the normal periodic rebalancing cycle.
- **Attacks**: Adding new attacks to a running campaign is supported
- **Editing running attacks**: Modifying a running or completed attack resets it to pending state. A confirmation dialog warns about this behavior.

**Troubleshooting Stalled Campaigns:**

If a campaign stops making progress:

1. Check if the campaign is quarantined (see [Campaign Quarantine](#campaign-quarantine))
2. Review the campaign error log for task failures
3. Verify agents are online and accepting tasks
4. Check agent compatibility with the hash type

---

## Campaign Quarantine

CipherSwarm automatically quarantines campaigns when agents report unrecoverable errors that prevent task execution. Quarantined campaigns are excluded from task assignment to prevent agents from repeatedly encountering the same error.

### What is Quarantine?

Quarantine is an automatic safety mechanism that flags campaigns with fatal configuration or data errors. When a campaign is quarantined:

- Agents will not be assigned tasks from the quarantined campaign
- The campaign retains its current state (running, paused, etc.) but cannot make progress
- A clear error message explains why the campaign was quarantined

### Quarantine Triggers

Campaigns are automatically quarantined when agents encounter certain unrecoverable errors:

| Error Type                    | Description                                    | Example Causes                                      |
| ----------------------------- | ---------------------------------------------- | --------------------------------------------------- |
| **Token length exception**    | Hash format does not match the selected type   | NTLM hashes in an MD5 hash list                     |
| **No hashes loaded**          | Hash file is empty or unreadable               | Corrupted file, wrong encoding, empty file          |
| **Hash format mismatch**      | Hashes cannot be parsed by hashcat             | Mixed hash types, invalid characters, wrong format  |
| **Incompatible attack params**| Attack configuration incompatible with hash type | Mask too short/long, invalid charset configuration |

These errors are identified by structured error metadata reported by agents, not by parsing error message text.

### Identifying Quarantined Campaigns

**In the Campaign Index:**

- A red **"Quarantined"** badge appears next to the campaign name
- Use the **Quarantined** filter button in the toolbar to show only quarantined campaigns
- The **All** filter button returns to the unfiltered view

**On the Campaign Show Page:**

- A dismissible alert banner appears at the top displaying the quarantine reason
- Example: "Campaign Quarantined — Token length exception (hash length: 32, expected: 16)"
- Administrators see a **Clear Quarantine** button in the alert

### Clearing Quarantine

Quarantine is designed to be cleared automatically when you fix the underlying problem.

**Automatic Clearing:**

Quarantine is automatically cleared when you:

- Update the hash list's **hash type** to match the actual hash format
- Replace the hash list **file** with a corrected version
- Modify **attack parameters** that were causing configuration errors (e.g., mask length, charsets, wordlist references)

The system detects these changes and removes the quarantine flag immediately.

**Manual Clearing (Admin Only):**

Administrators can manually clear quarantine from the campaign show page:

1. Click **Clear Quarantine** in the alert banner
2. Confirm the action
3. The quarantine flag is removed

**Important:** Manual clearing is only available to administrators. If you manually clear quarantine without fixing the underlying issue, the campaign will be immediately re-quarantined when the next agent attempts a task.

### Best Practices

- **Fix before clearing**: Always correct the hash list or attack configuration before clearing quarantine
- **Check the error message**: The quarantine reason tells you exactly what needs to be fixed
- **Verify hash format**: Use a hash identifier tool to confirm your hash type matches the hash list setting
- **Test with a small subset**: If unsure, test the configuration with a small hash list first
- **Re-upload clean files**: If the hash file is corrupted, re-export from your source system

---

## Campaign Actions

### Archiving Completed Campaigns

After a campaign is complete:

1. Open the completed campaign
2. Click **Archive**
3. The campaign moves to the archived section
4. Archived campaigns are read-only but retain all data and results

### Exporting Campaign Configuration

To save a campaign's configuration for reuse:

1. Open the campaign
2. Click **Export**
3. Choose the export format (JSON)
4. The configuration file downloads to your browser

This exports attack configurations and settings but not hash data or results.

### Deleting Campaigns

To permanently remove a campaign:

1. Open the campaign
2. Click **Delete**
3. Confirm the deletion
4. The campaign and all associated data are removed

Deleted campaigns use soft delete and can potentially be recovered by an administrator.

---

## Priority-Based Execution

### How Priorities Work

CipherSwarm's priority system uses both immediate (event-driven) and periodic (time-driven) task rebalancing to ensure that the most important work runs first:

**Event-Driven Rebalancing:**

- When you increase a campaign's priority, a `CampaignPriorityRebalanceJob` is enqueued asynchronously
- The job preempts running tasks belonging to lower-priority campaigns, transitioning them back to pending state
- Freed agents then pick up higher-priority work on their next task request
- This happens shortly after you save the priority change (asynchronous, not inline)

**Periodic Rebalancing:**

- The system performs periodic checks to ensure optimal task distribution over time
- Lowering a campaign's priority does not trigger immediate preemption
- The system will rebalance affected campaigns during the next periodic check
- This maintains system stability while ensuring efficient resource allocation

**Behavior Summary:**

1. When a campaign's priority is raised, the system enqueues a rebalance job
2. The rebalance job preempts running tasks from lower-priority campaigns (transitioning them to pending)
3. Freed agents pick up higher-priority tasks on their next task request
4. When the high-priority campaign completes, pending tasks from lower-priority campaigns become eligible for assignment again

### Example Priority Scenario

```
Time 0: Campaign A (normal) starts, agents working on its tasks
Time 1: Campaign B (high) created and started
        -> Rebalance job preempts Campaign A's running tasks to pending
        -> Agents pick up Campaign B's tasks on next request
Time 2: Campaign B completes
        -> Campaign A's pending tasks become eligible for assignment
        -> Agents pick up Campaign A's tasks again
```

### Priority Considerations

- Only campaigns within the same project interact via priority
- Raising a campaign's priority enqueues an asynchronous rebalance job that triggers task preemption
- Lowering priority has no immediate effect; the campaign's tasks continue running until completed or preempted
- Lower-priority running tasks are preempted (transitioned to pending) when you raise a campaign's priority
- This is intended behavior to ensure urgent campaigns get resources quickly
- Agents can only work on one task at a time
- Multiple campaigns at the same priority level run concurrently

---

## Best Practices

### Campaign Organization

- **Use descriptive names** that include dates, clients, or hash types
- **Group related hashes** into a single campaign rather than creating many small campaigns
- **Set appropriate priorities** - reserve high priorities for truly urgent work

### Attack Strategy

- **Start with dictionary attacks** using common wordlists (fastest results)
- **Follow with rule-based attacks** for mutation-based cracking
- **Use mask attacks** when you know password patterns
- **Save brute force** for last (slowest but most thorough)
- See [Attack Configuration](attack-configuration.md) for detailed guidance

### Resource Allocation

- **Monitor agent utilization** to ensure even work distribution
- **Avoid competing high-priority campaigns** that fight for agents
- **Schedule deferred campaigns** for off-hours when agents are idle

### Monitoring

- **Check progress regularly** using the campaign dashboard
- **Review error logs** if progress stalls
- **Watch the ETA** - if it increases instead of decreasing, investigate agent issues
- **Use the recent cracks feed** to verify attacks are finding results

### Related Guides

- [Attack Configuration](attack-configuration.md) - Detailed attack setup
- [Resource Management](resource-management.md) - Managing wordlists and rules
- [Understanding Results](understanding-results.md) - Interpreting cracking results
- [Performance Optimization](optimization.md) - Tuning for maximum throughput
