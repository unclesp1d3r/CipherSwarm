# Requirements Document

## Introduction

The Web UI API v1 (`/api/v1/web/*`) provides comprehensive endpoints to support the SvelteKit-based dashboard that human users interact with. This API powers views, forms, real-time updates, and all user-facing functionality for managing campaigns, attacks, agents, hash lists, and system resources. The API is designed to be consumed by the frontend application and includes features like pagination, filtering, real-time updates via Server-Sent Events (SSE), and comprehensive resource management.

This API is distinct from the Agent API (used by distributed hashcat instances) and focuses on providing rich, user-friendly interfaces for campaign management, attack configuration, resource browsing, and system monitoring.

## Requirements

### Requirement 1: Authentication and User Management

**User Story:** As a system administrator, I want comprehensive user and project management through the web interface, so that I can control access and organize work effectively.

#### Acceptance Criteria

1. WHEN a user logs in via the web interface THEN the system SHALL authenticate using JWT tokens and return user context including active project
2. WHEN a user requests their profile THEN the system SHALL return current user details and allow updates to name/email
3. WHEN an admin lists users THEN the system SHALL return paginated, filterable user data with search capabilities
4. WHEN an admin creates a user THEN the system SHALL validate required fields and return appropriate validation errors
5. WHEN an admin manages projects THEN the system SHALL support creation, updates, user assignment, and soft deletion
6. WHEN users switch projects THEN the system SHALL update their active project context and scope subsequent API calls
7. WHEN authentication context is requested THEN the system SHALL return current user and project information for UI state management

### Requirement 2: Campaign Management with Rich Metadata

**User Story:** As a security analyst, I want to create and manage password cracking campaigns with comprehensive attack configuration, so that I can efficiently coordinate distributed cracking operations.

#### Acceptance Criteria

1. WHEN campaigns are listed THEN the system SHALL return paginated results with filtering, search, and real-time progress updates
2. WHEN a campaign is created THEN the system SHALL validate hash list assignment and return structured validation errors
3. WHEN campaign details are viewed THEN the system SHALL return comprehensive information including attacks, tasks, progress metrics, and performance data
4. WHEN campaigns are updated THEN the system SHALL support state transitions (draft/active/archived) with appropriate validation
5. WHEN attacks are added to campaigns THEN the system SHALL support reordering, duplication, and bulk operations
6. WHEN campaign progress is requested THEN the system SHALL return real-time metrics including completion percentage, crack rate, and agent participation
7. WHEN campaigns are relaunched THEN the system SHALL validate resource changes and require explicit user confirmation

### Requirement 3: Advanced Attack Configuration

**User Story:** As a security analyst, I want sophisticated attack configuration with real-time validation and keyspace estimation, so that I can create effective cracking strategies.

#### Acceptance Criteria

1. WHEN attacks are created THEN the system SHALL support all hashcat attack modes (dictionary, mask, brute force, hybrid) with mode-specific validation
2. WHEN attack configurations are validated THEN the system SHALL return keyspace estimates, complexity scores, and structured validation errors
3. WHEN dictionary attacks are configured THEN the system SHALL support wordlist selection, rule application, length constraints, and ephemeral wordlists
4. WHEN mask attacks are configured THEN the system SHALL support inline mask editing, syntax validation, and ephemeral mask lists
5. WHEN brute force attacks are configured THEN the system SHALL provide charset selection UI that generates appropriate masks and custom charsets
6. WHEN attacks are edited THEN the system SHALL warn about lifecycle impacts and reset state appropriately for running/completed attacks
7. WHEN attacks are exported/imported THEN the system SHALL support JSON serialization with resource references and ephemeral content preservation

### Requirement 4: Hash List Management with Import/Export

**User Story:** As a security analyst, I want comprehensive hash list management with flexible import options, so that I can efficiently process various hash formats and sources.

#### Acceptance Criteria

