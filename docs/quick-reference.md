# CipherSwarm Quick Reference

## Commands

| Command                       | Description                 |
| ----------------------------- | --------------------------- |
| `just dev`                    | Start development server    |
| `just test`                   | Run all tests with coverage |
| `just test-file spec/path.rb` | Run specific test           |
| `just check`                  | Lint + security checks      |
| `just format`                 | Auto-format code            |
| `just db-migrate`             | Run migrations              |
| `just db-rollback`            | Rollback migration          |
| `just console`                | Rails console               |
| `just docs-api`               | Generate API docs           |

## File Locations

| What            | Where                            |
| --------------- | -------------------------------- |
| Models          | `app/models/`                    |
| API Controllers | `app/controllers/api/v1/client/` |
| Services        | `app/services/`                  |
| Jobs            | `app/jobs/`                      |
| Components      | `app/components/`                |
| Factories       | `spec/factories/`                |
| System Tests    | `spec/system/`                   |
| API Tests       | `spec/requests/`                 |

## Domain Hierarchy

```
Project → Campaign → Attack → Task → Agent
           ↓
        HashList → HashItem
```

## State Machines

### Agent

`pending → active → benchmarked → error/stopped`

### Attack

`pending → running → completed/exhausted/failed/paused`

### Task

`pending → running → completed/exhausted/failed/paused`

## API Endpoints

| Method | Endpoint                        | Purpose            |
| ------ | ------------------------------- | ------------------ |
| GET    | `/authenticate`                 | Verify token       |
| GET    | `/configuration`                | Agent config       |
| GET    | `/agents/{id}`                  | Agent details      |
| PUT    | `/agents/{id}`                  | Update agent       |
| POST   | `/agents/{id}/heartbeat`        | Keep alive         |
| POST   | `/agents/{id}/submit_benchmark` | Submit benchmarks  |
| POST   | `/agents/{id}/submit_error`     | Report error       |
| POST   | `/agents/{id}/shutdown`         | Shutdown           |
| GET    | `/tasks/new`                    | Get new task       |
| POST   | `/tasks/{id}/accept_task`       | Accept task        |
| POST   | `/tasks/{id}/submit_status`     | Update progress    |
| POST   | `/tasks/{id}/submit_crack`      | Submit crack       |
| POST   | `/tasks/{id}/exhausted`         | Mark complete      |
| POST   | `/tasks/{id}/abandon`           | Abandon task       |
| GET    | `/tasks/{id}/get_zaps`          | Get cracked hashes |
| GET    | `/attacks/{id}`                 | Attack details     |
| GET    | `/attacks/{id}/hash_list`       | Download hashes    |

## Authentication

```http
Authorization: Bearer <24-char-token>
```

## Campaign Priorities

| Priority       | Value | Effect                |
| -------------- | ----- | --------------------- |
| flash_override | 5     | Highest, preempts all |
| flash          | 4     | Very high             |
| immediate      | 3     | High                  |
| urgent         | 2     | Above normal          |
| priority       | 1     | Normal                |
| routine        | 0     | Default               |
| deferred       | -1    | Lowest                |

## Attack Modes

| Mode              | Hashcat | Description           |
| ----------------- | ------- | --------------------- |
| dictionary        | 0       | Wordlist attack       |
| mask              | 3       | Brute force with mask |
| hybrid_dictionary | 6       | Wordlist + mask       |
| hybrid_mask       | 7       | Mask + wordlist       |

## Logging Prefixes

```
[APIRequest]      - API requests
[APIError]        - API errors
[AgentLifecycle]  - Agent state changes
[BroadcastError]  - WebSocket errors
[TaskPreemption]  - Task preemption
[JobDiscarded]    - Failed jobs
```

## Testing

```bash
# All tests
COVERAGE=true bundle exec rspec

# Single file
bundle exec rspec spec/models/task_spec.rb

# Single test (line 42)
bundle exec rspec spec/models/task_spec.rb:42

# System tests (visible browser)
HEADLESS=false bundle exec rspec spec/system

# API tests only
bundle exec rspec spec/requests
```

## FactoryBot

```ruby
# Basic
create(:task)
build(:agent)

# With traits
create(:agent, :benchmarked)
create(:task, :running)
create(:campaign, :high_priority)

# With overrides
create(:task, state: "completed", agent: my_agent)
```

## Common Patterns

### Service Object

```ruby
class MyService
  def initialize(model)
    @model = model
  end

  def call
    # Business logic
  end
end

# Usage
MyService.new(model).call
```

### Controller Authorization

```ruby
class MyController < ApplicationController
  load_and_authorize_resource

  def index
    @items = @items.page(params[:page])
  end
end
```

### API Response

```ruby
# Success with body
render json: @task, status: :ok

# Success no body
head :no_content

# Error
render json: { error: "Message" }, status: :unprocessable_entity
```

### Transaction

```ruby
Model.transaction do
  record.lock!
  record.update!(field: value)
end
```

## URLs

| Environment | URL                            |
| ----------- | ------------------------------ |
| Development | http://localhost:3000          |
| API Docs    | http://localhost:3000/api-docs |
| Admin       | http://localhost:3000/admin    |
| Sidekiq     | http://localhost:3000/sidekiq  |

## Key Files

| File                             | Purpose               |
| -------------------------------- | --------------------- |
| `AGENTS.md`                      | Developer conventions |
| `justfile`                       | Task runner commands  |
| `config/routes.rb`               | Application routes    |
| `app/models/ability.rb`          | Authorization rules   |
| `spec/swagger_helper.rb`         | API doc config        |
| `config/initializers/sidekiq.rb` | Job config            |
