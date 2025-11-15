# System Tests Guide

## Introduction

System tests provide end-to-end UI testing for the CipherSwarm application. They simulate real user interactions through a browser, ensuring that the entire application stack works together correctly.

### Purpose

- Test complete user workflows from UI interaction to database persistence
- Verify JavaScript interactions (Turbo, Stimulus)
- Validate file uploads and Active Storage integration
- Test authorization and access control
- Ensure UI components render correctly

### When to Write System Tests

Write system tests for:

- Critical user workflows (authentication, resource creation/editing)
- Complex UI interactions (file uploads, nested forms)
- Authorization scenarios
- Navigation flows

Use unit tests or request specs for:

- Business logic validation
- API endpoints
- Model validations
- Service objects

## Setup and Configuration

### Capybara Driver Configuration

The application uses headless Chrome for system tests. Configuration is in `spec/support/capybara.rb`:

- **Driver**: `:headless_chrome` using Selenium WebDriver
- **Server**: Puma (configured in `Capybara.server = :puma`)
- **Wait Time**: 5 seconds default (`Capybara.default_max_wait_time = 5`)
- **Screenshots**: Automatically saved to `tmp/capybara/` on test failures

### Database Cleaning Strategy

System tests use `:truncation` strategy to avoid transaction isolation issues with the separate browser process. Since system tests run in a separate browser process that requires a different database connection, transactions are ineffective. All other test types use `:transaction` strategy for speed.

Configuration is in `spec/support/database_cleaner.rb`.

### Running Tests Locally

```bash
# Run all system tests
bundle exec rspec spec/system

# Run specific test file
bundle exec rspec spec/system/agents/create_agent_spec.rb

# Run with visible browser (for debugging)
HEADLESS=false bundle exec rspec spec/system

# Use just command
just test-system
```

### Running in CI

System tests run automatically in CircleCI. See `.circleci/config.yml` for configuration.

## Writing System Tests

### Basic Test Structure

```ruby
require "rails_helper"

RSpec.describe "Feature name", type: :system do
  let(:user) { create_and_sign_in_user }

  it "does something" do
    visit root_path
    click_button "Submit"
    expect(page).to have_content("Success")
  end
end
```

### Using Page Objects

Page objects encapsulate page interactions for maintainability:

```ruby
let(:agents_page) { AgentsIndexPage.new(page) }

it "creates an agent" do
  agents_page.visit_page
  agents_page.click_new_agent
  # ...
end
```

### Authentication Helpers

Use `SystemHelpers` for common authentication operations:

```ruby
# Sign in a user via UI
sign_in_as(user)

# Create and sign in user
user = create_and_sign_in_user

# Create and sign in admin
admin = create_and_sign_in_admin

# Sign out
sign_out_via_ui(user)
```

### Common Capybara Matchers

```ruby
# Content assertions
expect(page).to have_content("Text")
expect(page).to have_css(".class")
expect(page).to have_link("Link Text")

# Form interactions
fill_in "Field Name", with: "value"
select "Option", from: "Select"
check "Checkbox"
click_button "Submit"

# Navigation
visit path
expect(page).to have_current_path(path)
```

### Waiting for Async Operations

Capybara automatically waits for elements. For custom waits:

```ruby
# Wait for element to appear
expect(page).to have_css(".element", wait: 10)

# Wait for element to disappear
expect(page).to have_no_css(".loading", wait: 5)

# Wait for Turbo Frame to load
expect(page).to have_css("turbo-frame#content")
```

### Testing File Uploads

```ruby
file_path = Rails.root.join("spec/fixtures/file.txt")
attach_file "File", file_path

# Wait for Active Storage direct upload
expect(page).to have_no_css(".direct-upload--pending", wait: 10)
```

### Testing JavaScript Interactions

System tests run with JavaScript enabled by default. Turbo and Stimulus interactions work automatically:

```ruby
# Click Turbo link
click_link "Link"

# Wait for Turbo Frame update
expect(page).to have_css("turbo-frame#updated")
```

### Handling Browser Dialogs

```ruby
# Accept confirmation dialog
accept_confirm do
  click_button "Delete"
end

# Dismiss confirmation dialog
dismiss_confirm do
  click_button "Cancel"
end
```

## Page Object Pattern

### What are Page Objects?

Page objects encapsulate page-specific interactions, making tests more maintainable and readable.

### Creating New Page Objects

All page objects inherit from `BasePage`:

```ruby
class MyPage < BasePage
  def visit_page
    visit my_path
    self
  end

  def do_something
    click_button "Button"
    self
  end
end
```

### Naming Conventions

