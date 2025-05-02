
# Phase 4: Task Distribution System

This phase defines how CipherSwarm creates, assigns, tracks, and recovers password cracking tasks. Tasks are dispatched to agents using keyspace slicing, resource validation, and progress tracking. The system must support all Hashcat attack modes and operate in a fault-tolerant, load-balanced way.

---

## 🧾 Task Management

### Core Implementation

- [ ] Task creation:
  - Triggered from campaign or attack activation
  - Includes attack ID, hash list, resource bundle
- [ ] Assignment logic:
  - Selects agent(s) based on availability and capability
  - Marks task state as `assigned` with timestamp
- [ ] Progress tracking:
  - Updated via heartbeat or progress endpoint
  - Includes `keyspace_processed`, `percent_complete`, `current_speed`
- [ ] Result collection:
  - Results uploaded in JSON format:
    ```json
    {
      "hash": "<hash>",
      "plaintext": "<cracked_value>",
      "salt": "<salt>",
      "time_cracked": "<timestamp>"
    }
    ```
- [ ] Error handling:
  - Task can enter `error` state with reason
  - Logs associated agent and failure context

---

### Distribution Logic

- [ ] Keyspace Division:
  - Hashcat-compatible `--skip` and `--limit` slicing
  - Based on benchmarked agent throughput
- [ ] Load Balancing:
  - Prioritize agents with higher capacity
  - Consider historical performance (GPU hash/sec)
- [ ] Priority System:
  - Tasks tagged with priority level (`low`, `normal`, `high`)
  - Campaign-based override for urgent ops
- [ ] Failover Handling:
  - If agent fails task, requeue to next best match
  - N retries before task marked `aborted`
- [ ] Recovery Procedures:
  - Resume in-progress tasks from saved progress if agent restarts
  - Option to manually reassign stuck tasks

---

## 💥 Attack System

### Supported Attack Modes

- [x] Dictionary
- [x] Mask
- [x] Hybrid (Dict+Mask)
- [x] Rule-based
- [x] Combined (multi-resource)

Each attack must validate required resources:

| Attack Mode | Required Resources            |
|-------------|-------------------------------|
| Dictionary  | Wordlist                      |
| Mask        | Mask pattern                  |
| Hybrid      | Wordlist + Mask               |
| Rule-based  | Wordlist + Rule               |
| Combined    | Wordlist + Rule + Mask        |

### Resource Handling

- [ ] Dependency Checking:
  - Validate all resources exist in MinIO before scheduling
- [ ] Resource Validation:
  - MD5/size check before dispatch
  - Agents perform local integrity validation
- [ ] Distribution Management:
  - Resources cached locally on agents
  - Presigned URL with agent/token binding
- [ ] Performance Optimization:
  - Adjust task slice size based on agent benchmark
  - Tune workload profile
- [ ] Error Recovery:
  - Track agent health and isolate error-prone ones
  - Automatic task requeue if `heartbeat_lost`

---

## 🧠 Notes for Cursor

- All tasks must be explicitly associated with one `agent_id` and one `attack_id`
- Tasks must be created with a bounded `keyspace_range`
- Implement task states: `queued`, `assigned`, `in_progress`, `error`, `complete`, `aborted`, `expired`
- If agent heartbeat is missed for >60s, task should be marked `stale`
- Redis can be used for real-time dashboard updates of progress and agent stats
- Agent should post `result_json` in a single upload unless split mode is activated
