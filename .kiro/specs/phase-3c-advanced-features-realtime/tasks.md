# Implementation Plan

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step in a test-driven manner. Prioritize best practices, incremental progress, and early testing, ensuring no big jumps in complexity at any stage. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

## Task List

- [ ] 1. Real-Time Infrastructure Implementation (Turbo Streams & ActionCable)

  - [ ] 1.1 Create Turbo Streams and ActionCable infrastructure

    - Implement TurboStreamsEventService in `app/services/turbo_streams_event_service.rb` with ActionCable broadcasting
    - Create ActionCable channels for real-time event handling with proper authentication
    - Add project-scoped event filtering and connection management
    - _Requirements: 1.1, 1.2, 1.6_

  - [ ] 1.2 Implement Turbo Streams broadcast endpoints

    - Create ActionCable channels at `/cable` for agents, campaigns, and toast notifications
    - Implement user authentication and connection cleanup with proper resource management
    - Write RSpec request specs for Turbo Streams channels in `spec/requests/cable/`
    - _Requirements: 1.1, 1.2, 1.6_

  - [ ] 1.3 Create frontend Turbo Streams subscription management

    - Implement Stimulus controller for Turbo Streams connection management with reconnection logic
    - Add automatic reconnection handling with exponential backoff and authentication recovery
    - Create connection status indicators and error handling for connection failures
    - _Requirements: 1.1, 1.2, 1.6_

  - [ ] 1.4 Integrate Turbo Streams with existing components

    - Connect dashboard ViewComponents to Turbo Streams for real-time updates
    - Add Turbo Stream broadcasting to agent and campaign services on state changes
    - Write RSpec system tests for Turbo Streams integration in `spec/system/`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [ ] 2. Toast Notification System Implementation

  - [ ] 2.1 Create backend notification service

    - Implement NotificationService in `app/services/notification_service.rb` with batching logic
    - Add toast notification triggers for crack discoveries in agent service
    - Write RSpec unit tests for notification service in `spec/services/`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [ ] 2.2 Implement frontend toast management system

    - Create toast ViewComponent and Stimulus controller for notification display
    - Add toast stacking and auto-dismiss functionality using Hotwire
    - Implement visual hierarchy with proper Tailwind CSS styling
    - _Requirements: 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12_

  - [ ] 2.3 Integrate toast notifications with Turbo Streams

    - Connect toast system to Turbo Streams for crack notification events
    - Implement agent status change notifications and system alerts
    - Write RSpec system tests for toast notifications in `spec/system/`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 3. Advanced Attack Configuration Features

  - [ ] 3.1 Implement rule modificator system

    - Create RuleService class in `app/services/rule_service.rb` with rule generation and validation
    - Add rule modificator models and user-friendly modifier buttons that abstract hashcat complexity
    - Implement rule preview and testing capabilities with sample word transformations
    - Write RSpec unit tests for rule generation, validation, and preview functionality
    - _Requirements: 4.1, 4.6_

  - [ ] 3.2 Create dynamic wordlist generation service

    - Implement AdvancedAttackService class in `app/services/advanced_attack_service.rb`
    - Add dynamic wordlist generation from project history and cracked hashes
    - Create ephemeral wordlist storage and management for attack-specific resources
    - Write RSpec unit tests for dynamic wordlist generation with mock data sources
    - _Requirements: 4.2, 4.5_

  - [ ] 3.3 Implement attack overlap detection and performance estimation

    - Add keyspace overlap analysis and duplicate work prevention alerts in AdvancedAttackService
    - Create controller action in AttacksController for live keyspace calculation updates
    - Implement performance impact estimation and time-to-completion predictions
    - Write RSpec unit tests for overlap detection and performance estimation algorithms
    - _Requirements: 4.3, 4.4_

  - [ ] 3.4 Integrate name-that-hash for hash type detection

    - Create HashGuessService class in `app/services/hash_guess_service.rb` with name-that-hash integration
    - Add confidence-ranked hash type suggestions with manual override capability
    - Implement hash format validation and hashcat compatibility verification
    - Write RSpec request specs for name-that-hash integration with various hash formats
    - _Requirements: 4.7, 4.8, 4.9_

  - [ ] 3.5 Enhance attack configuration UI components

    - Enhance existing attack editor ViewComponent with rule modificators and dynamic wordlist selection
    - Add attack overlap warnings and performance estimation displays using Stimulus controllers
    - Implement hash type detection UI with confidence scoring and manual override
    - Write RSpec system tests for enhanced attack configuration workflows
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.7, 4.8, 4.9_

