# Phase 3 Step 2: Core Functionality Verification & Completion

**🎯 Foundation Verification Step** - This step verifies existing implementations work with authentication and completes core user management features that were identified as incomplete.

## 📋 Overview

With authentication implemented in [Step 1](./phase-3-step-1.md), this step focuses on verifying all existing implementations work correctly with authenticated APIs and completing the core user management functionality that currently has empty placeholder files.

**🔑 Critical Context Notes:**

- **Verification Focus**: All existing SvelteKit components and SSR load functions must work with authenticated API calls
- **User Management Gap**: Files `frontend/e2e/settings.test.ts` and `frontend/e2e/users.test.ts` are currently empty placeholders
- **Missing Routes**: User detail (`/users/[id]`) and deletion (`/users/[id]/delete`) pages need implementation
- **Project Context**: Project switching functionality affects all data visibility and requires proper context management
- **Role-Based Access**: UI must distinguish between admin-only and user functions with proper permission enforcement. Permissions must be enforced in the backend (using `casbin` in `app/core/authz.py`) and frontend (within the SvelteKit server load functions).
- **Testing Strategy**: Both Mock tests (UI behavior) and E2E tests (authentication flows) required for each feature; tests should be identical in functionality tested.
- **Component Architecture**: Uses Shadcn-Svelte components with Superforms for form handling and SvelteKit actions

## ✅ Verification Tasks (Existing Implementations)

Each of the following elements have been implemented in some capacity and with varying degrees of completeness. The goal of this step is to verify that the existing implementations work correctly with authentication and are consistent with the project's architecture and standards. Ensure idiomatic Shadcn-Svelte components are used for all UI elements. Ensure that SvelteKit 5 patterns are used for client-side and server-side code. Maximize code reuse and consistency across the application.

### Dashboard & Layout Verification

- [ ] **VERIFY-001**: Dashboard SSR functionality with authentication
  - [ ] Verify dashboard loads with authenticated API calls (`DRM-001a`)
  - [ ] Verify dashboard cards display correct real-time data (`DRM-001b`)
  - [ ] Verify error handling for failed dashboard API calls (`DRM-001c`)
  - [ ] Verify loading states during data fetch (`DRM-001d`)
  - [ ] Verify empty state handling (no campaigns, no agents) (`DRM-001e`)

- [ ] **VERIFY-002**: Layout and navigation verification
  - [ ] Verify sidebar navigation between main sections (`DRM-003a`)
  - [ ] Verify dashboard card click-through to detail views (`DRM-003b`)
  - [ ] Verify breadcrumb navigation consistency (`DRM-003c`)
  - [ ] Verify deep linking to dashboard sections (`DRM-003d`)
  - [ ] Verify responsive sidebar behavior (`UIX-001a`)

### Campaign Management Verification

- [ ] **VERIFY-003**: Campaign list functionality with authentication
  - [ ] Verify campaign list page loads with SSR data (`CAM-002a`)
  - [ ] Verify campaign pagination and search functionality (`CAM-002b`)
  - [ ] Verify campaign filtering by status (running, completed, paused) (`CAM-002c`)
  - [ ] Verify campaign sorting by various columns (`CAM-002d`)
  - [ ] Verify campaign detail view navigation (`CAM-002e`)

- [ ] **VERIFY-004**: Campaign details functionality
  - [ ] Verify campaign detail page loads with attack list (`CAM-003a`)
  - [ ] Verify campaign progress tracking and metrics display (`CAM-003b`)
  - [ ] Verify real-time campaign status updates (`CAM-003e`)
  - [ ] Verify campaign attack summary display (`CAM-003g`)

### Attack Management Verification

- [ ] **VERIFY-005**: Attack configuration functionality
  - [ ] Verify attack type selection and switching (`ATT-002a`)
  - [ ] Verify resource selection (searchable dropdowns) (`ATT-002b`)
  - [ ] Verify attack parameter validation (`ATT-002c`)
  - [ ] Verify keyspace estimation and complexity calculation (`ATT-002d`)
  - [ ] Verify attack preview and summary (`ATT-002e`)

### Resource Management Verification

- [ ] **VERIFY-006**: Resource list and detail functionality
  - [ ] Verify resource list page loads with SSR data (`RES-001a`)
  - [ ] Verify resource filtering by type (`RES-001b`)
  - [ ] Verify resource search functionality (`RES-001c`)
  - [ ] Verify resource pagination with large datasets (`RES-001d`)
  - [ ] Verify resource detail view navigation (`RES-001e`)
  - [ ] Verify resource preview for supported file types (`RES-003a`)

