# Implementation Plan

## Phase 1: Foundation (Core Infrastructure) - COMPLETED

-   [x] 1. Set up API key authentication system

    -   Add API key field to User model and create migration
    -   Implement API key generation utility functions (format: `cst_<user_id>_<random>`)
    -   Create `get_current_control_user` dependency for API key authentication
    -   Add functionality to create API keys during user creation
    -   Add functionality to allow users to rotate their API keys
    -   Add tests to verify API key authentication works correctly
    -   _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

-   [x] 2. Implement RFC9457-compliant error handling

    -   Add `fastapi-problem` dependency to project
    -   Create custom Control API exception classes for domain-specific errors
    -   Configure exception handler for Control API router
    -   Update all Control API endpoints to use custom exceptions
    -   Add tests to verify error responses match RFC9457 format
    -   _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

-   [x] 3. Create project scoping and access control utilities

    -   Implement project access checking utilities and dependencies
    -   Add project filtering to all list endpoints
    -   Add project access checks to detail endpoints
    -   Create utilities to get user accessible projects
    -   Add tests to verify project scoping works correctly
    -   _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

-   [x] 4. Implement offset-based pagination system

    -   Create pagination conversion utilities between offset-based and page-based
    -   Adapt existing service functions for Control API pagination using OffsetPagination class
    -   Add pagination parameter validation and defaults
    -   Add tests to verify pagination works correctly
    -   _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

-   [x] 5. Set up basic Control API router structure
    -   Create Control API router with proper prefix and tags
    -   Set up endpoint organization structure
    -   Configure middleware and dependencies
    -   Add basic health check endpoint for testing
    -   _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5, 17.6, 17.7_

## Phase 2: Core Resources (Building Blocks) - PARTIALLY COMPLETED

-   [x] 6. Implement system health and statistics endpoints

    -   Create `GET /api/v1/control/system/status` endpoint using health_service.py
    -   Create `GET /api/v1/control/system/version` endpoint with API version info
    -   Create `GET /api/v1/control/system/queues` endpoint for queue monitoring
    -   Create `GET /api/v1/control/system/stats` endpoint using dashboard_service.py
    -   Add caching for expensive health check operations
    -   Add tests for all system endpoints
    -   _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

-   [x] 7. Implement user management endpoints

    -   Create `GET /api/v1/control/users` endpoint with pagination and filtering
    -   Create `GET /api/v1/control/users/{id}` endpoint for user details
    -   Create `POST /api/v1/control/users/` endpoint for user creation
    -   Create `PATCH /api/v1/control/users/{id}` endpoint for user updates
    -   Create `DELETE /api/v1/control/users/{id}` endpoint for user deletion
    -   Create `POST /api/v1/control/users/{id}/rotate-keys` endpoint for API key rotation
    -   Create `GET /api/v1/control/users/{id}/api-keys` endpoint for API key info
    -   Add tests for all user management endpoints
    -   _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

-   [x] 8. Implement project management endpoints

    -   Create `GET /api/v1/control/projects` endpoint with pagination and filtering
    -   Create `GET /api/v1/control/projects/{id}` endpoint for project details
    -   Create `POST /api/v1/control/projects/` endpoint for project creation
    -   Create `PATCH /api/v1/control/projects/{id}` endpoint for project updates
    -   Create `DELETE /api/v1/control/projects/{id}` endpoint for project deletion
    -   Create `GET /api/v1/control/projects/{id}/users` endpoint for project users
    -   Create `POST /api/v1/control/projects/{id}/users` endpoint to add users to projects
    -   Create `DELETE /api/v1/control/projects/{id}/users/{user_id}` endpoint to remove users
    -   Add tests for all project management endpoints
    -   _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

-   [ ] 9. Implement hash list and hash item management endpoints
    -   Create `GET /api/v1/control/hashlists` endpoint with filtering and pagination
    -   Create `GET /api/v1/control/hashlists/{id}` endpoint for hash list details
    -   Create `POST /api/v1/control/hashlists/` endpoint for hash list creation
    -   Create `PATCH /api/v1/control/hashlists/{id}` endpoint for hash list updates
    -   Create `DELETE /api/v1/control/hashlists/{id}` endpoint for hash list deletion
    -   Create `POST /api/v1/control/hashlists/import` endpoint for hash list imports
    -   Create export endpoints for plaintext, potfile, and CSV formats
    -   Create `GET /api/v1/control/hashitems` endpoint with filtering
    -   Create `GET /api/v1/control/hashitems/{id}` endpoint for hash item details
    -   Add tests for all hash list management endpoints
    -   _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

## Phase 3: Attack Resources (Content Management) - PARTIALLY COMPLETED

