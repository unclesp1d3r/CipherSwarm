# GOTCHAS.md

Hard-won lessons, edge cases, and "watch out for" patterns. Organized by domain.

Referenced from [AGENTS.md](AGENTS.md) — read the relevant section before working in that area.

## Frontend & Accessibility

- **Navbar dropdowns must use `<button>` not `<a href="#">`** — both `_navbar.html.erb` and `NavbarDropdownComponent` had `<a href="#" role="button">` which causes scroll-to-top and is semantically wrong. Always use `<button type="button" class="nav-link dropdown-toggle">`.
- **Use Bootstrap z-index utilities (`z-1` through `z-3`)** instead of inline `style="z-index: ..."` — keeps values in sync with Bootstrap's layering system.
- **Sidebar `<ul>` needs `aria-label="Main navigation"`** — the `<aside>` provides the landmark but doesn't describe the navigation purpose.
- **Turbo morph preserves old DOM across navigations** — `data-turbo-permanent` on navbar collapse kept stale elements alive even after the template changed. When debugging layout changes, use cache-busting URLs (`?_=timestamp`) or `Turbo.visit(url, {action: "replace"})` to force a full re-render.
- **Railsboot components fully removed** — all views now use plain ERB + Bootstrap classes. The Railsboot component layer was an abstraction that made customization harder (e.g., auto-rendering child components). When adding new UI, use Bootstrap HTML directly.
- **Propshaft caches asset digests in-memory** — after `bun run build:css` or `just assets-build`, Propshaft continues serving the old fingerprinted CSS until the Rails server restarts. Use `touch tmp/restart.txt` to trigger Puma reload. Hard-refreshing the browser is NOT sufficient.
- **`rails assets:clobber` deletes ALL build artifacts** — removes JS, CSS, and font files from `app/assets/builds/`. Must run `just assets-build` (full rebuild) to recover, not just `bun run build:css`.

## State Machines

**TaskAssignmentService Query Paths:**

- Campaign-level filters (e.g., `quarantined: false`) must be applied at ALL 4 query paths: `find_existing_incomplete_task`, `find_own_paused_task`, `find_unassigned_paused_task`, and `log_grace_period_blocked` — not just `available_attacks`
- All 4 paths already join campaigns via `joins(attack: { campaign: ... })`, so `.where(campaigns: { ... })` works without additional joins

**Agent States:**

- `benchmarked` is an EVENT (not a state) — transitions pending→active after benchmarks complete
- Agent factory defaults to `state: "active"` — use `create(:agent, state: "pending")` for pending-state tests

**Agent Shutdown Cascade:**

- `agent.shutdown!` pauses running tasks AND pauses attacks with no remaining active tasks
- Shutdown clears task claim fields (`claimed_by_agent_id`, `claimed_at`, `expires_at`) ONLY when `pause!` succeeds — if pause fails, claim fields are preserved to avoid inconsistent state
- Other pause paths (attack cascade via `attack.pause!`, campaign cascade) do NOT clear claim fields
- `attack.resume!` triggers `resume_tasks` callback which resumes all tasks — calling `task.resume!` after will raise `ActiveRecord::StaleObjectError` unless you `task.reload` first
- Campaign has NO `state` column — `campaign.paused?` is computed from attack states

**Attack Scope:**

- `Attack.incomplete` excludes `:running` and `:paused` (only matches pending/failed) — use `without_states(:completed, :exhausted)` when you need all unfinished work including running attacks

**Task State Machine:**

- `task.abandon` triggers `attack.abandon` which destroys ALL tasks for that attack
- For reassigning running tasks, use `pause` then `resume` instead of `abandon`
- The `retry` event already handles incrementing `retry_count` and clearing `last_error`
- `accept` only transitions from `pending` or `running` — orphaned paused tasks must be `resume!`d to `pending` before a new agent can accept them
- `resume!` marks the task as `stale: true`, ensuring the new agent re-downloads crack data
- Tasks have a `paused_at` timestamp set on pause and cleared on resume — used for grace period in orphaned task recovery
- `accept_status` only allows transitions from active states (pending/running → running, paused → same) — finished states (completed/exhausted/failed) are blocked to prevent task resurrection