1. WHEN hash lists are created THEN the system SHALL support file uploads, paste operations, and automatic hash type detection
2. WHEN hash lists are viewed THEN the system SHALL return paginated hash items with search, filtering by crack status, and export capabilities
3. WHEN hash items are listed THEN the system SHALL support CSV/TSV export with hash values, plaintexts, and metadata
4. WHEN hash lists are updated THEN the system SHALL validate changes and maintain referential integrity with campaigns
5. WHEN hash lists are deleted THEN the system SHALL check for active campaign usage and prevent deletion if in use
6. WHEN crackable uploads are processed THEN the system SHALL support file extraction, hash parsing, type detection, and automatic campaign generation
7. WHEN upload analysis completes THEN the system SHALL provide preview screens with detected hash types, sample data, and proposed attack configurations

### Requirement 5: Agent Management and Monitoring

**User Story:** As a system administrator, I want comprehensive agent management with real-time monitoring and configuration, so that I can effectively manage distributed cracking resources.

#### Acceptance Criteria

1. WHEN agents are listed THEN the system SHALL return paginated data with status, performance metrics, current assignments, and filtering capabilities
2. WHEN agent details are viewed THEN the system SHALL provide tabbed interface with settings, hardware, performance graphs, logs, and capabilities
3. WHEN agent settings are updated THEN the system SHALL support enable/disable toggles, project assignments, and advanced configuration options
4. WHEN agent hardware is configured THEN the system SHALL support device toggles, backend selection, and temperature limits
5. WHEN agent performance is monitored THEN the system SHALL provide time-series data for guess rates, utilization, and device-specific metrics
6. WHEN agent errors occur THEN the system SHALL log structured error data with severity, codes, and contextual information
7. WHEN agent benchmarks are requested THEN the system SHALL trigger benchmark runs and display capability matrices with hash type support

### Requirement 6: Resource Management with Line-Level Editing

**User Story:** As a security analyst, I want comprehensive resource management with in-browser editing capabilities, so that I can efficiently manage wordlists, rules, masks, and custom charsets.

#### Acceptance Criteria

1. WHEN resources are listed THEN the system SHALL return filterable results by type, project scope, and modification date
2. WHEN resources are uploaded THEN the system SHALL detect resource type, validate content, and create database records with S3 storage
3. WHEN resources are edited THEN the system SHALL support line-level editing for eligible resources under size thresholds
4. WHEN resource lines are modified THEN the system SHALL validate syntax per resource type and return structured error responses
5. WHEN resources are too large for editing THEN the system SHALL require download/reupload workflow with clear size limit messaging
6. WHEN resources are deleted THEN the system SHALL check for attack linkage and prevent deletion if in use
7. WHEN resource metadata is updated THEN the system SHALL support name, description, and visibility changes with validation

### Requirement 7: Real-Time Updates via Server-Sent Events

**User Story:** As a security analyst, I want real-time updates in the web interface, so that I can monitor campaign progress and system status without manual refreshing.

#### Acceptance Criteria

1. WHEN SSE connections are established THEN the system SHALL authenticate using JWT tokens and scope events to user's active project
2. WHEN campaign state changes THEN the system SHALL broadcast lightweight trigger events to subscribed clients
3. WHEN agent status updates THEN the system SHALL notify clients of performance changes, errors, and connectivity status
4. WHEN crack results are submitted THEN the system SHALL trigger toast notifications for successful hash cracks
5. WHEN SSE events are received THEN the client SHALL issue targeted fetch requests to update specific UI components
6. WHEN SSE connections are lost THEN the browser SHALL automatically reconnect with proper authentication
7. WHEN multiple users monitor the same project THEN the system SHALL broadcast events to all authorized subscribers

### Requirement 8: System Health and Monitoring

**User Story:** As a system administrator, I want comprehensive system health monitoring and dashboard metrics, so that I can ensure optimal system performance and identify issues.

#### Acceptance Criteria

