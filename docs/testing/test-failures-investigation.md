# System Test Failures Investigation

## Summary

30 system tests are currently failing. This document outlines the main categories of failures and proposed fixes.

## Failure Categories

### 1. Form Submit Button Issues

**Affected Tests:**

- `spec/system/agents/create_agent_spec.rb` (multiple)
- `spec/system/errors/error_pages_spec.rb` (multiple)
- `spec/system/campaigns/create_campaign_spec.rb` (multiple)

**Issue:** `first("button[type='submit']")` is not finding submit buttons.

**Root Cause:** Simple Form's `f.button :submit` may generate buttons differently, or buttons may not be visible/rendered when the selector runs.

**Proposed Fix:**

- Use `click_button` with button text (Simple Form generates text like "Create Agent", "Update Agent", "Submit")
- Or use `find("input[type='submit']")` if Simple Form generates input elements
- Or use `find("button.btn-primary")` to match by class

### 2. Form Field Label Mismatches

**Affected Tests:**

- `spec/system/campaigns/create_campaign_spec.rb`

**Issue:** `fill_in "Name"` cannot find the field.

**Root Cause:** Simple Form may generate different labels, or the form may not be fully loaded.

**Proposed Fix:**

- Check actual form labels in rendered HTML
- Use field IDs or names instead of labels
- Wait for form to be visible before interacting

### 3. Sidebar Navigation Link Issues

**Affected Tests:**

- `spec/system/navigation/sidebar_navigation_spec.rb` (multiple)

**Issue:** `have_link(href: root_path)` cannot find links.

**Root Cause:** The `sidebar_link` helper generates links with icons, and Capybara may not match hrefs correctly, or links may be inside Turbo frames.

**Proposed Fix:**

- Use `find("a[href='#{root_path}']")` instead of `have_link(href: ...)`
- Check if links are inside Turbo frames that need to be scoped
- Use text-based matching if href matching fails

### 4. Agent Row Finding Issues

**Affected Tests:**

- `spec/system/agents/delete_agent_spec.rb` (multiple)
- `spec/system/agents/edit_agent_spec.rb` (multiple)

**Issue:** `agent_row(agent_name)` cannot find `tbody tr` elements.

**Root Cause:**

- Agents table may be empty
- Table structure may be different
- Turbo may not have loaded the content yet

**Proposed Fix:**

- Wait for table to be visible
- Check if agents are actually created before trying to find rows
- Use more flexible selectors

### 5. Hash List Table Issues

**Affected Tests:**

- `spec/system/hash_lists/view_hash_list_file_spec.rb`

**Issue:** `have_table` cannot find table.

**Root Cause:** Table only renders when `@hash_items.any?` is true. If no hash items exist, table won't be present.

**Proposed Fix:**

- Create hash items in test setup
- Or check for table conditionally
- Or test for "No hash items found" message instead

### 6. Campaign Attack Form Issues

**Affected Tests:**

- `spec/system/campaigns/add_attack_to_campaign_spec.rb` (multiple)

**Issue:** `find("a[href*='attack_mode=dictionary'][title='Add Dictionary Attack']")` fails with invalid option error.

**Root Cause:** The `title` attribute selector syntax may be incorrect, or the links may not have title attributes as expected.

**Proposed Fix:**

- Use CSS attribute selector: `find("a[href*='attack_mode=dictionary'][title='Add Dictionary Attack']")`
- Or use XPath if CSS selectors don't work
- Or find by href and then check title

### 7. Admin User Management Issues

**Affected Tests:**

- `spec/system/admin/manage_users_spec.rb` (lock/unlock user)

**Issue:** Cannot find lock/unlock buttons by ID.

**Root Cause:**

- Buttons may be inside forms that need special handling
- IDs may not match expected pattern
- Buttons may be disabled or hidden

**Proposed Fix:**

- Check actual button structure in rendered HTML
- Use form action paths to find buttons
- Handle Turbo form submissions correctly

## Next Steps

1. **Investigate Simple Form button generation** - Check what HTML Simple Form actually generates
2. **Add proper waits** - Ensure elements are visible before interacting
3. **Fix selectors** - Use more robust selectors that match actual HTML structure
4. **Handle Turbo** - Ensure tests work with Turbo Drive/Frame
5. **Create test data** - Ensure all required test data exists before assertions
