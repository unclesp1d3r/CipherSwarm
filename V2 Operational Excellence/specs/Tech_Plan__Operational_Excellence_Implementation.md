# Tech Plan: Operational Excellence Implementation

This technical plan defines the implementation approach for the CipherSwarm V2 Operational Excellence Epic. The plan extends the existing Rails 8 + Hotwire + ViewComponent architecture without introducing new frameworks, ensuring maintainability for a solo part-time developer.

## Architectural Approach

### 1. Real-Time Updates Strategy

**Decision: Targeted Turbo Stream Broadcasts**

Replace the current `broadcasts_refreshes` pattern with targeted Turbo Stream broadcasts to avoid disrupting user interactions (e.g., form inputs, scrolling).

**Current Pattern:**

```ruby
# app/models/agent.rb
broadcasts_refreshes unless Rails.env.test?
```

**New Pattern:**

```ruby
# app/models/agent.rb
after_update_commit :broadcast_status_update, if: :status_changed?

def broadcast_status_update
  broadcast_replace_to self,
    target: "agent_status_#{id}",
    partial: "agents/status_card",
    locals: { agent: self }
rescue => e
  Rails.logger.error("Failed to broadcast agent status update: #{e.message}")
  Rails.logger.error(e.backtrace.join("\n"))
end
```

**Scoping Strategy:**

- **Agent List**: Broadcast individual agent status cards (not entire table)
- **Agent Detail**: Broadcast specific tabs (Overview, Errors) independently
- **Campaign Detail**: Broadcast attack progress bars individually
- **Task Detail**: Broadcast task status section only

**Trade-offs:**

- ✅ Avoids disrupting user interactions
- ✅ Reduces bandwidth (smaller updates)
- ✅ More granular control over updates
- ❌ More manual broadcast management
- ❌ Requires careful DOM element targeting

**Implementation Notes:**

- Use `dom_id` helper for consistent target IDs
- Wrap broadcastable sections in divs with unique IDs
- Test broadcasts don't interfere with Stimulus controllers

---

### 2. Structured Logging with Lograge

**Decision: Add Lograge for JSON-formatted request logging**

Implement structured logging to improve debuggability and enable log parsing/analysis.

**Configuration:**

```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      user_id: event.payload[:user_id],
      agent_id: event.payload[:agent_id],
      ip: event.payload[:ip],
      request_id: event.payload[:request_id]
    }
  end
end
```

**Logging Levels:**

- **INFO**: Agent lifecycle events (connect, disconnect, heartbeat)
- **INFO**: Task state transitions (accepted, completed, failed)
- **INFO**: API requests/responses with timing
- **WARN**: Performance issues (slow queries, high memory)
- **ERROR**: Application errors with context
- **FATAL**: Critical failures (database connection lost)

**Structured Log Format:**

```json
{
  "method": "GET",
  "path": "/agents/1",
  "status": 200,
  "duration": 45.2,
  "user_id": 123,
  "timestamp": "2024-01-07T10:30:00Z"
}
```

**Trade-offs:**

- ✅ Easy to parse and analyze
- ✅ Consistent format across application
- ✅ Integrates with log aggregation tools
- ❌ Slightly more verbose logs
- ❌ One additional gem dependency

---

### 3. Caching Strategy

**Decision: Rails.cache with TTL-based expiration**

Use Rails.cache for expensive queries and health checks to balance performance and freshness.

**Caching Targets:**

- **System Health Checks**: 1-minute TTL
- **Agent Metrics**: 30-second TTL (updated on status broadcast)
- **Campaign ETAs**: 1-minute TTL
- **Recent Cracks**: 1-minute TTL

**Cache Keys:**

```ruby
# System health
Rails.cache.fetch("system_health", expires_in: 1.minute) { check_services }

# Agent metrics
Rails.cache.fetch("agent_metrics_#{agent.id}", expires_in: 30.seconds) { calculate_metrics }

# Campaign ETA
Rails.cache.fetch("#{campaign.cache_key_with_version}/eta", expires_in: 1.minute) { calculate_eta }
```

**Cache Invalidation:**

- Automatic expiration via TTL
- Manual invalidation on critical updates (e.g., `Rails.cache.delete("agent_metrics_#{id}")`)
- Use `cache_key_with_version` for model-based caching

**Trade-offs:**

- ✅ Reduces database load
- ✅ Improves page load times
- ✅ Simple TTL-based expiration
- ❌ Slight staleness (acceptable for monitoring)
- ❌ Cache warming on first request

---

### 4. UI Loading States

**Decision: Hybrid approach (skeleton screens + spinners)**

Use skeleton screens for major components (agent list, campaign list) and spinners for smaller interactions (modals, forms).

**Skeleton Screens:**

- Agent list loading state
- Campaign list loading state
- System health dashboard loading state

**Spinners:**

- Modal dialogs (error details, task actions)
- Form submissions
- Button actions (cancel, retry, reassign)

**Implementation:**

- Create `SkeletonLoaderComponent` for reusable skeleton patterns
- Use Bootstrap spinner component for simple loading states
- Turbo Frame loading states with `turbo:before-fetch-request` event

