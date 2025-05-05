# CipherSwarm: Skirmish Implementation Guide – Progress, Compatibility, and Task Assignment

This guide documents key algorithms from the legacy CipherSwarm system that must be reimplemented or updated for the new FastAPI + PostgreSQL backend. It provides functional requirements and implementation notes for Skirmish.

---

## 1. Agent Benchmark Compatibility

### ✅ Functionality

Determine whether an agent is compatible with a given hash type.

### 💡 What Are Hashcat Benchmarks?

Hashcat benchmarks are performance tests that measure how many hashes per second an agent's hardware can process for each supported hash type. These benchmarks:

* Are collected during agent registration or re-benchmarking
* Indicate agent capability for each hash type
* Are used to **determine eligibility for specific attacks**
* Provide **relative performance estimates** that can be used for **load balancing**

This allows CipherSwarm to distribute work intelligently, avoiding weaker agents for resource-heavy tasks and splitting work proportionally across stronger ones.

### 💡 Implementation

Agents store benchmark results in the format:

```json
{
  "hash_type_id": <int>,
  "speed": <float>  // hashes per second
}
```

### 🔧 Method Signature

```python
def can_handle_hash_type(agent: Agent, hash_type_id: int) -> bool:
    return hash_type_id in agent.benchmark_map
```

Benchmarks should be stored in a DB field or table, indexed by hash type. Agents without benchmark data for a hash type are ineligible.

---

## 2. State Machines (Campaign → Attack → Task)

### ✅ Functionality

Each object in the hierarchy calculates its completion based on its children.

* `Task`: complete if progress is 100% or a result has been submitted
* `Attack`: complete if all Tasks are complete
* `Campaign`: complete if all Attacks are complete

### 🔧 Method Signatures

```python
def task_is_complete(task: Task) -> bool:
    return task.progress_percent == 100 or task.result_submitted

def attack_is_complete(attack: Attack) -> bool:
    return all(task_is_complete(t) for t in attack.tasks)

def campaign_is_complete(campaign: Campaign) -> bool:
    return all(attack_is_complete(a) for a in campaign.attacks)
```

Each level should also store a calculated progress percentage (see next section).

---

## 3. Progress Calculation (Percent-Based)

### ✅ Functionality

Higher-level progress is calculated as the average of lower-level progress.

### 🔧 Method Signatures

```python
def attack_progress(attack: Attack) -> float:
    if not attack.tasks:
        return 0.0
    return sum(t.progress_percent for t in attack.tasks) / len(attack.tasks)

def campaign_progress(campaign: Campaign) -> float:
    if not campaign.attacks:
        return 0.0
    return sum(attack_progress(a) for a in campaign.attacks) / len(campaign.attacks)
```

---

## 3B. 🔍 Keyspace-Weighted Progress Calculation (Enhanced)

### ✅ Why Weight by Keyspace?

Not all tasks are equal — some take longer than others due to larger keyspaces. If we just average `progress_percent`, a small task at 100% can skew results.

Instead, weight each task’s progress by its total keyspace:

```python
def attack_progress(attack: Attack) -> float:
    total_keyspace = sum(t.keyspace_total for t in attack.tasks)
    if total_keyspace == 0:
        return 0.0
    weighted_sum = sum((t.progress_percent / 100.0) * t.keyspace_total for t in attack.tasks)
    return (weighted_sum / total_keyspace) * 100.0
```

Campaign progress would then be calculated from weighted attack progress, or further weighted by total attack keyspace.

---

## 4. Task Assignment Algorithm

### ✅ Functionality

Assigns pending tasks to available agents based on hash type compatibility.

### 🔧 Method Signature

```python
def assign_task_to_agent(agent: Agent) -> Optional[Task]:
    for task in get_pending_tasks():
        if can_handle_hash_type(agent, task.attack.hash_type_id):
            return task
    return None
```

### 🔒 Requirements

* Task must be in `pending` state
* Agent must have benchmark support for the task’s hash type
* Only one active task per agent at a time

---

## 5. Hash Crack Result Aggregation

### ✅ Functionality

Track cracked hash counts for UI and export.

### 🔧 Aggregates

* `hash_list.hash_items.count()`
* `hash_list.hash_items.filter(cracked=True).count()`
* `campaign.total_cracked` = sum of cracked items across associated hash lists

Use indexes on `HashItem.cracked` for performance.

---

## 6. Edge Cases

* Agents without benchmark data should be flagged and not assigned work
* Tasks with 0 `keyspace_total` should be logged and excluded
* Cracked hashes submitted twice should be deduplicated
* Failed tasks should trigger retries or manual reassignment

---

## ✅ Implementation Order

1. [ ] Agent benchmark ingestion & capability check
2. [ ] Task assignment endpoint & logic
3. [ ] Task completion detection
4. [ ] Attack & campaign progress calculation
5. [ ] Campaign & attack completion transitions
6. [ ] Hash crack aggregation

---

This guide is intended to serve as a reference and contract for implementing CipherSwarm's orchestration logic in a stateless API model using FastAPI and SQLAlchemy.