## Testing

**ActiveRecord N+1 Query Counting:**

- `payload[:name]` in `sql.active_record` notifications is the model name (e.g., `"Attack Load"`, `"Campaign Load"`), NOT `"SQL"` — filtering by `payload[:name] == "SQL"` captures zero queries and makes N+1 tests silently pass
- Correct pattern: exclude noise (`SCHEMA`, `CACHE`, transaction statements like `BEGIN`/`COMMIT`/`SAVEPOINT`/`RELEASE`/`SHOW`/`SET`) and count everything else

**CI Test Scope:**

- GitHub CI excludes `spec/system/` via `--exclude-pattern` — system tests only run locally via `just ci-check`
- `continue-on-error: true` on CI test step for Mergify quarantine features
- JUnit XML: `rspec_junit_formatter` outputs `<testsuite>` (singular); Mergify CI Insights requires `<testsuites>` (plural) — a CI step wraps it
- Tests with font-loading (e.g., Bootstrap icons) can hang in headless Chrome - skip with `skip: ENV["CI"].present?`
- Selenium requires explicit Chrome binary path: `options.binary = ENV["CHROME_BIN"]` in `spec/support/capybara.rb`
- File downloads don't work in CI headless Chrome; test download content via request specs instead
- `ProcessHashListJob` can race against DB truncation cleanup causing intermittent `PG::ForeignKeyViolation` on `hash_items` — safe to re-run

**ActiveStorage Blob Change Detection in Tests:**

- `file.attach(...)` on a persisted record runs in its own transaction — `saved_change_to_blob_id?` is false in a subsequent `hash_list.save!`'s `after_commit`
- To test the blob-change branch of `clear_campaigns_quarantine_if_needed`, stub `attachment.saved_change_to_blob_id?` to return true and trigger a hash_list `update!`

**Factory Callbacks vs Quarantine State:**

- Setting `quarantined: true` in `create(:campaign, quarantined: true)` can be silently cleared by `after_commit` callbacks (e.g., `ProcessHashListJob` → `hash_list.update!(processed: true)` → `clear_campaigns_quarantine_if_needed`)
- Use `campaign.update_columns(quarantined: true, quarantine_reason: "...")` AFTER record creation to set quarantine state reliably in tests

**Turbo Stream System Test Pattern:**

- Turbo Stream partial replacements do NOT trigger flash messages or update elements outside the replaced partial
- Do NOT wait for flash messages or CSS badges after Turbo Stream actions (cancel, retry, reassign)
- Use `sleep 1` + direct DB verification: `task.reload; expect(task.state).to eq("pending")`
- Bootstrap toasts: use `have_css(".toast-body", text: "...", visible: :all, wait: 5)` — the `.toast` wrapper has no visible text content
- Task actions use granular Turbo Streams (`turbo_stream.update`/`replace` with named DOM IDs like `task-details-{id}`, `task-actions-{id}`, `task-error-{id}`), not model-based replacement
- To verify button removal after Turbo actions, reload the page with `visit task_path(task)` then assert

**Turbo Frame Targeting:**

- Do NOT wrap entire show page content in a single `turbo_frame_tag dom_id(@model)` — causes all sections to be replaced when any Turbo Stream targets the model
- Use granular named frames/divs for updateable sections: `turbo_frame_tag "task-details-#{@task.id}"`, `div id="task-actions-#{@task.id}"`
- Partials rendered via Turbo Stream should NOT contain their own `turbo_frame_tag` — let the show page control framing
- Use `turbo_stream.update` for turbo-frame targets (preserves frame element); use `turbo_stream.replace` for div targets (partial must include wrapper div with same ID)

**Health Check Test Setup:**