**Trade-offs:**

- ✅ Better perceived performance (skeletons)
- ✅ Simple implementation (spinners)
- ✅ Balanced complexity
- ❌ Need to maintain skeleton templates

---

### 5. Tabbed Interface Implementation

**Decision: Stimulus controller with hidden divs**

Implement tabbed agent detail page using Stimulus controller for fast tab switching without network requests.

**Implementation:**

```javascript
// app/javascript/controllers/tabs_controller.js
import {
    Controller
} from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["tab", "panel"];

    switch (event) {
        const tabName = event.currentTarget.dataset.tabName;

        // Hide all panels
        this.panelTargets.forEach((panel) => panel.classList.add("d-none"));

        // Show selected panel
        const selectedPanel = this.panelTargets.find(
            (panel) => panel.dataset.tabPanel === tabName,
        );
        selectedPanel.classList.remove("d-none");

        // Update active tab styling
        this.tabTargets.forEach((tab) => tab.classList.remove("active"));
        event.currentTarget.classList.add("active");
    }
}
```

**Trade-offs:**

- ✅ Fast tab switching (no network request)
- ✅ All content loaded upfront (good for small datasets)
- ✅ Simple Stimulus controller
- ❌ Larger initial page load
- ❌ No URL updates (not bookmarkable)

---

### 6. Toast Notifications

**Decision: Stimulus controller for Bootstrap toast component**

Implement toast notifications using Stimulus controller to trigger Bootstrap 5 toast component.

**Implementation:**

```javascript
// app/javascript/controllers/toast_controller.js
import {
    Controller
} from "@hotwired/stimulus";
import {
    Toast
} from "bootstrap";

export default class extends Controller {
    connect() {
        const toast = new Toast(this.element, {
            autohide: true,
            delay: 5000,
        });
        toast.show();
    }
}
```

**Usage:**

```erb
<div class="toast" data-controller="toast" role="alert">
  <div class="toast-body">
    <%= message %>
  </div>
</div>
```

**Trade-offs:**

- ✅ Native Bootstrap component
- ✅ Auto-dismiss after 5 seconds
- ✅ Can be triggered from Turbo Stream responses
- ❌ Requires Stimulus controller

---

### 7. System Health Monitoring

**Decision: Stateless health checks with Rails.cache**

Implement system health monitoring without database persistence, using Rails.cache for 1-minute TTL.

**Health Check Services:**

- **PostgreSQL**: `ActiveRecord::Base.connection.active?`
- **Redis**: `Redis.current.ping`
- **MinIO**: S3 bucket access check
- **Sidekiq**: Queue stats and worker count

**Implementation:**

```ruby
# app/controllers/system_health_controller.rb
def index
  @health_status = fetch_health_status_with_lock
end

def fetch_health_status_with_lock
  # Use Redis lock to prevent cache stampede
  lock_key = "system_health_check_lock"

  # Try to get cached value first
  cached = Rails.cache.read("system_health")
  return cached if cached

  # Acquire lock to run health checks
  Redis.current.set(lock_key, "locked", nx: true, ex: 10) do
    # Run health checks
    status = {
      postgresql: check_postgresql,
      redis: check_redis,
      minio: check_minio,
      sidekiq: check_sidekiq
    }

    # Cache results for 1 minute
    Rails.cache.write("system_health", status, expires_in: 1.minute)
    status
  end

  # If we couldn't get lock, return cached value or wait briefly and retry
  Rails.cache.read("system_health") || {
    postgresql: { status: :checking },
    redis: { status: :checking },
    minio: { status: :checking },
    sidekiq: { status: :checking }
  }
end

private

def check_postgresql
  start_time = Time.current
  ActiveRecord::Base.connection.execute("SELECT 1")
  latency = ((Time.current - start_time) * 1000).round(2)

  { status: :healthy, latency: latency }
rescue => e
  Rails.logger.error("PostgreSQL health check failed: #{e.message}")
  { status: :unhealthy, error: e.message }
end
```

**Trade-offs:**

- ✅ No database table needed
- ✅ Fast reads (cached)
- ✅ Simple implementation
- ❌ No historical data
- ❌ First request runs checks (cache warming)

---

## Data Model

### 1. Database Schema Changes

**Migration: Add Performance Indexes**

Add indexes to optimize queries for monitoring features.

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_performance_indexes.rb
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Index for recent cracks query
    add_index :hash_items, :cracked_time

    # Index for recent errors query
    add_index :agent_errors, :created_at

    # Index for latest status query
    add_index :hashcat_statuses, :time

    # Composite index for agent task lookup
    add_index :tasks, [:agent_id, :state]
  end
end
```

**Migration: Add Cached Agent Metrics**

Add columns to Agent model for cached performance metrics.

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_cached_metrics_to_agents.rb
class AddCachedMetricsToAgents < ActiveRecord::Migration[8.0]
  def change
    add_column :agents, :current_hash_rate, :decimal, precision: 20, scale: 2
    add_column :agents, :current_temperature, :integer
    add_column :agents, :current_utilization, :integer
    add_column :agents, :metrics_updated_at, :datetime

    add_index :agents, :metrics_updated_at
  end
end
```

