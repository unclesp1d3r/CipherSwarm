# Implementation Plan

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step in a test-driven manner. Prioritize best practices, incremental progress, and early testing, ensuring no big jumps in complexity at any stage. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

## Task List

- [ ] 1. Server-Sent Events (SSE) Infrastructure Implementation
  - [ ] 1.1 Create SSE event models and base infrastructure
    - Create `SSEEvent`, `AgentStatusEvent`, `CampaignProgressEvent`, and `CrackNotificationEvent` Pydantic models in `app/schemas/events.py`
    - Implement `EventService` class in `app/core/services/event_service.py` with Redis pub/sub integration
    - Add SSE streaming response utilities and connection management helpers
    - Write unit tests for event models and EventService class
    - _Requirements: 1.1, 1.2, 1.6_

  - [ ] 1.2 Implement SSE server endpoints
    - Create `/api/v1/web/live/agents`, `/api/v1/web/live/campaigns`, and `/api/v1/web/live/toasts` endpoints in `app/api/v1/endpoints/web/live.py`
    - Implement project-scoped event filtering and user authentication for SSE streams
    - Add connection cleanup and timeout handling with proper resource management
    - Write integration tests for SSE endpoints with Redis testcontainer
    - _Requirements: 1.1, 1.2, 1.6_

  - [ ] 1.3 Create frontend SSE client service
    - Implement `SSEService` class in `frontend/src/lib/services/sse-service.ts` with connection management
    - Add automatic reconnection handling with exponential backoff and graceful degradation
    - Create connection status indicators and error handling for connection failures
    - Write unit tests for SSE client service with mock EventSource
    - _Requirements: 1.1, 1.2, 1.6_

  - [ ] 1.4 Integrate SSE with existing components
    - Update dashboard components to subscribe to SSE events for real-time updates
    - Modify agent status components to receive live status updates without page refresh
    - Add campaign progress components with smooth animations and color-coded states
    - Write E2E tests for real-time dashboard updates using mocked SSE streams
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 2. Toast Notification System Implementation
  - [ ] 2.1 Create backend notification service
    - Implement `NotificationService` class in `app/core/services/notification_service.py` with batching logic
    - Add notification queuing, batch processing, and rate limiting to prevent spam
    - Create notification event triggers for crack discoveries, agent status changes, and system alerts
    - Write unit tests for notification service with mock event broadcasting
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [ ] 2.2 Implement frontend toast management system
    - Create `ToastManager` class and toast components in `frontend/src/lib/components/ui/toast-manager.svelte`
    - Implement toast stacking, queue management, and auto-dismiss functionality
    - Add visual hierarchy with color coding, iconography, and severity levels
    - Write unit tests for toast manager with different notification types
    - _Requirements: 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12_

  - [ ] 2.3 Integrate toast notifications with SSE events
    - Connect toast system to SSE crack notification events with batching support
    - Add agent status change notifications and campaign completion alerts
    - Implement system error notifications with actionable information and retry actions
    - Write E2E tests for toast notifications triggered by SSE events
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 3. Advanced Attack Configuration Features
  - [ ] 3.1 Implement rule modificator system
    - Create `RuleService` class in `app/core/services/rule_service.py` with rule generation and validation
    - Add rule modificator models and user-friendly modifier buttons that abstract hashcat complexity
    - Implement rule preview and testing capabilities with sample word transformations
    - Write unit tests for rule generation, validation, and preview functionality
    - _Requirements: 4.1, 4.6_

  - [ ] 3.2 Create dynamic wordlist generation service
    - Implement `AdvancedAttackService` class in `app/core/services/advanced_attack_service.py`
    - Add dynamic wordlist generation from project history and cracked hashes
    - Create ephemeral wordlist storage and management for attack-specific resources
    - Write unit tests for dynamic wordlist generation with mock data sources
    - _Requirements: 4.2, 4.5_

  - [ ] 3.3 Implement attack overlap detection and performance estimation
    - Add keyspace overlap analysis and duplicate work prevention alerts in `AdvancedAttackService`
    - Create `/api/v1/web/attacks/estimate` endpoint for live keyspace calculation updates
    - Implement performance impact estimation and time-to-completion predictions
    - Write unit tests for overlap detection and performance estimation algorithms
    - _Requirements: 4.3, 4.4_

  - [ ] 3.4 Integrate name-that-hash for hash type detection
    - Enhance `HashGuessService` integration in attack configuration workflows
    - Add confidence-ranked hash type suggestions with manual override capability
    - Implement hash format validation and hashcat compatibility verification
    - Write integration tests for name-that-hash integration with various hash formats
    - _Requirements: 4.7, 4.8, 4.9_

  - [ ] 3.5 Create advanced attack configuration UI components
    - Build attack editor components with rule modificators and dynamic wordlist selection
    - Add attack overlap warnings and performance estimation displays
    - Implement hash type detection UI with confidence scoring and manual override
    - Write E2E tests for advanced attack configuration workflows
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.7, 4.8, 4.9_