- [ ] 4. Campaign Lifecycle Management Implementation

  - [ ] 4.1 Create campaign lifecycle service

    - Implement CampaignLifecycleService class in `app/services/campaign_lifecycle_service.rb`
    - Add start, pause, resume, and stop operations with proper state validation
    - Implement task generation, impact assessment, and confirmation workflows
    - Write RSpec unit tests for all campaign lifecycle operations with mock dependencies
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ] 4.2 Implement campaign export/import functionality

    - Create CampaignTemplateService class in `app/services/campaign_template_service.rb`
    - Add JSON template export with GUID-based resource references and version management
    - Implement template import with schema validation, version compatibility, and resource rehydration
    - Write RSpec unit tests for export/import functionality with template validation
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8_

  - [ ] 4.3 Create advanced campaign management UI

    - Build campaign toolbar ViewComponent with add attack, sort, bulk-select/delete, and start/stop toggle buttons
    - Implement attack reordering with drag-and-drop using Stimulus and keyboard accessibility support
    - Add context menu per attack row with edit, duplicate, delete, and move operations
    - Write RSpec system tests for campaign management UI interactions and workflows
    - _Requirements: 5.6, 5.7_

  - [ ] 4.4 Integrate campaign operations with real-time updates

    - Connect campaign lifecycle operations to Turbo Streams event broadcasting
    - Implement real-time status updates for campaign state changes
    - Write RSpec request specs for campaign operations with Turbo Streams event verification
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 5. Enhanced Resource Management Implementation

  - [ ] 5.1 Create enhanced resource upload system

    - Implement EnhancedResourceService class in `app/services/enhanced_resource_service.rb`
    - Add ActiveStorage direct upload support with resume capability and progress tracking
    - Create upload session management with presigned URLs and atomic operations
    - Write RSpec unit tests for enhanced resource service with S3 mock
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.8, 7.9, 7.10, 7.11, 7.12, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10_

  - [ ] 5.2 Implement resource content editor

    - Create ResourceEditorService class in `app/services/resource_editor_service.rb`
    - Add line-oriented editing with add/remove functionality and real-time validation
    - Implement type-aware editing interfaces for different resource types (masks, rules, wordlists, charsets)
    - Write RSpec unit tests for resource editor with validation and error handling
    - _Requirements: 8.2, 8.6, 12.8, 12.9_

  - [ ] 5.3 Create comprehensive resource detail pages

    - Build resource detail ViewComponent with metadata editing, content preview, and usage tracking
    - Add resource download options with presigned URLs and export functionality
    - Implement resource deletion with usage validation and cascade checks
    - Write RSpec system tests for resource detail pages and content management workflows
    - _Requirements: 8.1, 8.3, 8.4, 8.5, 8.7, 8.8_

  - [ ] 5.4 Enhance existing resource upload UI

    - Enhance existing resource upload ViewComponent with drag-over visual feedback and multi-file support
    - Implement progress indicators and cancellation controls using Stimulus controllers
    - Add real-time validation and metadata input forms
    - Write RSpec system tests for enhanced resource upload workflows
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

