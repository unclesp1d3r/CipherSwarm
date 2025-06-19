# Phase 3 Step 1: SSR Authentication Foundation

**🎯 Critical Foundation Step** - This step implements the core authentication infrastructure required for all subsequent testing and functionality. Nothing else can be fully validated until this is complete.

## 📋 Overview

This step addresses the critical blocker preventing full E2E testing: implementing SSR-compatible authentication for SvelteKit with FastAPI backend integration. All load functions require authenticated API calls, and the current architecture lacks session management.

**🔑 Critical Context Notes:**

- **Architecture**: SvelteKit SSR frontend (port 5173) + FastAPI backend (port 8000) as separate services
- **Current State**: All SSR load functions (`+page.server.ts`) make API calls but fail with 401 due to missing session handling
- **Authentication Flow**: Adapts existing FastAPI JWT implementation for SSR - JWT tokens stored in HTTP-only cookies, forwarded from SvelteKit to FastAPI
- **Environment Detection**: Load functions check `PLAYWRIGHT_TEST` or `NODE_ENV=test` to return mock data during testing
- **Docker E2E**: Infrastructure complete but requires authentication to enable full backend integration testing
- **Testing Pattern**: Layer 2 (frontend mocked) works, Layer 3 (full E2E) blocked by authentication requirement

## 🔧 Backend Authentication Tasks

### Backend Session Management Implementation

**🔧 Technical Context**: Adapt existing FastAPI JWT authentication for SSR compatibility. JWT tokens stored in HTTP-only cookies instead of localStorage, allowing server-side API calls.

- [x] **AUTH-BE-001**: Modify existing JWT authentication to support HTTP-only cookies
      - [x] Create `/api/v1/web/auth/login` endpoint that returns JWT in HTTP-only cookie
  - [x] Create `/api/v1/web/auth/logout` endpoint that clears JWT cookie
  - [x] Modify JWT middleware to accept tokens from cookies AND Authorization headers
    - [x] Update existing JWT validation to extract tokens from cookies
  - [x] Configure proper CORS settings for SvelteKit frontend cookie handling

- [x] **AUTH-BE-002**: JWT token refresh and validation
  - [x] Implement JWT token refresh mechanism
  - [x] Update existing JWT validation middleware for cookie extraction
  - [x] Implement proper token expiration handling
  - [x] Add token refresh capabilities for long-lived sessions

- [x] **AUTH-BE-003**: Health check endpoint updates
  - [x] Ensure `/api-info` endpoint remains unauthenticated for Docker health checks
  - [x] Create authenticated health endpoint for internal monitoring
  - [x] Update Docker health check configuration if needed

### Backend CORS and Security Configuration

- [x] **AUTH-BE-004**: CORS configuration for SvelteKit SSR
  - [x] Configure CORS to accept cookies from SvelteKit frontend
  - [x] Set appropriate `Access-Control-Allow-Credentials` headers
  - [x] Update allowed origins for development and production environments

## 🌐 Frontend SSR Authentication Tasks

### SvelteKit Hooks Implementation

**🔧 Technical Context**: SvelteKit hooks extract JWT cookies from requests and set `event.locals.user` for use in load functions. Must handle JWT validation and automatic login redirect.

- [x] **AUTH-FE-001**: Create `hooks.server.js` for JWT cookie handling
      - [x] Implement JWT cookie extraction from requests
  - [x] Create user context setting for load functions (`event.locals.user`)
    - [x] Add JWT validation and refresh logic
      - [x] Implement automatic redirect to login for expired tokens

### Server-Side API Client

- [ ] **AUTH-FE-002**: Create authenticated server-side API client
  - [ ] Implement `ServerApiClient` class with JWT cookie authentication
  - [ ] Add JWT cookie forwarding as Authorization headers for backend requests
  - [ ] Implement proper error handling for 401/403 responses
  - [ ] Create utility functions for common authenticated requests

### Login/Logout Route Implementation

- [ ] **AUTH-FE-003**: Implement login page with idiomatic SvelteKit actions
  - [ ] Create `/login/+page.svelte` using idiomatic Shadcn-Svelte login components
  - [ ] Implement login form action in `/login/+page.server.ts` with Superforms integration
  - [ ] Add JWT cookie setting from FastAPI response
  - [ ] Implement redirect logic after successful login using SvelteKit patterns

