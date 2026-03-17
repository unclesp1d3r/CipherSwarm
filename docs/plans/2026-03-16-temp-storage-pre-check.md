# Temp Storage Pre-Check for Blob Jobs — Implementation Plan

**Goal:** Prevent Sidekiq jobs from attempting Active Storage blob downloads when insufficient temp storage is available, failing fast with a clear error instead of mid-download `Errno::ENOSPC`.

**Architecture:** A shared `TempStorageValidation` concern provides `ensure_temp_storage_available!(attachment)` which compares `attachment.blob.byte_size` against `Sys::Filesystem.stat(Dir.tmpdir).bytes_available`. A custom `InsufficientTempStorageError` is raised on failure. Jobs retry with polynomial backoff (transient pressure from concurrent jobs) then discard with a structured log message.

**Tech Stack:** `sys-filesystem` gem, ActiveSupport::Concern, ActiveJob retry/discard

---

## Implementation Tasks

### Task 1: Add `sys-filesystem` gem

**Files:**

- Modify: `Gemfile`

**Step 1: Add the gem**

Add to the main gem group (not in a platform/environment block) since this runs in all environments:

```ruby
gem "sys-filesystem", "~> 1.5"
```

Add it after the `csv` gem (line 78) to keep alphabetical ordering within the utility gems section.

**Step 2: Install**

Run: `bundle install` Expected: Gem installs successfully, `Gemfile.lock` updated.

**Step 3: Verify**

Run: `bundle exec ruby -e "require 'sys/filesystem'; puts Sys::Filesystem.stat(Dir.tmpdir).bytes_available"` Expected: Prints a number (available bytes in tmpdir).

**Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -s -m "chore: add sys-filesystem gem for temp storage space checks"
```

---

### Task 2: Create `InsufficientTempStorageError` and `TempStorageValidation` concern — tests first

**Files:**

- Create: `spec/jobs/concerns/temp_storage_validation_spec.rb`

**Step 1: Write the failing tests**

```ruby
# frozen_string_literal: true

require "rails_helper"
require "sys/filesystem"

RSpec.describe TempStorageValidation do
  # Create a minimal test job that includes the concern
  let(:test_job_class) do
    Class.new(ApplicationJob) do
      include TempStorageValidation

      def perform(attachment)
        ensure_temp_storage_available!(attachment)
      end
    end
  end

  let(:blob) { instance_double(ActiveStorage::Blob, byte_size: 100.megabytes, filename: "wordlist.txt") }
  let(:attachment) { instance_double(ActiveStorage::Attached::One, blob: blob) }
  let(:fs_stat) { instance_double(Sys::Filesystem::Stat, bytes_available: available_bytes) }

  before do
    allow(Sys::Filesystem).to receive(:stat).with(Dir.tmpdir).and_return(fs_stat)
  end

  context "when sufficient space is available" do
    let(:available_bytes) { 200.megabytes }

    it "does not raise an error" do
      expect { test_job_class.new.perform(attachment) }.not_to raise_error
    end
  end

  context "when available space equals the blob size" do
    let(:available_bytes) { 100.megabytes }

    it "raises InsufficientTempStorageError" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError)
    end
  end

  context "when insufficient space is available" do
    let(:available_bytes) { 50.megabytes }

    it "raises InsufficientTempStorageError" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError)
    end

    it "includes the filename in the error message" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError, /wordlist\.txt/)
    end

    it "includes the required bytes in the error message" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError, /104857600 bytes required/)
    end

    it "includes the available bytes in the error message" do
      expect { test_job_class.new.perform(attachment) }
        .to raise_error(InsufficientTempStorageError, /52428800 bytes available/)
    end
  end

  context "when Sys::Filesystem raises an error" do
    before do
      allow(Sys::Filesystem).to receive(:stat).and_raise(Sys::Filesystem::Error, "permission denied")
    end

    it "logs a warning and does not block the job" do
      allow(Rails.logger).to receive(:warn)
      expect { test_job_class.new.perform(attachment) }.not_to raise_error
      expect(Rails.logger).to have_received(:warn).with(/\[TempStorage\].*permission denied/)
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/jobs/concerns/temp_storage_validation_spec.rb` Expected: FAIL — `uninitialized constant TempStorageValidation`

---

### Task 3: Implement `InsufficientTempStorageError` and `TempStorageValidation` concern

**Files:**

- Create: `app/errors/insufficient_temp_storage_error.rb`
- Create: `app/jobs/concerns/temp_storage_validation.rb`

**Step 1: Create the custom error class**

```ruby
# frozen_string_literal: true