- Specs touching `SystemHealthCheckService` require Redis lock cleanup in `before`: `Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }`
- Also need stubs for DB, storage, and Sidekiq — extract a `stub_health_checks` private method (see `spec/requests/system_health_spec.rb` for canonical example)

**State Machine Testing:**

- `transition any => same` always succeeds unless the save fails
- To test failure paths: invalidate the model via `update_column` (bypassing validations) so save fails during transition
- Beware DB NOT NULL constraints - use columns with only Rails-level validations (e.g., `workload_profile` numericality)
- `can_pause?`/`can_resume?` always return true for events with `transition any => same` — undercover flags the false branch as uncovered; use `allow_any_instance_of(Model).to receive(:can_pause?).and_return(false)` stubs
- `find_each` on relations can't be tested with plain arrays — use `double("relation")` with `allow(relation).to receive(:find_each).and_yield(task)`

**Deterministic Ordering:**

- When using `min_by`, `sort_by`, or `ORDER BY` with columns that can tie, always add a tiebreaker (typically `.id`)
- Example: `tasks.min_by { |t| [t.priority, t.progress, t.id] }` — without `t.id`, CI may return different results than local

**Undercover (Change-Based Coverage):**

- Undercover flags ALL uncovered branches in changed lines, even "impossible" ones — must cover with stubs
- `obj&.method` safe navigation creates an unreachable nil branch when nil is guarded earlier — remove the `&` if nil is impossible
- Rescue blocks in changed code need explicit error-path tests — stub the failing call with `and_raise`
- `swagger/v1/swagger.json` changes from `rails rswag` must be committed — schema mismatches cause rswag CI failures
- `retry_on` / `discard_on` block bodies are unreachable via `perform_now` — undercover flags them as uncovered even with `# :nocov:` (undercover treats `n/a` as uncovered). Workaround: extract handler to a lambda constant (`HANDLER = lambda { |job, error| ... }`) and pass via `&HANDLER` — lambda body gets coverage at class load time. See `ApplicationJob::TEMP_STORAGE_DISCARD_HANDLER`.

**Database Deadlock in Tests:**

- `DatabaseCleaner.clean_with(:truncation)` can deadlock if concurrent PG connections exist — retry the test command (transient)
- **Never run two `just ci-check` or `bundle exec rspec` instances simultaneously** — they share the same test database and will cause mass `PG::TRDeadlockDetected` failures and `tmp/storage` file conflicts
- Some tests fail intermittently in full suite but pass in isolation — use `git stash` to verify if failures are pre-existing vs introduced
- **`just ci-check` output buffering**: `just` recipes run via background mode produce empty output files. Run individual steps (`just check`, `bundle exec rspec`, `just undercover`) directly when you need real-time output.

**Cache Key Testing:**

- `touch` may not change `updated_at` within the same second — use `update_column(:updated_at, 1.minute.from_now)` to force cache key changes in tests
- CampaignEtaCalculator cache keys include `attacks.maximum(:updated_at)` and `tasks.maximum(:updated_at)` — both must change to bust cache

**Hash Item Test Setup:**

- When testing "no uncracked hashes" scenarios, call `hash_list.hash_items.delete_all` before creating test hash_items — factories or callbacks may create default items

**DB Constraint Testing:**

- Use `record.delete` (not `destroy`) when testing DB-level FK cascades — `destroy` fires Rails callbacks that mask missing constraints

**Request Tests:**

- Turbo Stream error rescue in controllers with `rescue_from StandardError` causes `ActionController::RespondToMismatchError` (double `respond_to`) — test with `expect { post ... }.to raise_error(ActionController::RespondToMismatchError)`
- When service methods add new SQL queries, stubs like `allow(...).to receive(:execute).with("SELECT 1")` reject other queries — add `and_call_original` as default first

**Logging Tests:**

