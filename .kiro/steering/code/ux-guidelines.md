---
inclusion: fileMatch
fileMatchPattern:
  - app/views/**/*
  - app/components/**/*
---

## Design Philosophy

- No modal abuse: each form or dialog should feel native to the page.
- Use ViewComponent with Tailwind CSS for consistent, accessible UI design.
- Responsive dark mode and keyboard accessibility are required.
- Theme: Catppuccin Macchiato base with DarkViolet accent (#9400D3).

## Interactions

- Use Hotwire (Turbo 8 + Stimulus 3.2+) for dynamic interactions without full page reloads.
- Use Turbo Frames for inline content updates and Turbo Streams for real-time updates.
- Display validation errors inline using Rails form helpers and server-side validation.
- Show flash messages for success/error using Rails flash with Turbo integration.
- Use ActionCable channels for real-time updates when needed.

## Rails & Hotwire Architecture

- Use Rails 8.0+ with Hotwire (Turbo 8 + Stimulus 3.2+) for frontend interactions.
- Follow idiomatic Rails patterns for routing, controllers, and view rendering.
- Use Turbo Drive for navigation, Turbo Frames for partial updates, Turbo Streams for live updates.
- Write Stimulus controllers for client-side behavior that can't be handled by Turbo.

## Component System

- Use **ViewComponent 4.0+** for reusable UI components (modals, alerts, dropdowns, tabs, pagination, etc.).
- Use **Tailwind CSS v4** utility classes for layout and styling via tailwindcss-rails gem.
- Keep components focused and single-purpose with proper initialization patterns.
- Use **Rails form helpers** with server-side validation for form handling.
- Integrate forms with Turbo for async submission without JavaScript frameworks.

All forms must be covered by RSpec system tests with Capybara.

## Testing Requirements

- Write comprehensive RSpec system tests for user workflows using Capybara.
- Test both happy paths and edge cases for all user interactions.
- Use FactoryBot for test data generation.
- Maintain 90%+ code coverage with SimpleCov.
- Test real-time features with ActionCable test helpers.

## Accessibility and Component Hygiene

- All interactive elements must use proper `aria-*` attributes for screen readers.
- Ensure WCAG 2.1 AA compliance with keyboard navigation support.
- Do not rely on external CDNs - keep all assets local via Propshaft.
- Follow Rails and Hotwire accessibility best practices.
- Test with keyboard navigation and screen readers during development.