# Raised when a job detects insufficient temp storage space to download
# an Active Storage blob. Retried with backoff (transient space pressure
# from concurrent jobs) then discarded if space remains unavailable.
class InsufficientTempStorageError < StandardError; end
```

**Step 2: Create the concern**

```ruby
# frozen_string_literal: true

# REASONING:
#   Why: Background jobs that call blob.open download the entire file to Dir.tmpdir
#     before processing. In Docker containers with tmpfs mounts, this can exhaust
#     available space. Checking before download prevents mid-transfer ENOSPC failures
#     and provides clear, actionable error messages for operators.
#   Alternatives Considered:
#     1) Inline check in each job: duplicates the same 5 lines across 3 jobs.
#     2) ApplicationJob base method: concern is more explicit about opt-in semantics.
#     3) Middleware: too broad — not all jobs download blobs.
#   Decision: ActiveSupport::Concern keeps the check co-located with jobs that need it
#     and follows the existing pattern (see AttackPreemptionLoop).
#   Performance: One stat() syscall per check — negligible.
#   Future: Could add a configurable headroom multiplier if operators want a safety margin.

require "sys/filesystem"

module TempStorageValidation
  extend ActiveSupport::Concern

  private

  # Checks that Dir.tmpdir has more space than the blob requires.
  # Raises InsufficientTempStorageError if space is insufficient.
  # Rescues filesystem stat errors to avoid blocking jobs when the
  # check itself fails (e.g., permission issues, unsupported FS).
  #
  # @param attachment [ActiveStorage::Attached::One] the file attachment to check
  # @raise [InsufficientTempStorageError] if available space <= blob byte_size
  def ensure_temp_storage_available!(attachment)
    blob = attachment.blob
    stat = Sys::Filesystem.stat(Dir.tmpdir)
    available = stat.bytes_available

    return if available > blob.byte_size

    raise InsufficientTempStorageError,
      "[TempStorage] Not enough temp storage to download #{blob.filename} " \
      "(#{blob.byte_size} bytes required, #{available} bytes available in #{Dir.tmpdir})"
  rescue Sys::Filesystem::Error => e
    Rails.logger.warn(
      "[TempStorage] Could not check available temp storage: #{e.message}. " \
      "Proceeding with download anyway."
    )
  end
end
```

**Step 3: Run tests to verify they pass**

Run: `bundle exec rspec spec/jobs/concerns/temp_storage_validation_spec.rb` Expected: All 6 examples PASS.

**Step 4: Commit**

```bash
git add app/errors/insufficient_temp_storage_error.rb app/jobs/concerns/temp_storage_validation.rb spec/jobs/concerns/temp_storage_validation_spec.rb
git commit -s -m "feat: add TempStorageValidation concern for blob download pre-check

Checks available tmpfs space against blob.byte_size before downloading.
Raises InsufficientTempStorageError when space is insufficient.
Gracefully degrades if the filesystem stat itself fails."
```

---

### Task 4: Wire retry/discard into `ApplicationJob` — tests first

**Files:**

- Modify: `spec/jobs/application_job_spec.rb`

**Step 1: Read the existing spec**

Read `spec/jobs/application_job_spec.rb` to understand current test structure.

**Step 2: Add tests for the retry/discard configuration**

Add to the existing spec:

```ruby
describe "InsufficientTempStorageError handling" do
  it "is configured to retry on InsufficientTempStorageError" do
    expect(described_class.rescue_handlers).to include(
      have_attributes(first: "InsufficientTempStorageError")
    )
  end