- Structured log output verification
- Rails.logger mocking to verify log messages
- Sensitive data filtering verification
- Error handling without breaking application flow
- Test that logs include relevant context (IDs, timestamps, state changes)
- See docs/development/logging-guide.md for logging patterns

**ViewComponent Testing:**

- When components query database (e.g., compatible agents), tests must create that data
- Use `create(:factory)` in tests before `render_inline` to ensure conditional UI renders

**ActiveJob::DeserializationError:**

- For tests, use `instance_double` instead of instantiating (constructor signature varies)

## API & rswag

**rswag 3.0.0.pre Migration Notes:**

- `openapi_strict_schema_validation` removed in 3.x — replaced by `openapi_no_additional_properties` and `openapi_all_properties_required`
- `openapi_all_properties_required: true` means **every property** declared in a schema is treated as required in validation — if a response omits a declared property, `run_test!` fails. To handle optional fields, declare them in the schema and always return them (with `null` for absent cases), using `nullable: true` on the property.
- `request_body_json` does not exist in rswag 3.0.0.pre — polyfilled in `spec/support/rswag_polyfills.rb`
- `RequestFactory` in 3.x resolves parameters via `params.fetch(name)` against `example.request_params` (empty hash by default); since rswag 2.x resolved parameters via `example.send(param_name)` directly from `let` blocks, `LetFallbackHash` in `spec/support/rswag_polyfills.rb` bridges this gap by falling back to `example.public_send(key)` when `request_params` lacks the key
- The rswag 3.x formatter already converts internal `in: :body` + `consumes` to OAS 3.0 `requestBody` — polyfills use this mechanism
- Known limitation: rswag 3.0.0.pre places `description` inside `requestBody.content.schema` rather than at the `requestBody` level — this is less conventional in OpenAPI 3.0 but does not affect functionality
- rswag 3.0.0.pre is the only version with proper OpenAPI 3.0 `requestBody` generation; 2.17.0 (latest stable, Nov 2025) only added Rails 8.1 gemspec support and still has the `in: body` limitation
- `request_body_json` must be called **inside** the HTTP method block (`post`, `put`, etc.), not at the path level
- When an endpoint `produces "text/plain"`, error responses returning JSON inherit `text/plain` in the generated OpenAPI spec. Override by setting `metadata[:response][:content]` directly inside the response block with the correct schema under `"application/json"` — the `content_type:` parameter on `response` does not work reliably for this purpose
- rswag 3.0.0.pre passes `request.body` as `StringIO` (not `String`) in `after(:each)` hooks — `JSON.parse(request.body)` raises `TypeError: no implicit conversion of StringIO into String`. Use `body = request.body.respond_to?(:read) ? request.body.tap(&:rewind).read : request.body` before parsing. See `swagger_helper.rb` request example capture hook.

**Vitest Mock Patterns:**

- `bun test` uses Bun's runner (no jsdom) — always use `just test-js` or `npx vitest run` for Vitest
- `vi.mock` is hoisted to file top; use `vi.hoisted()` for mock references: `const { mockFn } = vi.hoisted(() => ({ mockFn: vi.fn() }))`
- Turbo/Stimulus mocks: mock `@hotwired/turbo` and `@hotwired/stimulus` modules, not individual imports

**Devise 5 Label Casing:**

- Devise 5 applies `downcase_first` to humanized authentication keys in flash messages ("name" instead of "Name")
- Test page objects should derive labels dynamically via `User.human_attribute_name(key).downcase_first` (see `spec/support/page_objects/sign_in_page.rb#devise_auth_keys_label`)

**Unauthenticated Endpoints:**

- Endpoints inheriting from `ActionController::API` (bypassing agent auth) must never return raw `e.message` in responses — this leaks internal details (hostnames, DB errors, credential hints)
- Use a generic stable error string for clients (e.g., `"Internal health check failure"`), log full exception details server-side with `Rails.logger.error`

## Database & ActiveRecord

**ActiveRecord Setter Error Trap:**