- [ ] 4. Campaign Lifecycle Management Implementation
  - [ ] 4.1 Create campaign lifecycle service
    - Implement `CampaignLifecycleService` class in `app/core/services/campaign_lifecycle_service.py`
    - Add start, pause, resume, and stop operations with proper state validation
    - Implement task generation, impact assessment, and confirmation workflows
    - Write unit tests for all campaign lifecycle operations with mock dependencies
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ] 4.2 Implement campaign export/import functionality
    - Create `CampaignTemplateService` class in `app/core/services/campaign_template_service.py`
    - Add JSON template export with GUID-based resource references and version management
    - Implement template import with schema validation, version compatibility, and resource rehydration
    - Write unit tests for export/import functionality with template validation
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8_

  - [ ] 4.3 Create advanced campaign management UI
    - Build campaign toolbar with add attack, sort, bulk-select/delete, and start/stop toggle buttons
    - Implement attack reordering with drag-and-drop and keyboard accessibility support
    - Add context menu per attack row with edit, duplicate, delete, and move operations
    - Write E2E tests for campaign management UI interactions and workflows
    - _Requirements: 5.6, 5.7_

  - [ ] 4.4 Integrate campaign operations with real-time updates
    - Connect campaign lifecycle operations to SSE event broadcasting
    - Add real-time status updates for campaign state changes and progress tracking
    - Implement confirmation dialogs with impact assessment for destructive operations
    - Write integration tests for campaign operations with SSE event verification
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 5. Enhanced Resource Management Implementation
  - [ ] 5.1 Create enhanced resource upload system
    - Implement `EnhancedResourceService` class in `app/core/services/enhanced_resource_service.py`
    - Add chunked upload support with resume capability and progress tracking
    - Create upload session management with presigned URLs and atomic operations
    - Write unit tests for enhanced resource service with MinIO testcontainer
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.8, 7.9, 7.10, 7.11, 7.12, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10_

  - [ ] 5.2 Implement resource content editor
    - Create `ResourceEditorService` class in `app/core/services/resource_editor_service.py`
    - Add line-oriented editing with add/remove functionality and real-time validation
    - Implement type-aware editing interfaces for different resource types (masks, rules, wordlists, charsets)
    - Write unit tests for resource editor with validation and error handling
    - _Requirements: 8.2, 8.6, 12.8, 12.9_

  - [ ] 5.3 Create comprehensive resource detail pages
    - Build resource detail UI with metadata editing, content preview, and usage tracking
    - Add resource download options with presigned URLs and export functionality
    - Implement resource deletion with usage validation and cascade checks
    - Write E2E tests for resource detail pages and content management workflows
    - _Requirements: 8.1, 8.3, 8.4, 8.5, 8.7, 8.8_

  - [ ] 5.4 Build advanced resource upload UI
    - Create file drop zone with drag-over visual feedback and traditional file picker
    - Implement multi-file upload with progress indicators and cancellation controls
    - Add file type validation, size limits, and metadata input forms with real-time validation
    - Write E2E tests for resource upload workflows with progress tracking and error handling
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