end
```

**Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/application_job_spec.rb` Expected: FAIL — no rescue handler for InsufficientTempStorageError.

---

### Task 5: Implement retry/discard in `ApplicationJob`

**Files:**

- Modify: `app/jobs/application_job.rb`

**Step 1: Add retry and discard configuration**

Add after the existing `retry_on ActiveRecord::Deadlocked` line:

```ruby
  # Retry when temp storage is full — concurrent jobs may free space.
  # After 5 attempts, discard with a structured log message so operators
  # know to increase tmpfs size or reduce Sidekiq concurrency.
  retry_on InsufficientTempStorageError, wait: :polynomially_longer, attempts: 5
  discard_on(InsufficientTempStorageError) do |job, error|
    Rails.logger.error(
      "[TempStorage] #{job.class.name} discarded after retries — #{error.message}. " \
      "Job ID: #{job.job_id}. Arguments: #{job.arguments.inspect}. " \
      "Action: increase tmpfs size or reduce Sidekiq concurrency. " \
      "See docs/deployment/docker-storage-and-tmp.md"
    )
  end
```

**Important:** `retry_on` must come BEFORE `discard_on` for the same error class. ActiveJob tries handlers in reverse order — `discard_on` only fires after retries are exhausted.

**Step 2: Run test to verify it passes**

Run: `bundle exec rspec spec/jobs/application_job_spec.rb` Expected: PASS.

**Step 3: Commit**

```bash
git add app/jobs/application_job.rb spec/jobs/application_job_spec.rb
git commit -s -m "feat: add retry/discard for InsufficientTempStorageError in ApplicationJob

Retries 5 times with polynomial backoff (handles transient space pressure),
then discards with a structured log message pointing to sizing docs."
```

---

### Task 6: Wire `TempStorageValidation` into `ProcessHashListJob` — tests first

**Files:**

- Modify: `spec/jobs/process_hash_list_job_spec.rb`

**Step 1: Add test for the pre-check**

Add a new context block inside the `#perform` describe:

```ruby
context "when temp storage is insufficient" do
  let(:hash_list) do
    hl = create(:hash_list, processed: true)
    hl.update_column(:processed, false) # rubocop:disable Rails/SkipsModelValidations
    HashItem.where(hash_list_id: hl.id).delete_all
    hl.reload
  end

  before do
    fs_stat = instance_double(Sys::Filesystem::Stat, bytes_available: 1.byte)
    allow(Sys::Filesystem).to receive(:stat).with(Dir.tmpdir).and_return(fs_stat)
  end

  it "raises InsufficientTempStorageError before processing" do
    expect { described_class.perform_now(hash_list.id) }
      .to raise_error(InsufficientTempStorageError)
  end

  it "does not create any hash items" do
    begin
      described_class.perform_now(hash_list.id)
    rescue InsufficientTempStorageError
      # expected
    end
    expect(HashItem.where(hash_list_id: hash_list.id).count).to eq(0)
  end

  it "rolls back the processed flag" do
    begin
      described_class.perform_now(hash_list.id)
    rescue InsufficientTempStorageError
      # expected
    end
    expect(hash_list.reload.processed).to be false
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/process_hash_list_job_spec.rb` Expected: FAIL — no InsufficientTempStorageError raised (the job proceeds to download).

---

### Task 7: Implement pre-check in `ProcessHashListJob`

**Files:**

- Modify: `app/jobs/process_hash_list_job.rb`

**Step 1: Include the concern and add the check**

Add `include TempStorageValidation` after `queue_as :ingest`.

Add the check inside `ingest_hash_items`, immediately before `list.file.open`:

```ruby
def ingest_hash_items(list)
  # Clean up any partial results from a prior failed attempt to ensure idempotent ingestion.
  list.hash_items.delete_all

  ensure_temp_storage_available!(list.file)

  hash_items = []
  processed_count = 0
  # ... rest of method unchanged
```

**Step 2: Run tests to verify they pass**

Run: `bundle exec rspec spec/jobs/process_hash_list_job_spec.rb` Expected: All examples PASS.

**Step 3: Commit**

```bash
git add app/jobs/process_hash_list_job.rb spec/jobs/process_hash_list_job_spec.rb
git commit -s -m "feat: add temp storage pre-check to ProcessHashListJob

Checks available tmpfs space before downloading the hash list blob.
Raises InsufficientTempStorageError if space is insufficient,
which triggers retry then discard via ApplicationJob handlers."
```

---

### Task 8: Wire `TempStorageValidation` into `CountFileLinesJob` — tests first

**Files:**

- Modify: `spec/jobs/count_file_lines_job_spec.rb`

**Step 1: Add test for the pre-check**

Add a new context block inside the `#perform` describe:

```ruby
context "when temp storage is insufficient" do
  let(:rule_list) do
    rl = create(:rule_list, processed: true, line_count: 999)
    rl.update_columns(processed: false, line_count: 0) # rubocop:disable Rails/SkipsModelValidations
    rl.reload
  end

  before do
    fs_stat = instance_double(Sys::Filesystem::Stat, bytes_available: 1.byte)
    allow(Sys::Filesystem).to receive(:stat).with(Dir.tmpdir).and_return(fs_stat)
  end

  it "raises InsufficientTempStorageError before processing" do
    expect { described_class.perform_now(rule_list.id, "RuleList") }
      .to raise_error(InsufficientTempStorageError)
  end

  it "does not update the record" do
    begin
      described_class.perform_now(rule_list.id, "RuleList")
    rescue InsufficientTempStorageError
      # expected
    end
    expect(rule_list.reload.processed).to be false
    expect(rule_list.reload.line_count).to eq(0)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/count_file_lines_job_spec.rb` Expected: FAIL.

---

### Task 9: Implement pre-check in `CountFileLinesJob`

**Files:**

- Modify: `app/jobs/count_file_lines_job.rb`

**Step 1: Include the concern and add the check**

Add `include TempStorageValidation` after `queue_as :ingest`.

Add the check immediately before `record.file.open`:

```ruby
def perform(id, type)
  unless ALLOWED_TYPES.include?(type)
    raise InvalidTypeError, "[CountFileLinesJob] Invalid type '#{type}' - must be one of #{ALLOWED_TYPES.join(', ')}"
  end

  klass = type.constantize
  record = klass.find_by(id: id)
  return if record.nil?
  return if record.processed? || record.file.nil?

  ensure_temp_storage_available!(record.file)

  record.file.open do |file|
    # ... rest unchanged
```

**Step 2: Run tests to verify they pass**

Run: `bundle exec rspec spec/jobs/count_file_lines_job_spec.rb` Expected: All examples PASS.

**Step 3: Commit**

```bash
git add app/jobs/count_file_lines_job.rb spec/jobs/count_file_lines_job_spec.rb
git commit -s -m "feat: add temp storage pre-check to CountFileLinesJob"
```

---

### Task 10: Wire `TempStorageValidation` into `CalculateMaskComplexityJob` — tests first

**Files:**

- Modify: `spec/jobs/calculate_mask_complexity_job_spec.rb`

**Step 1: Add test for the pre-check**

Add a new context block inside the `#perform` describe:

```ruby
context "when temp storage is insufficient" do
  let(:mask_list) do
    ml = create(:mask_list, complexity_value: 999)
    ml.update_column(:complexity_value, 0) # rubocop:disable Rails/SkipsModelValidations
    ml.reload
  end

  before do
    fs_stat = instance_double(Sys::Filesystem::Stat, bytes_available: 1.byte)
    allow(Sys::Filesystem).to receive(:stat).with(Dir.tmpdir).and_return(fs_stat)
  end

  it "raises InsufficientTempStorageError before processing" do
    expect { described_class.perform_now(mask_list.id) }
      .to raise_error(InsufficientTempStorageError)
  end

  it "does not update the complexity value" do
    begin
      described_class.perform_now(mask_list.id)
    rescue InsufficientTempStorageError
      # expected
    end
    expect(mask_list.reload.complexity_value).to eq(0)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/calculate_mask_complexity_job_spec.rb` Expected: FAIL.

---

### Task 11: Implement pre-check in `CalculateMaskComplexityJob`

**Files:**

- Modify: `app/jobs/calculate_mask_complexity_job.rb`

**Step 1: Include the concern and add the check**

Add `include TempStorageValidation` after `queue_as :ingest`.

Add the check immediately before `mask_list.file.open`:

```ruby
def perform(mask_list_id)
  mask_list = MaskList.find(mask_list_id)
  return if mask_list.nil? || !mask_list.file.attached? || mask_list.complexity_value != 0

  ensure_temp_storage_available!(mask_list.file)

  total_combinations = 0
  mask_list.file.open do |file|
    # ... rest unchanged
```

**Step 2: Run tests to verify they pass**

Run: `bundle exec rspec spec/jobs/calculate_mask_complexity_job_spec.rb` Expected: All examples PASS.

**Step 3: Commit**

```bash
git add app/jobs/calculate_mask_complexity_job.rb spec/jobs/calculate_mask_complexity_job_spec.rb
git commit -s -m "feat: add temp storage pre-check to CalculateMaskComplexityJob"
```

---

### Task 12: Run full test suite and verify

**Step 1: Run all job specs**

Run: `bundle exec rspec spec/jobs/` Expected: All PASS.

**Step 2: Run linter**

Run: `just check` Expected: No new offenses.

**Step 3: Run undercover**

Run: `just undercover` Expected: No uncovered lines in changed files.

**Step 4: Commit any fixes if needed**

---

### Task 13: Update documentation

**Files:**

- Modify: `docs/deployment/docker-storage-and-tmp.md`

**Step 1: Add a section about the pre-check behavior**

Add a new `## Pre-Download Space Check` section after the `## Recovery` section:

````markdown
## Pre-Download Space Check

All background jobs that download Active Storage blobs (`ProcessHashListJob`, `CountFileLinesJob`, `CalculateMaskComplexityJob`) check available temp storage space before starting the download. If the available space in `Dir.tmpdir` is less than or equal to the blob's size, the job raises `InsufficientTempStorageError` instead of attempting the download.

This check prevents partial downloads that would fill the tmpfs and fail mid-transfer with `Errno::ENOSPC`.

**Retry behavior:** Jobs retry 5 times with increasing delays (polynomial backoff). This handles transient space pressure when multiple jobs are downloading concurrently — as other jobs finish and clean up their temp files, space becomes available.

**Discard behavior:** After 5 failed attempts, the job is discarded and a structured log message is emitted:

```text
[TempStorage] ProcessHashListJob discarded after retries — Not enough temp storage to download wordlist.txt (524288000 bytes required, 104857600 bytes available in /tmp). Action: increase tmpfs size or reduce Sidekiq concurrency. See docs/deployment/docker-storage-and-tmp.md
````

If you see this in logs, either:

1. Increase the tmpfs size (and container memory limit) to accommodate your largest files
2. Reduce Sidekiq concurrency to limit concurrent downloads
3. Switch to the TMPDIR volume approach for disk-backed temp storage

**Step 2: Commit**

```bash
git add docs/deployment/docker-storage-and-tmp.md
git commit -s -m "docs: document pre-download space check behavior for blob jobs"
```