- `errors.add` in a custom attribute setter (e.g., `def foo=(val)`) is useless — Rails clears `errors` before running validations on `save`/`valid?`
- Use an instance variable flag in the setter + a `validate` method to surface the error: `@invalid_foo = true` in rescue, then `validate :foo_is_valid` checks the flag
- See `Agent#advanced_configuration=` and `advanced_configuration_is_valid_json` for the pattern

**Strong Parameters Key Types:**

- `ActionController::Parameters#to_h` returns a plain `Hash` with **string keys** — `merged_params[:symbol_key]` returns `nil`
- Use `.to_h.with_indifferent_access` when you need symbol access on the result
- This bit `word_lists_controller`, `rule_lists_controller`, `mask_lists_controller` — `sensitive` flag was always `false` due to `merged_params[:project_ids]` returning nil

**JSONB Key Access:**

- ActiveRecord deserializes JSONB columns with **string keys** after DB round-trip, but `params` and in-memory hashes use **symbol keys**
- Code inspecting saved JSONB fields must check both: `hash.dig("key") || hash.dig(:key)`
- This applies to `AgentError#metadata`, `HashcatStatus` fields, and any other JSONB column read after `save`

**upsert_all:**

- Rails 8.1+ `upsert_all` auto-manages `updated_at` via `CURRENT_TIMESTAMP` on conflict — do NOT list `updated_at` in `update_only` (causes PG `multiple assignments to same column` error)
- `upsert_all` bypasses AR callbacks, so `touch: true` associations and `broadcasts_refreshes` will not fire — ensure the owning model is saved separately if cache invalidation is needed

**Foreign Key Cascade Strategy:**

- Prefer DB-level `on_delete: :cascade` / `:nullify` over relying solely on Rails `dependent:` callbacks
- `delete_all` and DB-level cascades bypass Rails callbacks — without DB rules, orphans or FK violations result
- Ephemeral child tables (telemetry, statuses) should cascade with their parent
- When a table has multiple FKs to the same parent, always specify `column:` explicitly in `remove_foreign_key`/`add_foreign_key`
- Test DB cascades with `delete` (not `destroy`) to verify the FK constraint, not Rails callbacks

**Database Transactions:**

- Wrap related operations in `Model.transaction do ... end` when they must succeed/fail together
- Use `save!` (bang) inside transactions to trigger rollback on failure
- Handle `ActiveRecord::RecordInvalid` outside the transaction block

**Migration Generation:**

- When replacing a permissive index with a stricter unique index, add a `DELETE` + `DISTINCT ON` cleanup step before `add_index` to remove duplicate rows that would violate the new constraint
- Running `db:migrate` regenerates `schema.rb` from actual DATABASE state, not from migrations
- Manual migration creation causes schema drift: unrelated DB changes get committed

**CanCanCan Nested Associations:**

- Task abilities use: `attack: { campaign: { project_id: user.all_project_ids } }`
- Association path follows model relationships: Task → attack → campaign → project
- Wrong path order will silently fail authorization checks

**Nullable Parameters:**

- Use `params.key?(:field)` to check if parameter exists (even if nil)
- Use `params[:field].present?` to check for non-nil values only
- Important for API endpoints that need to distinguish between missing vs null values

## Infrastructure

**Redis Lock Patterns:**

- `conn.set(key, value, nx: true)` returns `true` on success, `nil` on contention (not `false`) — never use `rescue => nil` around lock acquisition, as it makes contention indistinguishable from Redis failure
- Always capture lock errors in a separate variable (`lock_error`) to distinguish "lock contended" from "Redis down"
- See `SystemHealthCheckService#call` for the canonical lock-with-error-capture pattern

**Turbo Stream Broadcasts:**