---

### 2. Model Extensions

**Agent Model: Cached Metrics**

Add methods to update and retrieve cached performance metrics.

```ruby
# app/models/agent.rb
class Agent < ApplicationRecord
  # ... existing code ...

  def hash_rate_display
    return "—" unless current_hash_rate
    return "0 H/s" if current_hash_rate.zero?
    "#{number_to_human(current_hash_rate, prefix: :si)} H/s"
  end
end
```

**HashcatStatus Model: Update Agent Metrics**

Add callback to update agent metrics when status is created.

```ruby
# app/models/hashcat_status.rb
class HashcatStatus < ApplicationRecord
  belongs_to :task

  after_create_commit :update_agent_metrics

  private

  def update_agent_metrics
    agent = task.agent
    return unless agent
    return unless status == :running

    # Only update if metrics are stale (30 seconds)
    return if agent.metrics_updated_at && agent.metrics_updated_at > 30.seconds.ago

    agent.update_columns(
      current_hash_rate: hash_rate,
      current_temperature: device_temperature,
      current_utilization: device_utilization,
      metrics_updated_at: Time.current
    )
  rescue => e
    Rails.logger.error("Failed to update agent metrics: #{e.message}")
  end
end
```

**Rationale:** HashcatStatus is the source of truth for agent metrics. By updating Agent from HashcatStatus callback, we ensure metrics are updated whenever new status data arrives, avoiding race conditions and stale data.

**Campaign Model: ETA Calculation**

Add methods to calculate campaign estimated finish time (both current and total).

```ruby
# app/models/campaign.rb
class Campaign < ApplicationRecord
  # ... existing code ...

  # Current attack ETA (only running attacks)
  def current_eta
    Rails.cache.fetch("#{cache_key_with_version}/current_eta", expires_in: 1.minute) do
      calculate_current_eta
    end
  end

  # Total campaign ETA (all incomplete attacks)
  def total_eta
    Rails.cache.fetch("#{cache_key_with_version}/total_eta", expires_in: 1.minute) do
      calculate_total_eta
    end
  end

  private

  def calculate_current_eta
    running_attacks = attacks.with_state(:running)
    return nil if running_attacks.empty?

    # Return the maximum ETA of all running attacks
    etas = running_attacks.map(&:estimated_finish_time).compact
    etas.max
  end

  def calculate_total_eta
    incomplete_attacks = attacks.without_states(:completed, :exhausted)
    return nil if incomplete_attacks.empty?

    # Get estimated finish times for running attacks
    running_etas = incomplete_attacks.with_state(:running).map(&:estimated_finish_time).compact
    pending_count = incomplete_attacks.with_state(:pending).count

    # If we have running attacks, convert ETAs to durations (seconds remaining)
    if running_etas.any?
      # Convert Time objects to durations (seconds from now)
      running_durations = running_etas.map { |t| (t - Time.current).to_f }.compact
      avg_duration = running_durations.sum / running_durations.size
      running_max_seconds = running_durations.max.to_f

      # Total = max running duration + estimated time for all pending attacks
      total_seconds = running_max_seconds + (pending_count * avg_duration)
      Time.current + total_seconds.seconds
    else
      nil # Can't estimate without running attacks
    end
  end
end
```

**Rationale:** Showing both current and total ETA gives users a complete picture: "Current attack finishes in 2h, entire campaign finishes in 6h". This manages expectations better than showing only current attack ETA.

**HashList Model: Recent Cracks**

Add method to retrieve recently cracked hashes (last 24 hours).

```ruby
# app/models/hash_list.rb
class HashList < ApplicationRecord
  # ... existing code ...

  def recent_cracks(limit: 100)
    Rails.cache.fetch("#{cache_key_with_version}/recent_cracks", expires_in: 1.minute) do
      hash_items
        .where("cracked_time > ?", 24.hours.ago)
        .order(cracked_time: :desc)
        .limit(limit)
    end
  end

  def recent_cracks_count
    Rails.cache.fetch("#{cache_key_with_version}/recent_cracks_count", expires_in: 1.minute) do
      hash_items.where("cracked_time > ?", 24.hours.ago).count
    end
  end
end
```

---

### 3. State Machine Extensions

**Task Model: Add Retry Event**

Add retry event to Task state machine for proper failed → pending transition.

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  # ... existing code ...

  state_machine :state, initial: :pending do
    # ... existing events ...

    # New retry event for manual task retry
    event :retry do
      transition failed: :pending
    end

    after_transition on: :retry do |task|
      Rails.logger.info("[Task #{task.id}] Agent #{task.agent_id} - Attack #{task.attack_id} - State change: failed -> pending - Task manually retried")
      task.increment!(:retry_count)
      task.update(last_error: nil) # Clear previous error
    end
  end