### Agent Management Verification

- [ ] **VERIFY-007**: Agent list and details functionality
  - [ ] Verify agent list page loads with real-time status (`AGT-001a`)
  - [ ] Verify agent filtering by status (online, offline, error) (`AGT-001b`)
  - [ ] Verify agent search and sorting functionality (`AGT-001c`)
  - [ ] Verify agent performance metrics display (`AGT-001d`)
  - [ ] Verify agent health monitoring and alerts (`AGT-001e`)

## 🔧 User Management Implementation (Critical Gap)

### Complete Empty Placeholder Files

**🔧 Technical Context**: These test files are completely empty and need full implementation. Settings involves self-service profile management (name, email, password), while users involves admin-controlled role assignment and project membership. All forms must use idiomatic Shadcn-Svelte components.

- [ ] **USER-001**: Implement `frontend/e2e/settings.test.ts` (currently empty)
  - [ ] User profile editing (self-service name and email updates) (`USR-003a`)
  - [ ] Password change functionality with immediate confirmation (`USR-003b`)
  - [ ] User preferences and settings (`USR-003c`)
  - [ ] API key generation and management (`USR-003d`)
  - [ ] Activity history and audit logs (`USR-003e`)

- [ ] **USER-002**: Implement `frontend/e2e/users.test.ts` (admin-only) (currently empty)
  - [ ] User list page with role-based visibility (`USR-001a`)
  - [ ] New user creation form (`USR-001b`)
  - [ ] User role assignment and validation (`USR-001c`)
  - [ ] User project association management (`USR-001d`)
  - [ ] User deletion with cascade handling (`USR-001e`)

### User Detail and Deletion Pages Implementation

- [ ] **USER-003**: Create user detail pages (`/users/[id]/+page.svelte`)
  - [ ] User detail page loads with complete profile information (`USR-004a`)
  - [ ] User profile editing and updates (`USR-004b`)
  - [ ] User role management and project associations (`USR-004c`)
  - [ ] User activity history and audit trails (`USR-004d`)
  - [ ] User permission validation and enforcement (`USR-004e`)
  - [ ] User profile form validation and error handling (`USR-004f`)

- [ ] **USER-004**: Create user deletion flow (admin-only) (`/users/[id]/delete/+page.svelte`)
  - [ ] User deletion page loads with impact assessment (`USR-005a`)
  - [ ] Display of user's associated campaigns, attacks, and resources (`USR-005b`)
  - [ ] Warning messages for active user sessions (`USR-005c`)
  - [ ] Confirmation workflow with typed verification (`USR-005d`)
  - [ ] Cascade deletion options and warnings (`USR-005e`)
  - [ ] User deletion permission validation (`USR-005f`)

### Project Management Completion

- [ ] **PROJECT-001**: Complete project management functionality (admin-only)
  - [ ] Project creation form (admin only) (`USR-002b`)
  - [ ] Project user management (`USR-002c`)
  - [ ] Project settings and configuration (`USR-002d`)
  - [ ] Project deletion with impact assessment (`USR-002e`)

### Project Selection & Switching Implementation

- [ ] **PROJECT-002**: Implement project selection and switching
  - [ ] Single project auto-selection on login (store last selected project in browser local storage, prompt if no project selected) (`ASM-002a`)
  - [ ] Multi-project selection modal on login (`ASM-002b`)
  - [ ] Project switching via global project selector (`ASM-002c`)
  - [ ] Project context persistence across navigation (`ASM-002d`)
  - [ ] Project-scoped data visibility validation (`ASM-002e`)
  - [ ] Project context awareness in all UI elements (`ASM-002f`)
  - [ ] Project-based resource filtering and access control (`ASM-002g`)

## 🧪 Core Functionality Test Implementation

Create or update tests to cover the following functionality. All user-facing functionality must have E2E tests, both mocked and full E2E. If the the note below includes a notation like (E2E, referring to the full E2E tests) or (Mock, referring to the mocked E2E tests), then the test must be created or updated to cover the functionality and confirm that the functionality works as expected. Strictly follow the existing test structure and naming conventions, as as described in the [full testing architecture](../side_quests/full_testing_architecture.md) document. Refer to `.cursor/rules/testing/e2e-docker-infrastructure.mdc` and `.cursor/rules/testing/testing-patterns.mdc` for more details.