- Broadcast partials (rendered by `broadcast_replace_to`/`broadcast_replace_later_to`) run in background jobs with NO `current_user` — partials must not reference `current_user` or session data
- For targeted broadcasts, extract small partials (e.g., `_index_state.html.erb`) that wrap a single element with a stable DOM ID, following the Agent `broadcast_index_state` pattern
- Never fragment-cache content containing `safe_can?` calls in broadcast-rendered partials — Sidekiq has no `current_user`, so `safe_can?` returns false and poisons the cache for all users. Keep auth-gated elements outside cache blocks.
- **Never fragment-cache ViewComponents that render `can?` checks or `form_authenticity_token`** — `cache: agent` on `AgentStatusCardComponent` leaked admin action buttons and stale CSRF tokens across users. Either omit caching entirely or scope cache keys to include `current_user.id`. Turbo Stream broadcasts handle freshness for uncached components.
- Use `saved_changes.keys.intersect?(FIELDS)` or `saved_change_to_<attr>?` guards in `after_update_commit` callbacks to avoid broadcasting tabs whose data didn't change (see `Agent#broadcast_tab_updates`)

**Logging Patterns:**

- Use structured logging with `[LogType]` prefixes (`[APIRequest]`, `[APIError]`, `[AgentLifecycle]`, `[BroadcastError]`, `[AttackAbandon]`, `[JobDiscarded]`)
- `Rails.logger.debug { block }` (block-form) cannot be tested with `have_received(:debug).with(/pattern/)` — use block-capture: `debug_messages = []; allow(Rails.logger).to receive(:debug) { |*args, &block| debug_messages << (block ? block.call : args.first) }; expect(debug_messages).to include(match(/pattern/))`
- Include relevant context (IDs, timestamps, state changes)
- Log errors with backtrace (first 5 lines)
- Ensure logging failures don't break application (rescue blocks)
- Always test that important events are logged correctly
- Verify sensitive data is filtered (see docs/development/logging-guide.md)

**Docker Temp Storage (`/tmp` and `/rails/tmp`):**

- Active Storage `blob.open` streams entire blobs to `Dir.tmpdir` (`/tmp` on Linux) — the download path is `blob.open` → `ActiveStorage::Downloader#open_tempfile` → `Tempfile.open(name, nil)` → `Dir.tmpdir`
- This is `/tmp`, NOT `/rails/tmp` — the Dockerfile does not set `TMPDIR`, so Ruby's default applies
- `/rails/tmp` contains only Bootsnap cache (~27 MB at boot) and `restart.txt` — no upload or job temp files land here
- Under concurrent Sidekiq load, `/tmp` fills up causing `Errno::ENOSPC` in `ProcessHashListJob`, `CountFileLinesJob`, `CalculateMaskComplexityJob`
- Both compose files mount `tmpfs` at `/tmp` and `/rails/tmp` on web and sidekiq services — do not remove these mounts
- tmpfs size must be **at least** as large as the largest single attack file and ideally several times larger for concurrent processing
- `TempStorageValidation` concern checks available space before download — raises `InsufficientTempStorageError` with retry+discard via `ApplicationJob`
- See `docs/deployment/docker-storage-and-tmp.md` for full sizing guidance

**Nginx and Large File Uploads:**

- `client_max_body_size 0` (unlimited) is required — Active Storage direct uploads PUT files via `/rails/active_storage/disk/*` and word lists can be multi-GB
- The `/rails/active_storage/` location block uses `proxy_request_buffering off` — without this, nginx buffers the entire upload body to `/var/cache/nginx/client_temp/` before proxying, filling the nginx container's overlay
- Timeouts are set to 1 hour (`proxy_send_timeout 3600s`, `proxy_read_timeout 3600s`) for multi-GB uploads over slow links
- Thruster was removed — its 30s `HTTP_READ_TIMEOUT` default silently killed large uploads with a 502 and no client-side error. Nginx handles HTTP/2, compression, and caching instead.

**Active Storage Direct Upload (Client-Side):**

