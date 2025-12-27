---
name: warn-debug-code
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.(rb|rake)$
  - field: new_text
    operator: regex_match
    pattern: (binding\.pry|binding\.irb|debugger|pp\s+|puts\s+['"]debug|puts\s+\w+\.inspect)
---

⚠️ **Debug Code Detected!**

You're adding debugging statements to Ruby code that may be committed.

**Detected patterns:**

- `binding.pry` or `binding.irb` - Interactive debuggers
- `debugger` - Debug breakpoints
- `pp` - Pretty print (often used for debugging)
- `puts "debug"` or `puts variable.inspect` - Debug output

**Why this matters:**

- Debug code shouldn't be committed to version control
- Can expose sensitive data in logs
- Breaks production execution (binding.pry halts the process)
- Clutters output and logs

**Alternatives:**

- Use Rails.logger for intentional logging
- Remove debug statements before committing
- Use `byebug` in test environment only
- Consider structured logging instead

**If intentional:**

- For test helpers: Use Rails.logger.debug instead
- For debugging output: Document why it's needed
- For temporary debugging: Remember to remove before committing