- [ ] 6. Hash List Management and Crackable Upload Enhancement
  - [ ] 6.1 Enhance hash list management service
    - Create `EnhancedHashListService` class in `app/core/services/enhanced_hash_list_service.py`
    - Integrate name-that-hash for intelligent hash type detection with confidence scoring
    - Add dual input modes (file upload + text paste) with hash isolation from metadata
    - Write unit tests for enhanced hash list service with name-that-hash integration
    - _Requirements: 9.1, 9.2, 9.3, 9.8, 9.9_

  - [ ] 6.2 Implement enhanced crackable upload processing
    - Create `EnhancedCrackableUploadService` class in `app/core/services/enhanced_crackable_upload_service.py`
    - Add plugin-based hash extraction with support for `.shadow`, `.pdf`, `.zip`, `.7z`, `.docx` files
    - Implement background processing pipeline with `HashUploadTask`, `RawHash`, and `UploadErrorEntry` models
    - Write integration tests for crackable upload processing with plugin architecture
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10, 10.11, 10.12_

  - [ ] 6.3 Create hash list and upload management UI
    - Build hash list creation UI with dual input modes and intelligent type detection
    - Implement crackable upload interface with file support and progress tracking
    - Add hash list preview with statistics, confidence scoring, and manual override capability
    - Write E2E tests for hash list creation and crackable upload workflows
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [ ] 6.4 Integrate hash management with campaign creation
    - Connect hash list selection to campaign creation workflows
    - Add auto-campaign creation from uploaded hashes with dynamic wordlist generation
    - Implement hash list reuse across multiple campaigns with proper validation
    - Write integration tests for hash list and campaign integration workflows
    - _Requirements: 9.4, 9.5, 9.6, 9.7, 10.7, 10.8, 10.9, 10.10, 10.11, 10.12_

- [ ] 7. Presigned URL Validation and Testing Infrastructure
  - [ ] 7.1 Implement presigned URL validation service
    - Create admin-only endpoint `POST /api/v1/web/agents/{id}/test_presigned` for URL validation
    - Add URL validation with HEAD requests, timeout handling, and security constraints
    - Implement proper error handling for 403/404 responses and network errors
    - Write unit tests for presigned URL validation with mock HTTP responses
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

  - [ ] 7.2 Enhance testing infrastructure with MinIO testcontainers
    - Configure MinIO testcontainer integration for comprehensive storage testing
    - Add auto-creation of required buckets and test data seeding capabilities
    - Implement configurable MinIO endpoints and credentials for test environments
    - Write integration tests for all storage operations with MinIO testcontainer
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8_

- [ ] 8. Performance Optimization and Security Implementation
  - [ ] 8.1 Implement performance optimizations
    - Add throttling for real-time updates to prevent UI flooding
    - Implement connection limits and cleanup for SSE connections
    - Add chunked upload optimization and resume capabilities for large files
    - Write performance tests for SSE connections and real-time features
    - _Requirements: 15.1, 15.2, 15.4, 15.5_

  - [ ] 8.2 Enhance security measures
    - Implement project-scoped event filtering to prevent data leaks
    - Add file type validation, size limits, and timeout enforcement
    - Ensure all MinIO operations use `asyncio.to_thread()` for proper async handling
    - Write security tests for access control and data isolation
    - _Requirements: 15.3, 15.6, 15.7, 15.8, 15.9, 15.10, 15.11_

- [ ] 9. Comprehensive Testing and Integration
  - [ ] 9.1 Create comprehensive unit test suite
    - Write unit tests for all service classes with proper mocking and isolation
    - Add tests for error handling, edge cases, and validation logic
    - Implement tests for all Pydantic models and schema validation
    - Ensure minimum 80% code coverage for all new components
    - _Requirements: 11.1, 11.2, 11.4, 11.6, 11.7_

  - [ ] 9.2 Implement integration test coverage
    - Write integration tests for all API endpoints with database and MinIO integration
    - Add tests for SSE functionality, real-time updates, and event broadcasting
    - Implement tests for crackable upload processing and resource management workflows
    - Create tests for campaign lifecycle operations and template import/export
    - _Requirements: 11.1, 11.2, 11.4, 11.6, 11.7_

  - [ ] 9.3 Create end-to-end test suite
    - Write E2E tests for all user-facing functionality using Playwright
    - Implement both mocked E2E tests (fast, no backend) and full E2E tests (complete integration)
    - Add tests for real-time features, advanced attack configuration, and resource management
    - Create tests for responsive design and offline capability requirements
    - _Requirements: 11.1, 11.2, 11.3, 11.5, 11.6, 11.7_

  - [ ] 9.4 Final integration and validation
    - Integrate all components and ensure proper wiring between frontend and backend
    - Validate all requirements are met with comprehensive testing
    - Perform final performance testing and optimization
    - Complete documentation and deployment preparation
    - _Requirements: All requirements validation_