end
```

**Rationale:** Adding a proper state machine event ensures retry follows the same lifecycle management as other state transitions, triggers appropriate callbacks, and maintains system invariants.

---

### 4. Authorization Rules

**CanCanCan Abilities: Task Management**

Add project-based authorization for task management actions.

```ruby
# app/models/ability.rb
class Ability
  include CanCan::Ability

  def initialize(user)
    # ... existing code ...

    # Task management (project-based)
    can :read, Task, attack: { campaign: { project_id: user.project_ids } }
    can :cancel, Task, attack: { campaign: { project_id: user.project_ids } }
    can :retry, Task, attack: { campaign: { project_id: user.project_ids } }
    can :reassign, Task, attack: { campaign: { project_id: user.project_ids } }
    can :download_results, Task, attack: { campaign: { project_id: user.project_ids } }

    # Admins can manage all tasks
    can :manage, Task if user.admin?
  end
end
```

---

## Component Architecture

### 1. New ViewComponents

**AgentStatusCardComponent**

Displays agent status in list view with real-time updates.

```ruby
# app/components/agent_status_card_component.rb
class AgentStatusCardComponent < ApplicationViewComponent
  option :agent, required: true

  def status_badge_variant
    case agent.state
    when "active" then "success"
    when "offline" then "danger"
    when "pending" then "warning"
    else "secondary"
    end
  end

  def error_count
    agent.agent_errors.where("created_at > ?", 24.hours.ago).count
  end
end
```

**AgentDetailTabsComponent**

Tabbed interface for agent detail page.

```ruby
# app/components/agent_detail_tabs_component.rb
class AgentDetailTabsComponent < ApplicationViewComponent
  option :agent, required: true

  renders_one :overview_tab
  renders_one :errors_tab
  renders_one :configuration_tab
  renders_one :capabilities_tab
end
```

**CampaignProgressComponent**

Progress bar with ETA for campaign attacks.

```ruby
# app/components/campaign_progress_component.rb
class CampaignProgressComponent < ApplicationViewComponent
  option :attack, required: true

  def progress_percentage
    attack.percentage_complete
  end

  def eta_text
    return "Calculating..." unless attack.estimated_finish_time
    "ETA: #{distance_of_time_in_words_to_now(attack.estimated_finish_time)}"
  end
end
```

**ErrorModalComponent**

Modal dialog for displaying error details.

```ruby
# app/components/error_modal_component.rb
class ErrorModalComponent < ApplicationViewComponent
  option :error, required: true
  option :modal_id, required: true

  def severity_badge_variant
    case error.severity
    when "fatal" then "danger"
    when "error" then "danger"
    when "warning" then "warning"
    when "info" then "info"
    else "secondary"
    end
  end
end
```

**SystemHealthCardComponent**

Service status card for system health dashboard.

```ruby
# app/components/system_health_card_component.rb
class SystemHealthCardComponent < ApplicationViewComponent
  option :service_name, required: true
  option :status, required: true
  option :latency, default: proc { nil }
  option :error, default: proc { nil }

  def status_variant
    status == :healthy ? "success" : "danger"
  end

  def status_icon
    status == :healthy ? "check-circle" : "x-circle"
  end
end
```

**TaskActionsComponent**

Action buttons for task management.

```ruby
# app/components/task_actions_component.rb
class TaskActionsComponent < ApplicationViewComponent
  option :task, required: true

  def can_cancel?
    task.pending? || task.running?
  end

  def can_retry?
    task.failed?
  end

  def can_reassign?
    task.pending? || task.failed?
  end
end
```

**SkeletonLoaderComponent**

Loading state placeholder for major components.

```ruby
# app/components/skeleton_loader_component.rb
class SkeletonLoaderComponent < ApplicationViewComponent
  option :type, required: true # :agent_list, :campaign_list, :health_dashboard
  option :count, default: proc { 5 }
end
```

**ToastNotificationComponent**

Toast notification for success/error feedback.

```ruby
# app/components/toast_notification_component.rb
class ToastNotificationComponent < ApplicationViewComponent
  option :message, required: true
  option :variant, default: proc { "success" } # success, danger, warning, info

  def toast_class
    "toast-#{variant}"
  end
end
```

---

### 2. New Stimulus Controllers

**tabs_controller.js**

Manages tabbed interface for agent detail page.

```javascript
// app/javascript/controllers/tabs_controller.js
import {
    Controller
} from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["tab", "panel"];

    connect() {
        // Show first tab by default
        this.showTab(0);
    }

    switch (event) {
        event.preventDefault();
        const index = this.tabTargets.indexOf(event.currentTarget);
        this.showTab(index);
    }

    showTab(index) {
        // Hide all panels
        this.panelTargets.forEach((panel) => {
            panel.classList.add("d-none");
        });

        // Show selected panel
        this.panelTargets[index].classList.remove("d-none");

        // Update active tab
        this.tabTargets.forEach((tab) => {
            tab.classList.remove("active");
        });
        this.tabTargets[index].classList.add("active");
    }
}
```

**toast_controller.js**

Triggers Bootstrap toast notifications.

```javascript
// app/javascript/controllers/toast_controller.js
import {
    Controller
} from "@hotwired/stimulus";
import {
    Toast
} from "bootstrap";