- [ ] **AUTH-FE-004**: Implement logout functionality
  - [ ] Create logout action accessible from layout
  - [ ] Implement JWT cookie cleanup and removal
  - [ ] Add confirmation handling for logout process
  - [ ] Ensure proper redirect after logout

### Load Function Authentication Updates

- [ ] **AUTH-FE-005**: Update all `+page.server.ts` files for authentication
  - [ ] Update dashboard load function (`/+page.server.ts`)
  - [ ] Update campaigns load functions (`/campaigns/+page.server.ts`, `/campaigns/[id]/+page.server.ts`)
  - [ ] Update attacks load function (`/attacks/+page.server.ts`)
  - [ ] Update agents load function (`/agents/+page.server.ts`)
  - [ ] Update resources load functions (`/resources/+page.server.ts`, `/resources/[id]/+page.server.ts`)
  - [ ] Update users load function (`/users/+page.server.ts`)
  - [ ] Update projects load function (`/projects/+page.server.ts`)
  - [ ] Update settings load function (`/settings/+page.server.ts`)

### Environment Detection for Testing

- [x] **AUTH-FE-006**: Implement test environment authentication bypass
  - [x] Add environment detection in load functions (`PLAYWRIGHT_TEST`, `NODE_ENV=test`)
  - [x] Create mock data fallbacks for test scenarios
  - [x] Ensure test data matches production API response structure
  - [x] Implement clean switching between test and production modes

## 🧪 Test Implementation

### Authentication Flow Tests (Critical)

- [ ] **TEST-ASM-001**: Login Flow Testing
  - [ ] **ASM-001a**: Successful login with valid credentials (E2E + Mock)
  - [ ] **ASM-001b**: Failed login with invalid credentials (E2E + Mock)
  - [ ] **ASM-001c**: Login form validation errors (Mock)
  - [ ] **ASM-001d**: JWT persistence across page refreshes (E2E)
  - [ ] **ASM-001e**: Redirect to login when accessing protected routes unauthenticated (E2E)
  - [ ] **ASM-001f**: Login loading states and error display (Mock)

- [ ] **TEST-ASM-003**: JWT Token Management Testing
  - [ ] **ASM-003a**: JWT expiration handling with redirect (E2E)
  - [ ] **ASM-003b**: Token refresh on API calls (E2E)
  - [ ] **ASM-003c**: Logout functionality with JWT cleanup (E2E + Mock)
  - [ ] **ASM-003d**: JWT expiry redirect to login (E2E)

### Load Function Authentication Tests

- [ ] **TEST-AUTH-LOAD**: SSR Load Function Authentication
  - [ ] Test authenticated data loading for dashboard (E2E)
  - [ ] Test authenticated data loading for campaigns (E2E)
  - [ ] Test authenticated data loading for resources (E2E)
  - [ ] Test 401 handling and redirect to login (E2E)
  - [ ] Test environment detection and mock data fallback (Mock)

## 🐳 Docker Infrastructure Updates

### E2E Testing Infrastructure

- [ ] **DOCKER-001**: Update E2E Docker environment for authentication
  - [ ] Update data seeding script to create test users with known credentials
  - [ ] Modify Playwright global setup to handle login flow
  - [ ] Update health check configuration for authenticated services
  - [ ] Ensure JWT cookie handling works in Docker environment

### Development Environment

- [ ] **DOCKER-002**: Update development Docker configuration
  - [ ] Ensure JWT handling works in development environment
  - [ ] Update hot reload configuration for authentication changes
  - [ ] Verify CORS settings work between services in Docker

## 🔍 Validation & Success Criteria

### Authentication Validation

- [ ] **VALIDATE-001**: Authentication flow validation
  - [ ] All protected routes require authentication
  - [ ] Login redirects work correctly
  - [ ] JWT persistence works across browser tabs
  - [ ] Logout clears JWT cookies and redirects appropriately

### E2E Testing Validation

- [ ] **VALIDATE-002**: E2E infrastructure validation
  - [ ] Docker E2E environment starts successfully with authentication
  - [ ] Test users can log in through E2E tests
  - [ ] All SSR load functions work with authenticated API calls
  - [ ] Health checks pass without breaking authentication requirements