- Active Storage computes an MD5 checksum of the entire file client-side (SparkMD5, 2 MB chunks via `FileReader`) before the upload starts
- For files >10-20 GB, this silently stalls in the browser — no CPU spike, no error, no network requests, just a frozen submit button
- The `POST /rails/active_storage/direct_uploads` request (which gets the signed upload URL) only fires AFTER the hash completes — if it never fires, the hash is stuck
- **Solution (#747):** Attack resources (word lists, rule lists, mask lists) now upload via tusd (Go sidecar) with tus-js-client, bypassing Active Storage entirely. Hash lists still use Active Storage direct upload.
- Upload progress UI (#746): `direct_upload_controller.js` shows progress via tus-js-client `onProgress` callback

**tusd (Resumable Upload Server):**

- **tusd does NOT auto-clean incomplete uploads** — a `tusd-cleanup` Alpine sidecar runs hourly to delete uploads older than 24 hours
- **nginx `proxy_buffering off` is required** in addition to `proxy_request_buffering off` — without both, nginx buffers upload data defeating tus resumability
- **Preventing double upload**: tus-js-client uploads the file, then the Stimulus controller removes the file input's `name` attribute so the browser excludes it from the multipart form POST
- **tusd port is 8080** (not 1080) — the Alpine image uses `wget` for health checks (not `curl`)
- **Upload ID validation**: `TusUploadHandler#extract_upload_id` validates hex format to prevent path traversal
- **tusd hook retries**: configure `-hooks-http-retry=5 -hooks-http-backoff=2` in production for resilience
- **tusd hook auth in production**: `verify_tusd_origin` rejects all requests when `TUSD_HOOK_SECRET` is unset in production — dev/test environments skip verification. If adding new unauthenticated bypass conditions, ensure they cannot activate in production.
- **TUSD_HOOK_SECRET must be set in BOTH web and tusd services** — tusd forwards it as `X-Tusd-Hook-Secret` header via `-hooks-http-forward-headers`, web reads it in `verify_tusd_origin` to authenticate. Missing from either side silently disables auth.

**Inline `rescue` in Security Code:**

- Ruby's inline `rescue` (`foo rescue bar`) catches ALL exceptions including `Errno::EACCES`, `SystemCallError`, `SecurityError` — not just `StandardError`
- Never use inline `rescue` in security-critical validation code — use explicit `begin/rescue` with specific error classes
- Fail closed: if path validation can't resolve a directory, reject the request rather than falling back to string comparison
- See `TusUploadHandler#validate_source_path!` for the correct pattern

**Active Storage Blob Validator Patching:**

- **Never use `clear_validators!` on `ActiveStorage::Blob`** — it removes ALL validators (including `service_name` presence), not just the one you want. Use targeted removal: `_validators.delete(:checksum)` + iterate `_validate_callbacks` to remove specific callbacks.
- **`blob.open` does NOT accept `verify:` kwarg** — that param is on `ActiveStorage::Downloader#open`, not `Blob#open`. To skip integrity verification (e.g., when computing your own checksum), call `blob.service.open(blob.key, checksum: blob.checksum, verify: false)` directly.

**Jobs & Callbacks:**

- 4 models enqueue jobs from `after_commit` callbacks (`ProcessHashListJob`, `CalculateMaskComplexityJob`, `CountFileLinesJob`, `CampaignPriorityRebalanceJob`)
- `active_job-performs` gem does NOT fit — these jobs contain substantial logic (batch processing, atomic locks, file I/O), not simple model method delegation
- This is accepted Rails convention; don't try to "fix" it unless jobs become pure delegators

**Ruby 3.4+ Dependencies:**

- `csv` gem must be in Gemfile (removed from Ruby stdlib in 3.4)
- Add `gem "csv", "~> 3.3"` if generating CSV files

**PreToolUse Hook:**

- A PreToolUse hook protects certain files (migrations, etc.) from direct Read/Edit/Write tools
- Always try Read/Edit/Write tools first
- If blocked, use bash commands as fallback for that specific file only
- Never default to bash for file operations without first attempting proper tools