-   [x] 10. Implement hash type detection endpoints

    -   Create `POST /api/v1/control/hash_guess` endpoint using hash_guess_service.py
    -   Create `POST /api/v1/control/hash/validate` endpoint for hash format validation
    -   Create `GET /api/v1/control/hash/types` endpoint for supported hash types
    -   Add confidence scoring and multiple hash sample analysis
    -   Add tests for hash type detection functionality
    -   _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

-   [ ] 11. Implement resource file management endpoints
    -   Create `GET /api/v1/control/resources` endpoint with filtering by type and project
    -   Create `GET /api/v1/control/resources/{id}` endpoint for resource details
    -   Create `POST /api/v1/control/resources/` endpoint for resource uploads
    -   Create `PATCH /api/v1/control/resources/{id}` endpoint for metadata updates
    -   Create `DELETE /api/v1/control/resources/{id}` endpoint for resource deletion
    -   Create `GET /api/v1/control/resources/{id}/content` endpoint for content access
    -   Create `PATCH /api/v1/control/resources/{id}/content` endpoint for content updates
    -   Create resource line management endpoints for line-level operations
    -   Create `POST /api/v1/control/resources/{id}/assign` endpoint for assignments
    -   Add tests for all resource management endpoints
    -   _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

## Phase 4: Campaign and Attack Management (Core Business Logic) - PARTIALLY COMPLETED

-   [x] 12. Implement basic campaign listing endpoint

    -   Create `GET /api/v1/control/campaigns` endpoint using list_campaigns_service()
    -   Add project scoping and pagination support
    -   Add filtering by name and project_id
    -   Add comprehensive tests for campaign listing
    -   _Requirements: 10.1, 10.2, 10.7_

-   [ ] 12.1. Complete campaign management endpoints

    -   Create `GET /api/v1/control/campaigns/{id}` endpoint using get_campaign_service()
    -   Create `POST /api/v1/control/campaigns/` endpoint using create_campaign_service()
    -   Create `PATCH /api/v1/control/campaigns/{id}` endpoint using update_campaign_service()
    -   Create campaign lifecycle control endpoints (start, stop, relaunch)
    -   Create `DELETE /api/v1/control/campaigns/{id}` endpoint using delete_campaign_service()
    -   Create `GET /api/v1/control/campaigns/{id}/progress` endpoint for progress metrics
    -   Create `GET /api/v1/control/campaigns/{id}/metrics` endpoint for performance data
    -   Create `POST /api/v1/control/campaigns/{id}/reorder_attacks` endpoint
    -   Add tests for all remaining campaign management endpoints
    -   _Requirements: 10.3, 10.4, 10.5, 10.6_

-   [ ] 13. Implement attack management endpoints

    -   Create `GET /api/v1/control/attacks` endpoint using get_attack_list_service()
    -   Create `GET /api/v1/control/attacks/{id}` endpoint using get_attack_service()
    -   Create `POST /api/v1/control/attacks/` endpoint using create_attack_service()
    -   Create `PATCH /api/v1/control/attacks/{id}` endpoint using update_attack_service()
    -   Create `DELETE /api/v1/control/attacks/{id}` endpoint using delete_attack_service()
    -   Create attack validation and estimation endpoints
    -   Create `GET /api/v1/control/attacks/{id}/performance` endpoint for performance data
    -   Create attack manipulation endpoints (move, duplicate, bulk delete)
    -   Add tests for all attack management endpoints
    -   _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7_

-   [ ] 14. Implement template import/export endpoints
    -   Create `POST /api/v1/control/campaigns/{id}/export` endpoint using export_campaign_template_service()
    -   Create `POST /api/v1/control/campaigns/import` endpoint for campaign template imports
    -   Create `POST /api/v1/control/attacks/{id}/export` endpoint using export_attack_template_service()
    -   Create `POST /api/v1/control/attacks/import` endpoint for attack template imports
    -   Verify Control API endpoints use existing template services
    -   Add Control API template import functionality using existing schemas
    -   Add tests for template import/export functionality
    -   _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7_

## Phase 5: Agent and Task Management (Runtime Operations)

-   [ ] 15. Implement agent management endpoints

    -   Create `GET /api/v1/control/agents` endpoint using list_agents_service()
    -   Create `GET /api/v1/control/agents/{id}` endpoint using get_agent_by_id_service()
    -   Create `POST /api/v1/control/agents/` endpoint using register_agent_service()
    -   Create `PATCH /api/v1/control/agents/{id}` endpoint for agent updates
    -   Create `PATCH /api/v1/control/agents/{id}/config` endpoint for configuration updates
    -   Create agent performance and monitoring endpoints
    -   Create agent benchmark and hardware management endpoints
    -   Create `POST /api/v1/control/agents/{id}/test_presigned` endpoint
    -   Add tests for all agent management endpoints
    -   _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7_

