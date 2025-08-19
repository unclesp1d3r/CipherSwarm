# Phase 3: Complete E2E Test Coverage Plan

This document defines the comprehensive e2e test coverage required for CipherSwarm Phase 3, derived from the user flows in `user_journey_flowchart.mmd` and `user_flows_notes.md`. These tests will validate the complete user experience from frontend through backend integration.

---

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [Phase 3: Complete E2E Test Coverage Plan](#phase-3-complete-e2e-test-coverage-plan)
  - [Table of Contents](#table-of-contents)
  - [Testing Strategy](#testing-strategy)
  - [Missing Test Coverage Analysis](#missing-test-coverage-analysis)
  - [Authentication & Session Management Tests](#authentication--session-management-tests)
  - [Dashboard & Real-Time Monitoring Tests](#dashboard--real-time-monitoring-tests)
  - [Campaign Management Tests](#campaign-management-tests)
  - [Attack Configuration Tests](#attack-configuration-tests)
  - [Resource Management Tests](#resource-management-tests)
  - [Hash List Management Tests](#hash-list-management-tests)
  - [Agent Management Tests](#agent-management-tests)
  - [User & Project Management Tests](#user--project-management-tests)
  - [Access Control & Security Tests](#access-control--security-tests)
  - [Monitoring & System Health Tests](#monitoring--system-health-tests)
  - [Notification & Toast System Tests](#notification--toast-system-tests)
  - [UI/UX & Responsive Design Tests](#uiux--responsive-design-tests)
  - [Integration & Workflow Tests](#integration--workflow-tests)
  - [Performance & Load Tests](#performance--load-tests)
  - [Test Implementation Priority](#test-implementation-priority)
  - [Test Infrastructure Requirements](#test-infrastructure-requirements)
  - [Success Metrics](#success-metrics)
  - [Notes for Implementation](#notes-for-implementation)
  - [Current Test Coverage Analysis](#current-test-coverage-analysis)
  - [API v2 Contract & Plan Alignment](#api-v2-contract--plan-alignment)
  - [API v2 Contract & Error Format Tests](#api-v2-contract--error-format-tests)

<!-- mdformat-toc end -->

---

## Testing Strategy

### Three-Tier Architecture Integration

- **Layer 1**: Backend tests (Python + testcontainers) – ✅ Complete  
- **Layer 2**: Frontend mocked tests (Playwright + mocked APIs) – ✅ Complete  
- **Layer 3**: Full E2E tests (Playwright + real Docker backend) – 🔄 Infrastructure complete, authentication pending  

### Test Environment Requirements

- Docker-based backend stack with seeded test data  
- SSR authentication implementation for authenticated flows  
- Real database with predictable test data  
- MinIO object storage for file uploads  
- Session-based authentication flow  

---

## API v2 Contract & Plan Alignment

The following additions align the E2E coverage with Agent API v2 changes introduced in this release (router infrastructure, authentication, schema foundation, unified JSON error handling, and endpoint implementations).

### Scope

- Agent API v2 endpoints: registration, heartbeat, task assignment, progress, result submission, resource management, temporary/secure auth.  
- Unified JSON error envelope and status codes across v2.  
- Resource API response model updates (IDs as strings, checksum, upload status, storage bucket info).  
- Validation semantics updates (1-based line numbering).  

### Objectives

- Ensure UI and workflows reflect v2 contract changes end-to-end.  
- Validate error surfaces and recovery paths match the v2 error schema.  
- Establish OpenAPI contract checks for v2 responses used by the frontend.  

---

## Missing Test Coverage Analysis

Based on examination of the frontend source code in `/src`, the following UI elements and pages are **NOT** covered in the current E2E test plan:

### Missing Pages and Routes

1. **Resource Upload Page** (`/resources/upload/+page.svelte`)
   - File upload interface with drag-and-drop  
   - Resource type detection and validation  
   - Upload progress indicators  
   - Metadata input forms  

2. **Campaign Edit Page** (`/campaigns/[id]/edit/+page.svelte`)
   - Campaign modification workflows  
   - Attack reordering within existing campaigns  
   - Campaign settings updates  

3. **User Detail Pages** (`/users/[id]/+page.svelte`)
   - Individual user profile viewing and editing  
   - User-specific settings and permissions  

4. **User Delete Page** (`/users/[id]/delete/+page.svelte`)
   - User deletion confirmation workflows  
   - Impact assessment display  

5. **Campaign Delete Page** (`/campaigns/[id]/delete/+page.svelte`)
   - Campaign deletion with impact assessment  
   - Cascade deletion warnings  

6. **Attack Creation/Edit Pages** (`/attacks/new/+page.svelte`, `/attacks/[id]/`)
   - Standalone attack creation outside of campaign context  
   - Attack modification workflows  

7. **Resource Detail Pages** (`/resources/[id]/+page.svelte`)
   - Individual resource viewing and editing  
   - Content preview and metadata management  

8. **Error Pages** (`/resources/+error.svelte`, `/campaigns/[id]/+error.svelte`)
   - Error state handling and user guidance  
   - Error recovery workflows  

### Missing UI Components and Features

1. **Project Selection Modal** (Used during login for multi-project users)
   - Project switching interface  
   - Project context awareness  

2. **Toast Notification System** (`Toast.svelte`)
   - Real-time notification display  
   - Notification persistence and dismissal  

3. **Night Mode Toggle** (`NightModeToggleButton.svelte`)
   - Dark/light theme switching  
   - Theme persistence  

4. **Advanced Search and Filtering**
   - Cross-page search functionality  
   - Complex filter combinations  
   - Saved search preferences  

5. **File Upload Progress Tracking**
   - Large file upload handling  
   - Upload cancellation  
   - Resume functionality  

6. **Resource Content Editing**
   - Inline editing for small files  
   - Syntax highlighting for different resource types  
   - Line-by-line editing capabilities  

7. **Real-Time Progress Updates**
   - SSE connection management  
   - Live dashboard updates  
   - Connection recovery handling  

---

## Authentication & Session Management Tests

### ASM-001: Login Flow

- [ ] **ASM-001a**: Successful login with valid credentials  
- [ ] **ASM-001b**: Failed login with invalid credentials  
- [ ] **ASM-001c**: Login form validation (empty fields, invalid email format)  
- [ ] **ASM-001d**: Session persistence across page refreshes  
- [ ] **ASM-001e**: Redirect to login page when accessing protected routes unauthenticated  
- [ ] **ASM-001f**: "Remember me" checkbox functionality and persistence  
- [ ] **ASM-001g**: Login loading states and error display  

### ASM-002: Project Selection & Switching

- [ ] **ASM-002a**: Single project auto-selection on login  
- [ ] **ASM-002b**: Multi-project selection modal on login  
- [ ] **ASM-002c**: Project switching via global project selector  
- [ ] **ASM-002d**: Project context persistence across navigation  
- [ ] **ASM-002e**: Project-scoped data visibility validation  
- [ ] **ASM-002f**: Project context awareness in all UI elements (verify all components respect current project)  
- [ ] **ASM-002g**: Project-based resource filtering and access control validation  

### ASM-003: Session Management

- [ ] **ASM-003a**: Session timeout handling with modal prompt  
- [ ] **ASM-003b**: Token refresh on expired JWT  
- [ ] **ASM-003c**: Logout functionality with session cleanup  
- [ ] **ASM-003d**: Concurrent session handling  
- [ ] **ASM-003e**: Session expiry redirect to login  

### ASM-004: API v2 Token Flows (NEW)

- [ ] **ASM-004a**: Temporary token issuance flow (backend) and UI handling where applicable  
- [ ] **ASM-004b**: Token renewal/refresh via v2 endpoints (happy path + failure)  
- [ ] **ASM-004c**: Unified error handling and logout on invalid/expired tokens  

---

## Dashboard & Real-Time Monitoring Tests

### DRM-001: Dashboard Data Loading

- [ ] **DRM-001a**: Dashboard loads with SSR data (agents, campaigns, stats)  
- [ ] **DRM-001b**: Dashboard cards display correct real-time data  
- [ ] **DRM-001c**: Error handling for failed dashboard API calls  
- [ ] **DRM-001d**: Loading states during data fetch  
- [ ] **DRM-001e**: Empty state handling (no campaigns, no agents)  

### DRM-002: Real-Time Updates

> Note: Tests should align with v2 SSE trigger semantics (lightweight notifications, targeted component refresh, not full data streaming).

- [ ] **DRM-002a**: Campaign progress updates via SSE (lightweight trigger notifications, not full data)  
- [ ] **DRM-002b**: Agent status updates in real-time (verify EventSource reconnection handling)  
- [ ] **DRM-002c**: Crack notifications via toast system (test batching logic for >5 events/sec)  
- [ ] **DRM-002d**: Task completion notifications with targeted component refresh  
- [ ] **DRM-002e**: System health status updates  
- [ ] **DRM-002f**: SSE connection cleanup and timeout handling  
- [ ] **DRM-002g**: Project-scoped event filtering (users only see events for their current project)  

### DRM-003: Dashboard Navigation

- [ ] **DRM-003a**: Sidebar navigation between main sections  
- [ ] **DRM-003b**: Dashboard card click-through to detail views  
- [ ] **DRM-003c**: Breadcrumb navigation consistency  
- [ ] **DRM-003d**: Deep linking to dashboard sections  
- [ ] **DRM-003e**: Mobile responsive navigation  

---

## Campaign Management Tests

…continued in the same unmodified structure…

This comprehensive test plan ensures complete coverage of CipherSwarm’s user experience while maintaining the three-tier testing architecture established in Phase 3.