export default class extends Controller {
    static values = {
        autohide: {
            type: Boolean,
            default: true,
        },
        delay: {
            type: Number,
            default: 5000,
        },
    };

    connect() {
        const toast = new Toast(this.element, {
            autohide: this.autohideValue,
            delay: this.delayValue,
        });
        toast.show();

        // Remove from DOM after hidden
        this.element.addEventListener("hidden.bs.toast", () => {
            this.element.remove();
        });
    }
}
```

---

### 3. New Controller Actions

**SystemHealthController**

Displays system health dashboard.

```ruby
# app/controllers/system_health_controller.rb
class SystemHealthController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize! :read, :system_health

    @health_status = fetch_health_status_with_lock
  end

  def fetch_health_status_with_lock
    # Try to get cached value first
    cached = Rails.cache.read("system_health")
    return cached if cached

    # Use Redis lock to prevent cache stampede
    lock_key = "system_health_check_lock"
    lock_acquired = Redis.current.set(lock_key, "locked", nx: true, ex: 10)

    if lock_acquired
      # Run health checks
      status = {
        postgresql: check_postgresql,
        redis: check_redis,
        minio: check_minio,
        sidekiq: check_sidekiq
      }

      # Cache results for 1 minute
      Rails.cache.write("system_health", status, expires_in: 1.minute)

      # Release lock
      Redis.current.del(lock_key)

      status
    else
      # Another request is running checks, wait briefly and return cached value
      sleep 0.1
      Rails.cache.read("system_health") || {
        postgresql: { status: :checking },
        redis: { status: :checking },
        minio: { status: :checking },
        sidekiq: { status: :checking }
      }
    end
  end

  private

  def check_postgresql
    start_time = Time.current
    ActiveRecord::Base.connection.execute("SELECT 1")
    latency = ((Time.current - start_time) * 1000).round(2)

    { status: :healthy, latency: latency }
  rescue => e
    Rails.logger.error("PostgreSQL health check failed: #{e.message}")
    { status: :unhealthy, error: e.message }
  end

  def check_redis
    start_time = Time.current
    Redis.current.ping
    latency = ((Time.current - start_time) * 1000).round(2)

    { status: :healthy, latency: latency }
  rescue => e
    Rails.logger.error("Redis health check failed: #{e.message}")
    { status: :unhealthy, error: e.message }
  end

  def check_minio
    # Check S3 bucket access
    start_time = Time.current
    ActiveStorage::Blob.service.exist?("health_check")
    latency = ((Time.current - start_time) * 1000).round(2)

    { status: :healthy, latency: latency }
  rescue => e
    Rails.logger.error("MinIO health check failed: #{e.message}")
    { status: :unhealthy, error: e.message }
  end

  def check_sidekiq
    stats = Sidekiq::Stats.new

    {
      status: :healthy,
      workers: stats.workers_size,
      queues: stats.queues.size,
      enqueued: stats.enqueued
    }
  rescue => e
    Rails.logger.error("Sidekiq health check failed: #{e.message}")
    { status: :unhealthy, error: e.message }
  end
end
```

**TasksController**

Manages task lifecycle actions.

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource

  def show
    @task = Task.includes(:agent, :attack, :hashcat_statuses).find(params[:id])
  end

  def cancel
    @task = Task.find(params[:id])
    authorize! :cancel, @task

    if @task.cancel
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("task_#{@task.id}", partial: "tasks/task", locals: { task: @task }),
            turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: "Task cancelled", variant: "success" })
          ]
        end
        format.html { redirect_to @task, notice: "Task cancelled" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: "Failed to cancel task", variant: "danger" })
        end
        format.html { redirect_to @task, alert: "Failed to cancel task" }
      end
    end
  end

  def retry
    @task = Task.find(params[:id])
    authorize! :retry, @task

    # Use state machine event for proper transition
    if @task.retry
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("task_#{@task.id}", partial: "tasks/task", locals: { task: @task }),
            turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: "Task queued for retry", variant: "success" })
          ]
        end
        format.html { redirect_to @task, notice: "Task queued for retry" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: "Failed to retry task", variant: "danger" })
        end
        format.html { redirect_to @task, alert: "Failed to retry task" }
      end
    end
  end

  def reassign
    @task = Task.find(params[:id])
    authorize! :reassign, @task

    new_agent = Agent.find(params[:agent_id])

    # Validate agent can handle this task
    unless agent_compatible_with_task?(new_agent, @task)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: "Agent #{new_agent.name} cannot handle this task (incompatible hash type or insufficient performance)", variant: "danger" })
        end
        format.html { redirect_to @task, alert: "Agent incompatible with task" }
      end
      return
    end

    if @task.update(agent: new_agent, state: :pending)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("task_#{@task.id}", partial: "tasks/task", locals: { task: @task }),
            turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: "Task reassigned to #{new_agent.name}", variant: "success" })
          ]
        end
        format.html { redirect_to @task, notice: "Task reassigned" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: "Failed to reassign task", variant: "danger" })
        end
        format.html { redirect_to @task, alert: "Failed to reassign task" }
      end
    end
  end

  def logs
    @task = Task.find(params[:id])
    authorize! :read, @task

    @logs = @task.hashcat_statuses.order(time: :desc).limit(100)
  end

  def download_results
    @task = Task.find(params[:id])
    authorize! :download_results, @task

    # Generate CSV of cracked hashes for this task
    csv_data = generate_results_csv(@task)

    send_data csv_data,
      filename: "task_#{@task.id}_results_#{Time.current.to_i}.csv",
      type: "text/csv"
  end

  private

  def generate_results_csv(task)
    require "csv"

    CSV.generate do |csv|
      csv << ["Hash", "Plaintext", "Cracked At"]

      task.attack.hash_list.hash_items.where.not(cracked_time: nil).find_each do |item|
        csv << [item.hash_value, item.plain_text, item.cracked_time]
      end
    end
  end

  def agent_compatible_with_task?(agent, task)
    hash_type = task.attack.hash_type

    # Check if agent supports this hash type
    return false unless agent.allowed_hash_types.include?(hash_type)

    # Check if agent meets performance threshold
    return false unless agent.meets_performance_threshold?(hash_type)

    # Check if agent has access to task's project
    return false unless agent.project_ids.include?(task.attack.campaign.project_id)

    true
  end
end
```