1. WHEN dashboard summary is requested THEN the system SHALL return aggregated campaign statistics, agent status, and performance metrics
2. WHEN system health is checked THEN the system SHALL return component status for database, Redis, MinIO, and core services
3. WHEN health metrics are gathered THEN the system SHALL include latency measurements, error rates, and resource utilization
4. WHEN performance data is requested THEN the system SHALL provide time-series data for agent performance and system throughput
5. WHEN system errors occur THEN the system SHALL log structured error data with appropriate severity levels
6. WHEN health data is cached THEN the system SHALL use configurable TTL values and support both memory and Redis backends
7. WHEN health status changes THEN the system SHALL provide alerts and notifications for critical system issues

### Requirement 9: Advanced UX Support Features

**User Story:** As a security analyst, I want intelligent UX features like auto-completion, validation helpers, and configuration suggestions, so that I can efficiently configure complex attacks.

#### Acceptance Criteria

1. WHEN dropdown data is requested THEN the system SHALL return filtered, searchable options for agents, resources, and hash types
2. WHEN hash types are suggested THEN the system SHALL include confidence scores from detection algorithms and allow manual override
3. WHEN attack configurations are built THEN the system SHALL provide default suggestions for masks, charsets, and rule combinations
4. WHEN rule explanations are requested THEN the system SHALL return human-readable descriptions of hashcat rule syntax
5. WHEN resource modifiers are applied THEN the system SHALL map user-friendly options to appropriate rule files
6. WHEN keyspace estimates are needed THEN the system SHALL provide real-time calculations for unsaved attack configurations
7. WHEN configuration errors occur THEN the system SHALL return structured validation messages with specific field guidance

### Requirement 10: Data Export and Template Management

**User Story:** As a security analyst, I want to export and import attack configurations and campaign templates, so that I can reuse successful strategies and share configurations.

#### Acceptance Criteria

1. WHEN attacks are exported THEN the system SHALL generate JSON files with all configuration data and resource references
2. WHEN campaigns are exported THEN the system SHALL preserve attack ordering, comments, and ephemeral resource content
3. WHEN configurations are imported THEN the system SHALL validate schema correctness and resolve resource references by GUID
4. WHEN resource references cannot be resolved THEN the system SHALL provide fallback options (replacement, skip, abort)
5. WHEN ephemeral resources are exported THEN the system SHALL serialize inline content for complete portability
6. WHEN import validation fails THEN the system SHALL return structured error messages with specific field issues
7. WHEN templates are applied THEN the system SHALL allow customization before final campaign creation

### Requirement 11: Security and Access Control

**User Story:** As a system administrator, I want robust security controls and project-based access restrictions, so that sensitive data remains properly isolated.

#### Acceptance Criteria

1. WHEN API requests are made THEN the system SHALL require authentication for all endpoints except login
2. WHEN project-scoped data is accessed THEN the system SHALL enforce project context and prevent cross-project data leakage
3. WHEN admin operations are performed THEN the system SHALL validate admin role permissions using Casbin authorization
4. WHEN sensitive operations are requested THEN the system SHALL require explicit confirmation and log audit trails
5. WHEN authentication fails THEN the system SHALL return appropriate error codes without exposing sensitive information
6. WHEN rate limiting is applied THEN the system SHALL protect against abuse while allowing normal operation
7. WHEN data is transmitted THEN the system SHALL enforce HTTPS and secure header policies

### Requirement 12: Performance and Scalability

**User Story:** As a system administrator, I want the web API to perform efficiently under load, so that multiple users can work simultaneously without degradation.

#### Acceptance Criteria

1. WHEN database queries are executed THEN the system SHALL use appropriate indexes, pagination, and query optimization
2. WHEN large datasets are returned THEN the system SHALL implement cursor-based pagination with configurable page sizes
3. WHEN expensive operations are performed THEN the system SHALL use caching with appropriate TTL values
4. WHEN concurrent requests are made THEN the system SHALL handle them efficiently using async patterns
5. WHEN background tasks are needed THEN the system SHALL use appropriate task queues and avoid blocking operations
6. WHEN memory usage grows THEN the system SHALL implement proper cleanup and resource management
7. WHEN response times exceed thresholds THEN the system SHALL provide performance monitoring and alerting