- Page objects: `ResourceNamePage` (e.g., `AgentsIndexPage`)
- Files: `spec/support/page_objects/resource_name_page.rb`
- Methods: Use descriptive action names (`click_new_agent`, `fill_name`)

### Example Page Object

```ruby
class AgentsIndexPage < BasePage
  def visit_page
    visit agents_path
    self
  end

  def click_new_agent
    click_link "New Agent"
    self
  end

  def has_agent?(name)
    has_content?(name)
  end
end
```

## Best Practices

### Keep Tests Focused

Each test should verify one specific behavior:

```ruby
# Good
it "creates agent with valid data" do
  # ...
end

# Bad
it "creates, edits, and deletes agent" do
  # ...
end
```

### Use Factories for Test Data

```ruby
let(:user) { create(:user) }
let(:project) { create(:project) }
```

### Avoid Sleep Statements

Use Capybara's built-in waiting:

```ruby
# Good
expect(page).to have_content("Loaded", wait: 10)

# Bad
sleep 5
```

### Test User Workflows, Not Implementation

Focus on what users do, not how it's implemented:

```ruby
# Good - tests user action
click_button "Submit"
expect(page).to have_content("Success")

# Bad - tests implementation detail
expect(Agent.count).to eq(1)
```

### Handle Authorization

Test both authorized and unauthorized access:

```ruby
it "prevents unauthorized access" do
  visit protected_path
  expect(page).to have_content("not authorized")
end
```

### Debugging Failed Tests

1. **Screenshots**: Automatically saved to `tmp/capybara/` on failure
2. **Logs**: Check `log/test.log` for errors
3. **Visible Browser**: Run with `HEADLESS=false` to see what's happening
4. **Console Output**: Use `puts` or `save_and_open_page` for debugging

## Running Tests

### Run All System Tests

```bash
bundle exec rspec spec/system
```

### Run Specific Test Directory

```bash
bundle exec rspec spec/system/agents
```

### Run Single Test File

```bash
bundle exec rspec spec/system/agents/create_agent_spec.rb
```

### Run with Visible Browser

```bash
HEADLESS=false bundle exec rspec spec/system
```

### Use Just Commands

```bash
just test-system
```

## Troubleshooting

### Common Issues

**Chrome/Chromedriver version mismatch**

- Ensure Chrome and Chromedriver versions match
- Update webdrivers gem: `bundle update webdrivers`

**Timeout errors**

- Increase wait time: `expect(page).to have_content("Text", wait: 10)`
- Check for JavaScript errors in browser console

**Database state issues**

- Ensure Database Cleaner is configured correctly
- Check that system tests use `:truncation` strategy

**Flaky tests**

- Add explicit waits for async operations
- Use `have_no_css` to wait for loading states to disappear
- Check for race conditions in test setup

### Screenshot Location

Screenshots are saved to `tmp/capybara/` with filenames like: `FAILURE_test_description_20240101-120000.png`

## Examples

### Complete Example: Testing Agent Creation

```ruby
require "rails_helper"

RSpec.describe "Create agent", type: :system do
  let(:user) { create_and_sign_in_user }
  let(:agents_page) { AgentsIndexPage.new(page) }
  let(:agent_form) { AgentFormPage.new(page) }

  it "creates a new agent" do
    agents_page.visit_page
    agents_page.click_new_agent

    agent_form.fill_custom_label("Test Agent")
    agent_form.toggle_enabled
    agent_form.submit_form

    expect(page).to have_current_path(agents_path)
    expect_flash_message("Agent was successfully created")
    expect(agents_page).to have_agent?("Test Agent")
  end
end
```

### Complete Example: Testing File Upload

```ruby
require "rails_helper"

RSpec.describe "Create hash list", type: :system do
  let(:user) { create_and_sign_in_user }
  let(:file_path) { Rails.root.join("spec/fixtures/hash_lists/example_hashes.txt") }

  it "uploads file and creates hash list" do
    visit new_hash_list_path

    fill_in "Name", with: "Test Hash List"
    attach_file "File", file_path
    expect(page).to have_no_css(".direct-upload--pending", wait: 10)
    click_button "Submit"

    expect(page).to have_content("Test Hash List")
  end
end
```

## Resources

- [Capybara Documentation](https://rubydoc.info/github/teamcapybara/capybara)
- [RSpec System Test Guide](https://rspec.info/documentation/latest/rspec-rails/RSpec/Rails/SystemExampleGroup.html)
- [Page Object Pattern](https://martinfowler.com/bliki/PageObject.html)
- [CI/CD Integration](.circleci/config.yml)