---

### 4. Integration Points

**Turbo Stream Broadcasts**

Define broadcast targets and partials for real-time updates.

```ruby
# app/models/agent.rb
after_update_commit :broadcast_status_update, if: :should_broadcast_status?

def broadcast_status_update
  broadcast_replace_to self,
    target: "agent_status_#{id}",
    partial: "agents/status_card",
    locals: { agent: self }
end

def should_broadcast_status?
  saved_change_to_state? ||
  saved_change_to_last_seen_at? ||
  saved_change_to_current_hash_rate?
end
```

```ruby
# app/models/attack.rb
after_update_commit :broadcast_progress_update, if: :should_broadcast_progress?

def broadcast_progress_update
  broadcast_replace_to campaign,
    target: "attack_progress_#{id}",
    partial: "campaigns/attack_progress",
    locals: { attack: self }
rescue => e
  Rails.logger.error("Failed to broadcast attack progress update: #{e.message}")
  Rails.logger.error(e.backtrace.join("\n"))
end

def should_broadcast_progress?
  saved_change_to_state? || tasks.any?(&:saved_change_to_state?)
end
```

**Routes**

Add routes for new controllers and actions.

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # ... existing routes ...

  # System Health
  resource :system_health, only: [:index]

  # Tasks
  resources :tasks, only: [:show] do
    member do
      post :cancel
      post :retry
      post :reassign
      get :logs
      get :download_results
    end
  end
end
```

---

### 5. View Structure

**Agent List View**

```erb
<!-- app/views/agents/index.html.erb -->
<div id="agents_list">
  <%= turbo_stream_from "agents" %>

  <div class="row">
    <% @agents.each do |agent| %>
      <div id="<%= dom_id(agent, :status) %>" class="col-md-4 mb-3">
        <%= render AgentStatusCardComponent.new(agent: agent) %>
      </div>
    <% end %>
  </div>
</div>
```

**Agent Detail View with Tabs**

```erb
<!-- app/views/agents/show.html.erb -->
<div data-controller="tabs">
  <ul class="nav nav-tabs" role="tablist">
    <li class="nav-item">
      <a class="nav-link" data-tabs-target="tab" data-action="click->tabs#switch" href="#">Overview</a>
    </li>
    <li class="nav-item">
      <a class="nav-link" data-tabs-target="tab" data-action="click->tabs#switch" href="#">Errors</a>
    </li>
    <li class="nav-item">
      <a class="nav-link" data-tabs-target="tab" data-action="click->tabs#switch" href="#">Configuration</a>
    </li>
    <li class="nav-item">
      <a class="nav-link" data-tabs-target="tab" data-action="click->tabs#switch" href="#">Capabilities</a>
    </li>
  </ul>

  <div class="tab-content">
    <div data-tabs-target="panel" class="tab-pane">
      <div id="<%= dom_id(@agent, :overview_content) %>">
        <%= render "agents/overview_tab", agent: @agent %>
      </div>
    </div>
    <div data-tabs-target="panel" class="tab-pane d-none">
      <div id="<%= dom_id(@agent, :errors_content) %>">
        <%= render "agents/errors_tab", agent: @agent %>
      </div>
    </div>
    <div data-tabs-target="panel" class="tab-pane d-none">
      <%= render "agents/configuration_tab", agent: @agent %>
    </div>
    <div data-tabs-target="panel" class="tab-pane d-none">
      <%= render "agents/capabilities_tab", agent: @agent %>
    </div>
  </div>
</div>
```

**Turbo Stream Broadcast Targets:**

Broadcasts target only the content inside each tab panel, preserving the tab structure and Stimulus controller state:

```ruby
# Broadcast overview tab content
broadcast_replace_to agent,
  target: dom_id(agent, :overview_content),
  partial: "agents/overview_tab",
  locals: { agent: agent }

