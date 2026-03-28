---
title: PostgreSQL B-tree Index Size Exceeded for Hash Values > 2704 bytes
category: database-issues
date: '2026-03-28'
tags:
  - postgresql
  - indexes
  - hash-items
  - b-tree-limits
  - schema-migration
related_issues:
  - '#789'
components:
  - hash_items table
  - HashItem model
  - ProcessHashListJob
  - CrackSubmissionService
severity: critical
---

# PostgreSQL B-tree Index Size Exceeded for Hash Values > 2704 bytes

## Problem

PostgreSQL INSERT operations on `hash_items` fail when `hash_value` (TEXT column) exceeds ~2704 bytes. Composite B-tree indexes on `hash_value` (e.g., `(hash_value, cracked)`, `(hash_value, hash_list_id)`) cannot accommodate entries that large.

**Error:** `index row size exceeds btree version 4 maximum 2704 for index "index_hash_items_on_hash_value_and_cracked"`

## Root Cause

PostgreSQL B-tree indexes enforce a hard ~2704 byte limit per index entry. The `hash_value` column is TEXT (unbounded) and certain hash algorithms produce values exceeding this limit. Composite indexes that include `hash_value` as a leading key sum their column sizes toward the limit, making overflows more likely.

## Solution

Introduce a fixed-width `hash_value_digest` column (MD5 hex string, 32 chars) as an indexable surrogate for `hash_value`. Index the digest instead of the raw text.

### Migration

```ruby
class AddHashValueDigestToHashItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :hash_items, :hash_value_digest, :string, limit: 32, null: true,
                                                         comment: "MD5 fingerprint of hash_value for B-tree indexing"

    # Batch the backfill to avoid holding a long-running write lock on the entire table.
    loop do
      rows = execute(<<~SQL.squish).cmd_tuples
        UPDATE hash_items SET hash_value_digest = md5(hash_value)
        WHERE id IN (
          SELECT id FROM hash_items WHERE hash_value_digest IS NULL LIMIT 10000
        )
      SQL
      break if rows.zero?
    end

    change_column_null :hash_items, :hash_value_digest, false

    remove_index :hash_items, name: "index_hash_items_on_hash_value_and_cracked", algorithm: :concurrently
    remove_index :hash_items, name: "index_hash_items_on_hash_value_and_hash_list_id", algorithm: :concurrently

    add_index :hash_items, %i[hash_value_digest cracked],
      name: "index_hash_items_on_hash_value_digest_and_cracked", algorithm: :concurrently
    add_index :hash_items, %i[hash_value_digest hash_list_id],
      name: "index_hash_items_on_hash_value_digest_and_hash_list_id", algorithm: :concurrently
  end
end
```

Key points:

- `disable_ddl_transaction!` required for `algorithm: :concurrently`
- Backfill existing rows before removing old indexes
- Column added as nullable first, backfilled, then constrained

### Model Callback (Single-Record Saves)

```ruby
class HashItem < ApplicationRecord
  before_validation :set_hash_value_digest
  validates :hash_value_digest, presence: true

  private

  def set_hash_value_digest
    self.hash_value_digest = Digest::MD5.hexdigest(hash_value) if hash_value.present?
  end
end
```

### Bulk Insert (Inline Digest Computation)

`insert_all`/`upsert_all` bypass ActiveRecord callbacks, so the digest must be computed inline:

```ruby
hash_items << {
  hash_value: line,
  hash_value_digest: Digest::MD5.hexdigest(line),
  hash_list_id: list.id,
  # ...
}
```

### Collision Guard Pattern

MD5 is not collision-resistant. After any digest-based lookup, confirm the full `hash_value` matches:

**Single-row (Ruby-side guard):**

```ruby
digest = Digest::MD5.hexdigest(hash_value)
hash_item = hash_list.hash_items
                     .find_by(hash_value_digest: digest, hash_value: hash_value)
```

**Batch update (SQL-side guard):**

```ruby
HashItem.joins(:hash_list)
        .where(hash_value_digest: hash_item.hash_value_digest, cracked: false)
        .where(hash_value: hash_item.hash_value)  # collision guard
        .where(hash_lists: { hash_type_id: hash_list.hash_type_id })
        .update_all(...)
```

### Why MD5

- **Fixed width:** Always 32 characters (well within B-tree limit)
- **Fast:** No bottleneck in high-throughput ingestion pipelines
- **Collision risk mitigated:** Full-value confirmation guards against (rare) collisions
- **Industry precedent:** Common pattern for digest-based indexing (Git, file integrity tools)

## Prevention

### Rules

1. **Never create B-tree indexes directly on unbounded TEXT columns** -- use a fixed-length digest surrogate
2. **Any new bulk insert path must compute the digest inline** -- `insert_all`/`upsert_all` bypass callbacks
3. **Any digest-based lookup must include a collision guard** -- confirm `hash_value` matches after digest filter
4. **Use `algorithm: :concurrently`** when adding/removing indexes on large tables

### Code Review Checklist

- [ ] New queries on `hash_value` use `hash_value_digest` instead
- [ ] Bulk inserts include `hash_value_digest: Digest::MD5.hexdigest(value)`
- [ ] Digest-based lookups include full-value collision guard
- [ ] New indexes use digest column, not raw TEXT column
- [ ] Migration uses `algorithm: :concurrently` for index operations

## Related

- [GOTCHAS.md -- hash_value_digest Pattern](../../../GOTCHAS.md) (Database & ActiveRecord section)
- [GOTCHAS.md -- upsert_all](../../../GOTCHAS.md) (NOT NULL column requirements)
- [Sidekiq Docker tmp exhaustion](../infrastructure-issues/sidekiq-docker-tmp-exhaustion-and-large-upload-pipeline.md) (related large-file handling)
- GitHub Issue #789