-   [ ] 16. Implement task management endpoints
    -   Create `GET /api/v1/control/tasks` endpoint with filtering and pagination
    -   Create `GET /api/v1/control/tasks/{id}` endpoint for task details
    -   Create `PATCH /api/v1/control/tasks/{id}/requeue` endpoint for task requeuing
    -   Create `POST /api/v1/control/tasks/{id}/cancel` endpoint for task cancellation
    -   Create `GET /api/v1/control/tasks/{id}/logs` endpoint for task log retrieval
    -   Create `GET /api/v1/control/tasks/{id}/performance` endpoint for performance metrics
    -   Create `GET /api/v1/control/tasks/{id}/status` endpoint for status monitoring
    -   Add tests for all task management endpoints
    -   _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7_

## Phase 6: Advanced Features (Enhanced Functionality)

-   [ ] 17. Implement crackable upload endpoints

    -   Create `POST /api/v1/control/uploads/` endpoint for file/hash text uploads
    -   Create `GET /api/v1/control/uploads/{id}/status` endpoint for upload status
    -   Create `POST /api/v1/control/uploads/{id}/launch_campaign` endpoint
    -   Create `GET /api/v1/control/uploads/{id}/errors` endpoint for upload errors
    -   Create `DELETE /api/v1/control/uploads/{id}` endpoint for upload deletion
    -   Create `GET /api/v1/control/uploads/{id}/preview` endpoint for result preview
    -   Add tests for crackable upload functionality
    -   _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7_

-   [ ] 18. Implement live monitoring endpoints
    -   Create `GET /api/v1/control/live/campaigns` endpoint for campaign status streams
    -   Create `GET /api/v1/control/live/agents` endpoint for agent status streams
    -   Create `GET /api/v1/control/live/tasks` endpoint for task status streams
    -   Create `GET /api/v1/control/live/system` endpoint for system health streams
    -   Implement JSON-formatted status updates instead of HTML SSE
    -   Add efficient polling mechanisms with appropriate update frequencies
    -   Add tests for live monitoring functionality
    -   _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7_

## Phase 7: State Management and Validation

-   [ ] 19. Implement state management utilities
    -   Create state validation utilities based on core algorithm guide
    -   Implement progress calculation functions for attacks and campaigns
    -   Add state transition enforcement to all lifecycle endpoints
    -   Create StateValidator class for task, attack, and campaign state transitions
    -   Add keyspace-weighted progress calculation functions
    -   Add tests for state management and validation
    -   _Requirements: 10.4, 11.4, 13.3_

## Phase 8: Performance and Optimization

-   [ ] 20. Implement caching and performance optimizations
    -   Add caching for system health data with appropriate TTL values
    -   Implement user project association caching
    -   Add query optimization for list endpoints
    -   Implement streaming responses for large datasets
    -   Add connection pooling and database optimization
    -   Add performance monitoring and metrics collection
    -   Add tests for performance optimizations
    -   _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_

## Phase 9: Documentation and Integration

-   [ ] 21. Update documentation to reflect Control API changes

    -   Update architecture documentation to include Control API
    -   Update API reference documentation with Control API endpoints
    -   Update user guide with Control API usage examples
    -   Update developer guide with Control API integration patterns
    -   Update getting started guide for administrators and users
    -   Update troubleshooting guide with Control API specific issues
    -   Update FAQ with Control API related questions
    -   _Requirements: All requirements need documentation coverage_

-   [ ] 22. Create comprehensive test suite
    -   Add unit tests for all service layer functions
    -   Add integration tests for all Control API endpoints
    -   Add contract tests to verify API responses match schemas
    -   Add authentication and authorization tests
    -   Add performance tests for high-load scenarios
    -   Add end-to-end tests for complete workflows
    -   Add security tests for API key handling and project scoping
    -   _Requirements: All requirements need test coverage_

## Phase 10: Missing Core Endpoints (High Priority)

-   [ ] 23. Complete hash type detection endpoints

    -   Create `POST /api/v1/control/hash/validate` endpoint for hash format validation
    -   Create `GET /api/v1/control/hash/types` endpoint for supported hash types
    -   Add tests for hash validation and supported types endpoints
    -   _Requirements: 8.2, 8.3_

-   [ ] 24. Add missing project management endpoints
    -   Create `POST /api/v1/control/projects/{id}/users` endpoint to add users to projects
    -   Create `DELETE /api/v1/control/projects/{id}/users/{user_id}` endpoint to remove users
    -   Add tests for user assignment/removal endpoints
    -   _Requirements: 6.6, 6.7_

## Phase 11: Deployment and Monitoring

-   [ ] 25. Prepare Control API for production deployment
    -   Configure API key settings and security parameters
    -   Set up rate limiting configuration
    -   Configure cache backend (Redis/memory)
    -   Set up error reporting and monitoring
    -   Create health check endpoints for load balancers
    -   Set up metrics collection and observability
    -   Create deployment documentation and runbooks
    -   _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_