# Broadcast errors tab content
broadcast_replace_to agent,
  target: dom_id(agent, :errors_content),
  partial: "agents/errors_tab",
  locals: { agent: agent }
```

**Rationale:** By broadcasting only the content inside each tab panel (not the tab structure itself), we preserve the Stimulus controller state and avoid resetting the active tab when updates arrive.

**Campaign Detail with Progress**

```erb
<!-- app/views/campaigns/show.html.erb -->
<%= turbo_stream_from @campaign %>

<!-- Campaign ETA Summary -->
<div class="alert alert-info">
  <% if @campaign.current_eta %>
    <strong>Current Attack ETA:</strong> <%= distance_of_time_in_words_to_now(@campaign.current_eta) %>
  <% end %>
  <% if @campaign.total_eta %>
    <br><strong>Total Campaign ETA:</strong> <%= distance_of_time_in_words_to_now(@campaign.total_eta) %>
  <% end %>
</div>

<% @campaign.attacks.each do |attack| %>
  <div id="<%= dom_id(attack, :progress) %>">
    <%= render CampaignProgressComponent.new(attack: attack) %>
  </div>
<% end %>

<!-- Recent Cracks Section -->
<div class="mt-4">
  <button class="btn btn-outline-primary" data-bs-toggle="collapse" data-bs-target="#recent_cracks">
    View Recent Cracks (<%= @campaign.hash_list.recent_cracks_count %>)
  </button>

  <div id="recent_cracks" class="collapse mt-3">
    <table class="table table-sm">
      <thead>
        <tr>
          <th>Hash</th>
          <th>Plaintext</th>
          <th>Cracked At</th>
        </tr>
      </thead>
      <tbody>
        <% @campaign.hash_list.recent_cracks.each do |item| %>
          <tr>
            <td><%= truncate(item.hash_value, length: 20) %></td>
            <td><%= item.plain_text %></td>
            <td><%= time_ago_in_words(item.cracked_time) %> ago</td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

**System Health Dashboard**

```erb
<!-- app/views/system_health/index.html.erb -->
<div class="row">
  <% @health_status.each do |service, status| %>
    <div class="col-md-3 mb-3">
      <%= render SystemHealthCardComponent.new(
        service_name: service.to_s.titleize,
        status: status[:status],
        latency: status[:latency],
        error: status[:error]
      ) %>
    </div>
  <% end %>
</div>

<div class="mt-4">
  <h4>Diagnostic Links</h4>
  <ul>
    <li><%= link_to "Sidekiq Dashboard", sidekiq_web_path %></li>
    <li><%= link_to "Rails Logs", "#" %> (view in terminal)</li>
  </ul>
</div>
```

---

## Summary

This technical plan extends the existing CipherSwarm architecture with targeted improvements for operational excellence:

**Key Principles:**

- ✅ Build on existing patterns (Rails 8 + Hotwire + ViewComponent)
- ✅ No new frameworks or major dependencies
- ✅ Maintainable by solo part-time developer
- ✅ Air-gapped deployment compatible
- ✅ Pragmatic over perfect

**Implementation Phases:**

1. **Database migrations** (indexes, cached columns)
2. **Model extensions** (methods, callbacks, broadcasts)
3. **ViewComponents** (reusable UI patterns)
4. **Stimulus controllers** (tabs, toasts)
5. **Controller actions** (system health, task management)
6. **Views and partials** (integrate components)
7. **Logging configuration** (Lograge setup)
8. **Authorization rules** (CanCanCan abilities)

**Testing Strategy:**

- System tests for new flows (agent monitoring, campaign progress, task actions)
- Request specs for new controller actions
- Component tests for ViewComponents
- Model tests for new methods and callbacks

**Deployment Considerations:**

- Run migrations before deployment
- Warm caches on first request (acceptable)
- Monitor Turbo Stream broadcast performance
- Verify air-gapped asset compilation

---

## Architecture Validation Results

This section documents critical architectural decisions validated during the architecture review process.

### Validated Decisions

**1. Cached Agent Metrics: HashcatStatus Callback Pattern**

**Issue:** Original design had Agent callback updating metrics, but Agent doesn't update when HashcatStatus arrives, causing race conditions and stale data.

**Resolution:** Move callback to HashcatStatus model. When status is created, update Agent metrics directly.

**Rationale:** HashcatStatus is the source of truth for agent metrics. By updating Agent from HashcatStatus callback, we ensure metrics are updated whenever new status data arrives, avoiding race conditions.

**Trade-offs:**

- ✅ Eliminates race condition
- ✅ Metrics always fresh (within 30-second throttle)
- ✅ Simpler data flow (status → agent)
- ❌ Adds callback to HashcatStatus model

---

**2. Task Retry: State Machine Event**

**Issue:** Original design bypassed state machine with direct `update(state: :pending)`, violating architecture pattern and skipping callbacks.

**Resolution:** Add `retry` event to Task state machine with proper `failed → pending` transition.

**Rationale:** State machines are the established pattern for lifecycle management in CipherSwarm. Adding a proper event ensures retry follows the same lifecycle management as other state transitions, triggers appropriate callbacks (logging, attack updates), and maintains system invariants.