Be sure to use or reuse the existing test utils and helpers in `frontend/tests/test-utils.ts`.

### User Management Testing

- [ ] **TEST-USR-001**: User Management Tests
  - [ ] **USR-001a**: User list page with role-based visibility (E2E + Mock)
  - [ ] **USR-001b**: New user creation form (E2E + Mock)
  - [ ] **USR-001c**: User role assignment and validation (E2E + Mock)
  - [ ] **USR-001d**: User project association management (E2E + Mock)
  - [ ] **USR-001e**: User deletion with cascade handling (E2E + Mock)
  - [ ] **USR-001f**: Clear permission boundaries in UI (Mock)
  - [ ] **USR-001g**: Role-based UI element separation (Mock)

- [ ] **TEST-USR-003**: Profile & Settings Tests
  - [ ] **USR-003a**: User profile editing (self-service updates) (E2E + Mock)
  - [ ] **USR-003b**: Password change functionality (E2E + Mock)
  - [ ] **USR-003c**: User preferences and settings (E2E + Mock)
  - [ ] **USR-003d**: API key generation and management (E2E + Mock)
  - [ ] **USR-003e**: Activity history and audit logs (E2E + Mock)
  - [ ] **USR-003f**: Profile change validation and feedback (Mock)
  - [ ] **USR-003g**: Self-service vs admin function distinction (Mock)

### Project Management Testing

- [ ] **TEST-USR-002**: Project Management Tests
  - [ ] **USR-002a**: Project list page with membership info (E2E + Mock)
  - [ ] **USR-002b**: Project creation form (admin only) (E2E + Mock)
  - [ ] **USR-002c**: Project user management (E2E + Mock)
  - [ ] **USR-002d**: Project settings and configuration (E2E + Mock)
  - [ ] **USR-002e**: Project deletion with impact assessment (E2E + Mock)

- [ ] **TEST-ASM-002**: Project Selection & Switching Tests
  - [ ] **ASM-002a**: Single project auto-selection on login (E2E)
  - [ ] **ASM-002b**: Multi-project selection modal on login (E2E)
  - [ ] **ASM-002c**: Project switching via global selector (E2E + Mock)
  - [ ] **ASM-002d**: Project context persistence across navigation (E2E)
  - [ ] **ASM-002e**: Project-scoped data visibility validation (E2E)
  - [ ] **ASM-002f**: Project context awareness in UI elements (Mock)
  - [ ] **ASM-002g**: Project-based resource filtering and access control (E2E)

### Dashboard and Navigation Testing

- [ ] **TEST-DRM-001**: Dashboard Data Loading Tests
  - [ ] **DRM-001a**: Dashboard loads with SSR data (E2E + Mock)
  - [ ] **DRM-001b**: Dashboard cards display correct real-time data (E2E + Mock)
  - [ ] **DRM-001c**: Error handling for failed dashboard API calls (Mock)
  - [ ] **DRM-001d**: Loading states during data fetch (Mock)
  - [ ] **DRM-001e**: Empty state handling (no campaigns, no agents) (Mock)

- [ ] **TEST-DRM-003**: Dashboard Navigation Tests
  - [ ] **DRM-003a**: Sidebar navigation between main sections (E2E + Mock)
  - [ ] **DRM-003b**: Dashboard card click-through to detail views (E2E + Mock)
  - [ ] **DRM-003c**: Breadcrumb navigation consistency (Mock)
  - [ ] **DRM-003d**: Deep linking to dashboard sections (E2E)
  - [ ] **DRM-003e**: Mobile responsive navigation (Mock)

### Form Behavior Testing

- [ ] **TEST-UIX-002**: Form Behavior Tests
  - [ ] **UIX-002a**: Form validation and error display (Mock)
  - [ ] **UIX-002b**: Progressive enhancement (JS disabled) (E2E)
  - [ ] **UIX-002c**: Form persistence during navigation (E2E)
  - [ ] **UIX-002d**: Multi-step form navigation (Mock)
  - [ ] **UIX-002e**: Form submission loading states (Mock)
  - [ ] **UIX-002f**: Server-side validation with error reporting (E2E)
  - [ ] **UIX-002g**: Superforms integration consistency (Mock)

## 🔒 Basic Access Control Implementation

### Role-Based Access Control Foundation

- [ ] **ACCESS-001**: Implement basic RBAC UI patterns
  - [ ] Admin-only functionality restrictions (`ACS-001a`)
  - [ ] Project admin scope limitations (`ACS-001b`)
  - [ ] Regular user permission enforcement (`ACS-001c`)
  - [ ] Cross-project access prevention (`ACS-001d`)
  - [ ] Role-based menu and action visibility

