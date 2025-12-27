---
name: prevent-manual-migrations
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: db/migrate/\d+_.+\.rb$
---

🚫 **Manual Migration File Creation Blocked!**

You're attempting to create a migration file manually, which violates CipherSwarm project standards.

**Why this matters:**

- Manual migrations can have incorrect timestamps
- Risk of duplicate version numbers
- Bypasses Rails migration conventions
- Can cause merge conflicts

**Required approach:** Use Rails generators instead:

```bash
# Using justfile (recommended)
just db-migration MigrationName

# Or directly with Rails
bin/rails generate migration MigrationName

# For model migrations
bin/rails generate migration AddFieldToModel field:type
```

**Example:**

```bash
just db-migration AddStatusToAgents status:integer
```

This ensures proper timestamp generation and Rails conventions.