**Trade-offs:**

- ✅ Maintains architectural consistency
- ✅ Triggers proper callbacks and logging
- ✅ Respects state machine guards
- ❌ Requires migration to add state machine event

---

**3. Turbo Stream + Stimulus: Scoped Broadcasts**

**Issue:** Turbo Stream broadcasts could replace Stimulus controller elements, resetting tab state and disrupting user interaction.

**Resolution:** Broadcast only tab content (inside panels), not tab structure. Wrap content in divs with unique IDs (`dom_id(agent, :overview_content)`).

**Rationale:** By broadcasting only the content inside each tab panel, we preserve the Stimulus controller state and avoid resetting the active tab when updates arrive.

**Trade-offs:**

- ✅ Preserves Stimulus controller state
- ✅ No tab reset on updates
- ✅ User interaction not disrupted
- ❌ Requires careful DOM structure
- ❌ More granular broadcast targets

---

**4. System Health: Redis Lock for Cache Stampede Prevention**

**Issue:** Multiple concurrent requests could overwhelm services with health checks when cache expires.

**Resolution:** Use Redis lock (`SET NX EX`) to ensure only one request runs health checks. Other requests wait briefly and return cached value or "checking" status.

**Rationale:** Redis lock is simple, robust, and prevents cache stampede without requiring background jobs or complex coordination.

**Trade-offs:**

- ✅ Prevents service overload
- ✅ Simple implementation (Redis SET NX)
- ✅ Graceful degradation (returns "checking" if locked)
- ❌ Slight delay for concurrent requests
- ❌ Requires Redis (already in stack)

---

**5. Campaign ETA: Current + Total Display**

**Issue:** Original design only showed running attack ETA, not accounting for pending attacks, giving incomplete picture of campaign completion time.

**Resolution:** Add two methods: `current_eta` (running attacks only) and `total_eta` (all incomplete attacks). Display both in UI.

**Rationale:** Showing both current and total ETA gives users a complete picture: "Current attack finishes in 2h, entire campaign finishes in 6h". This manages expectations better than showing only current attack ETA.

**Trade-offs:**

- ✅ Complete information for users
- ✅ Better expectation management
- ✅ Uses existing ETA calculation logic
- ❌ Total ETA is estimate (based on average)
- ❌ Two cache keys instead of one

---

**6. Task Reassign: Agent Compatibility Validation**

**Issue:** Original design allowed reassigning tasks to incompatible agents (wrong hash type, insufficient performance, no project access), causing task failures.

**Resolution:** Add `agent_compatible_with_task?` validation in controller. Only show compatible agents in UI (filter by hash type, performance, project access).

**Rationale:** Preventing invalid reassignments at the UI level (only showing compatible agents) is better UX than allowing selection and then rejecting. Backend validation provides defense-in-depth.

**Trade-offs:**

- ✅ Prevents invalid reassignments
- ✅ Better UX (only valid options shown)
- ✅ Defense-in-depth (UI + backend validation)
- ❌ More complex agent selection logic
- ❌ Requires querying agent capabilities

---

**7. Turbo Stream Broadcast Errors: Rescue and Log**

**Issue:** Broadcast failures (partial rendering errors, WebSocket issues) could cause silent failures or rollback transactions.

**Resolution:** Wrap all broadcasts in `rescue` blocks, log errors with full backtrace, continue execution.

**Rationale:** Turbo Stream broadcasts are best-effort updates. If a broadcast fails, the database update should still succeed. Logging errors ensures visibility for debugging without disrupting core functionality.

**Trade-offs:**

- ✅ Resilient to broadcast failures
- ✅ Database updates succeed even if UI update fails
- ✅ Errors logged for debugging
- ❌ UI might be stale until next update
- ❌ Silent failure from user perspective

---

### Architecture Readiness

The architecture has been validated against six dimensions:

1. ✅ **Simplicity**: Extends existing patterns, no new frameworks, minimal new dependencies (Lograge only)
2. ✅ **Flexibility**: Modular components, targeted broadcasts allow independent updates
3. ✅ **Robustness**: Error handling for broadcasts, health checks, state machines; Redis lock prevents stampede
4. ✅ **Scaling**: Caching strategy reduces load, indexes optimize queries, appropriate for small customer base
5. ✅ **Codebase Fit**: Follows Rails 8 + Hotwire + ViewComponent patterns, respects state machines, consistent with existing code
6. ✅ **Requirements Coverage**: All Core Flows addressed, Epic Brief acceptance criteria met

**Critical Gaps Resolved:**

- ✅ Cached metrics race condition fixed (HashcatStatus callback)
- ✅ Task retry state machine violation fixed (proper event added)
- ✅ Turbo Stream + Stimulus conflict resolved (scoped broadcasts)
- ✅ System health stampede prevented (Redis lock)
- ✅ Campaign ETA completeness improved (current + total)
- ✅ Task reassign validation added (agent compatibility)
- ✅ Broadcast error handling added (rescue and log)

**Architecture Status:** ✅ **READY FOR IMPLEMENTATION**