### Access Control Testing

- [ ] **TEST-ACS-001**: Role-Based Access Control Tests
  - [ ] **ACS-001a**: Admin-only functionality restrictions (E2E + Mock)
  - [ ] **ACS-001b**: Project admin scope limitations (E2E + Mock)
  - [ ] **ACS-001c**: Regular user permission enforcement (E2E + Mock)
  - [ ] **ACS-001d**: Cross-project access prevention (E2E)

## 🎯 UI Polish Tasks

### Layout and Responsive Design

- [ ] **POLISH-001**: Complete layout implementation
  - [ ] Modal overlay and z-index management (`UIX-001d`)
  - [ ] Mobile navigation menu (`UIX-001b`)
  - [ ] Responsive design validation across viewports

### Theme Implementation

- [ ] **POLISH-002**: Complete theme system
  - [ ] Dark mode toggle functionality (`UIX-001e`)
  - [ ] Theme switching without page refresh (`UIX-004b`)
  - [ ] Theme preference persistence across sessions (`UIX-004c`)
  - [ ] Catppuccin Macchiato theme consistency (`UIX-004d`)
  - [ ] System theme detection and auto-switching (`UIX-004f`)

## 🔍 Validation & Success Criteria

### Core Functionality Validation

- [ ] **VALIDATE-001**: All existing features work with authentication
  - [ ] Dashboard loads and displays data correctly
  - [ ] Campaign, attack, resource, and agent management functional
  - [ ] Forms submit successfully with proper validation
  - [ ] Navigation works across all sections

### User Management Validation

- [ ] **VALIDATE-002**: User management is fully functional
  - [ ] Empty test files are now implemented and passing
  - [ ] User creation, editing, and deletion workflows complete
  - [ ] Project selection and switching works properly
  - [ ] Role-based access control functions correctly

### Test Coverage Validation

- [ ] **VALIDATE-003**: Test coverage is comprehensive
  - [ ] All core functionality has both Mock and E2E tests where applicable
  - [ ] Test environment detection works properly
  - [ ] All tests pass in both Mock and E2E environments
  - [ ] Performance is acceptable for core workflows

## 📝 Implementation Notes

### Key Implementation Patterns

- **Component Architecture**: Use idiomatic Shadcn-Svelte components with proper composition and accessibility
- **SvelteKit Patterns**: Follow idiomatic SvelteKit 5 patterns with runes ($state, $derived, $effect), actions, and load functions
- **Form Handling**: All forms use Superforms v2 with SvelteKit actions, Zod validation, and Shadcn-Svelte form components
- **SSR Load Functions**: Located in `+page.server.ts` files, handle authenticated API calls and error states
- **Role-Based UI**: Use `$page.data.user.role` for conditional rendering of admin-only features
- **Project Context**: Access via `$page.data.project` and update with project switching functionality
- **Error Handling**: 401 redirects to login, 404 shows error page, 500 logs and shows generic error
- **Environment Detection**: Check `PLAYWRIGHT_TEST` or `NODE_ENV=test` for mock data fallbacks
- **E2E Testing Structure**: `frontend/e2e/` contains mocked E2E tests (fast, no backend), `frontend/tests/e2e/` contains full E2E tests (slower, real backend). Configs: `playwright.config.ts` (mocked) vs `playwright.config.e2e.ts` (full backend)

### Priority Focus

This step prioritizes:

1. Verifying existing implementations work with authentication
2. Completing the user management gap (empty test files)
3. Implementing basic access control patterns
4. Establishing solid test coverage for core features

### Test Implementation Strategy

- Mock tests focus on UI behavior and validation
- E2E tests focus on authentication flows and data persistence
- Both test types should be implemented for critical user workflows
- Environment detection ensures tests work in all scenarios

### User Management Context

User management was identified as a major gap with empty placeholder files. This step completes:

- Settings page functionality (`settings.test.ts`)
- User management workflows (`users.test.ts`)
- User detail and deletion pages
- Project selection and switching

## 🎯 Completion Definition

This step is complete when:

1. All existing implementations verified to work with authentication
2. User management functionality fully implemented and tested
3. Basic access control patterns implemented across the application
4. Core functionality test coverage is comprehensive (Mock + E2E)
5. Theme system and responsive design are functional
6. All validation criteria pass without errors
