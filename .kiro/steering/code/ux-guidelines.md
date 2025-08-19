---
inclusion: fileMatch
fileMatchPattern: ['frontend/**/*']
---

## Design Philosophy

- Clear layout using SvelteKit routing and layouts.
- No modal abuse: each form or dialog should feel native to the page.
- Use Shadcn-Svelte components for consistent, accessible UI design.
- Responsive dark mode and keyboard accessibility are required.

## Interactions

- Use JSON API endpoints for data fetching and form submission.
- Display validation errors inline using Svelte component logic and Zod validation.
- Show toast notifications for success/error using `svelte-sonner`.

## Svelte versions

- Use Svelte 5 with runes for all new components and pages.
- Follow idiomatic SvelteKit patterns for routing, layouts, and data loading.

## Component System

- Use **Shadcn-Svelte** and **bits-ui** for accessible, Tailwind-compatible UI components (modals, alerts, dropdowns, tabs, pagination, etc.).
- Use **Tailwind CSS v4** utility classes for layout and spacing.
- Use idiomatic Svelte 5 runes for dynamic interaction (e.g., inline updates, modals, forms).
- Use **formsnap** with **Zod** for form validation and submission.

All forms must be covered by unit tests (Vitest) and E2E tests (Playwright).

### Accessibility and Component Hygiene

- All modals and alerts must use `aria-*` attributes correctly.
- Do not rely on external CDNs — keep all styling local.
- Follow Shadcn-Svelte accessibility patterns and best practices.