### Development Workflow Validation

- [ ] **VALIDATE-003**: Development experience validation
  - [ ] `just test-e2e` command runs successfully with authentication
  - [ ] Development environment supports both authenticated and test modes
  - [ ] Authentication errors provide clear debugging information

## 📝 Implementation Notes

### Key Architecture References

- **Agent API Contract**: All backend behavior must match `docs/swagger.json` exactly
- **Data Models**: Located in `app/models/` with SQLAlchemy ORM patterns
- **API Endpoints**: Follow `/api/v1/web/*` structure for web UI, `/api/v1/client/*` for agents
- **Frontend Components**: Use idiomatic Shadcn-Svelte components in `frontend/src/lib/components/`
- **SvelteKit Patterns**: Follow idiomatic SvelteKit 5 patterns with runes, actions, and load functions
- **Testing Commands**: `just test-backend`, `just test-frontend`, `just test-e2e`, `just ci-check`
- **Docker E2E Environment**: Uses `docker-compose.e2e.yml` with health checks and data seeding via `scripts/seed_e2e_data.py`
- **Three-Tier Testing**: Layer 1 (backend), Layer 2 (frontend mocked), Layer 3 (full E2E) - authentication blocks Layer 3
- **Mock Data Pattern**: Environment detection in load functions returns mock data when `PLAYWRIGHT_TEST=true`
- **E2E Testing Structure**: `frontend/e2e/` contains mocked E2E tests (fast, no backend), `frontend/tests/e2e/` contains full E2E tests (slower, real backend). Configs: `playwright.config.ts` (mocked) vs `playwright.config.e2e.ts` (full backend)

### 🏗️ SvelteKit Data Flow Architecture

**Critical Pattern**: The established SvelteKit architecture separates concerns cleanly:

- **Client-Side Code**: Uses SvelteKit 5 stores and runes for reactivity - **NO direct API calls**
- **Server-Side Code**: SSR load functions (`+page.server.ts`) make authenticated API calls to FastAPI backend
- **Store Population**: Server-side load functions populate and hydrate stores with initial data
- **Real-Time Updates**: Stores updated via Server-Sent Events (SSE) when appropriate for live data
- **Store Examples**: Projects store, resources store (by type), user context - all follow this pattern

**Implementation Implication**: Authentication must work in server-side load functions, not client-side components. Client components consume store state reactively without making API calls.

### 🎨 Frontend Component Standards

**All frontend implementation must use idiomatic patterns:**

- **Shadcn-Svelte Components**: Use composable, accessible components from Shadcn-Svelte library
- **SvelteKit 5 Runes**: Use `$state`, `$derived`, `$effect` for reactive state management
- **Form Components**: Use Shadcn-Svelte form components with Superforms integration
- **Data Tables**: Use Shadcn-Svelte data table components for lists and grids
- **Modal Dialogs**: Use Shadcn-Svelte dialog components for overlays and confirmations
- **Navigation**: Use Shadcn-Svelte navigation components for consistent UX patterns

### Authentication Strategy Context

This implementation adapts existing JWT authentication for SSR compatibility:

- JWT tokens stored in HTTP-only and secure cookies (not localStorage)
- Server-side API client extracts JWT from cookies and sets Authorization headers
- SvelteKit hooks manage JWT validation and user context across requests
- Test environment bypasses authentication with mock data

### Test Environment Integration

- Environment detection prevents authentication in test scenarios
- Mock data must match exact API response structure from backend
- Test seeding creates users with known credentials for E2E tests
- Playwright global setup handles login sequence for full E2E tests

### Critical Dependencies

This step must be completed before any other Phase 3 steps because:

- All E2E tests require authentication to access protected endpoints
- SSR load functions cannot fetch data without session management
- Docker health checks must work without breaking authentication
- Test infrastructure requires authentication bypass mechanisms

## 🎯 Completion Definition

This step is complete when:

1. All SSR load functions can make authenticated API calls successfully
2. E2E tests can log in and access all protected routes
3. JWT token management works across page navigation and browser refresh
4. Test environment detection bypasses authentication with proper mock data
5. Docker E2E infrastructure runs successfully with authentication enabled
6. All validation criteria pass without errors