- [ ] 6. Hash List Management and Crackable Upload Enhancement

  - [ ] 6.1 Enhance hash list management service

    - Create EnhancedHashListService class in `app/services/enhanced_hash_list_service.rb`
    - Integrate name-that-hash for intelligent hash type detection with confidence scoring
    - Add dual input modes (file upload + text paste) with hash isolation from metadata
    - Write RSpec unit tests for enhanced hash list service with name-that-hash integration
    - _Requirements: 9.1, 9.2, 9.3, 9.8, 9.9_

  - [ ] 6.2 Implement enhanced crackable upload processing

    - Create EnhancedCrackableUploadService class in `app/services/enhanced_crackable_upload_service.rb`
    - Add plugin-based hash extraction with support for `.shadow`, `.pdf`, `.zip`, `.7z`, `.docx` files
    - Implement background processing pipeline using Sidekiq with HashUploadJob, RawHash, and UploadErrorEntry models
    - Write RSpec request specs for crackable upload processing with plugin architecture
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10, 10.11, 10.12_

  - [ ] 6.3 Create hash list and upload management UI

    - Build hash list creation ViewComponent with dual input modes and intelligent type detection
    - Implement crackable upload interface with file support and progress tracking
    - Add hash list preview with statistics, confidence scoring, and manual override capability
    - Write RSpec system tests for hash list creation and crackable upload workflows
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [ ] 6.4 Integrate hash management with campaign creation

    - Connect hash list selection to campaign creation workflows
    - Add auto-campaign creation from uploaded hashes with dynamic wordlist generation
    - Implement hash list reuse across multiple campaigns with proper validation
    - Write RSpec request specs for hash list and campaign integration workflows
    - _Requirements: 9.4, 9.5, 9.6, 9.7, 10.7, 10.8, 10.9, 10.10, 10.11, 10.12_

- [ ] 7. Presigned URL Validation and Testing Infrastructure

  - [ ] 7.1 Implement presigned URL validation service

    - Create admin-only controller action for URL validation at agents#test_presigned
    - Add URL validation with HTTP HEAD requests using Ruby Net::HTTP, timeout handling, and security constraints
    - Implement proper error handling for 403/404 responses and network errors
    - Write RSpec unit tests for presigned URL validation with WebMock
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

  - [ ] 7.2 Enhance testing infrastructure with S3 mock

    - Configure AWS SDK mock for comprehensive storage testing using aws-sdk-s3 gem
    - Add auto-creation of required buckets and test data seeding capabilities in test setup
    - Implement configurable S3 endpoints and credentials for test environments
    - Write RSpec request specs for all storage operations with S3 mock
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8_

- [ ] 8. Performance Optimization and Security Implementation

  - [ ] 8.1 Implement performance optimizations

    - Add throttling for real-time updates in TurboStreamsEventService to prevent UI flooding
    - Implement connection limits and cleanup for ActionCable connections with proper timeout handling
    - Optimize ActionCable performance with connection pooling and proper caching
    - _Requirements: 15.1, 15.2, 15.4, 15.5_

  - [ ] 8.2 Enhance security measures

    - Implement project-scoped event filtering in ActionCable channels to prevent data leaks
    - Add file type validation and security constraints for all uploads
    - Ensure proper authentication patterns used throughout ActionCable connections
    - _Requirements: 15.3, 15.6, 15.7, 15.8, 15.9, 15.10, 15.11_

- [ ] 9. Comprehensive Testing and Integration

  - [ ] 9.1 Expand unit test coverage for new services

    - Write RSpec unit tests for RuleService, AdvancedAttackService, and HashGuessService
    - Add RSpec unit tests for CampaignLifecycleService and CampaignTemplateService
    - Implement RSpec unit tests for EnhancedResourceService and ResourceEditorService
    - Ensure minimum 80% code coverage for all new components using SimpleCov
    - _Requirements: 11.1, 11.2, 11.4, 11.6, 11.7_

  - [ ] 9.2 Implement integration test coverage

    - Write RSpec request specs for Turbo Streams functionality and event broadcasting
    - Add RSpec request specs for real-time updates and campaign triggers
    - Implement RSpec request specs for toast notification integration
    - _Requirements: 11.1, 11.2, 11.4, 11.6, 11.7_

  - [ ] 9.3 Create end-to-end test suite for new features

    - Write RSpec system tests for advanced attack configuration workflows
    - Implement RSpec system tests for enhanced resource management features
    - Add RSpec system tests for hash list management and crackable upload processing
    - Create RSpec system tests for campaign lifecycle management operations
    - _Requirements: 11.1, 11.2, 11.3, 11.5, 11.6, 11.7_

  - [ ] 9.4 Final integration and validation

    - Integrate all new components and ensure proper wiring between controllers and services
    - Validate all requirements are met with comprehensive RSpec testing
    - Perform performance testing and optimization using Rails benchmarking tools
    - _Requirements: All requirements validation_
