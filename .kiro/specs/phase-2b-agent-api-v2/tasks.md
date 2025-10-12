# Implementation Plan

- [ ] 1. Set up Agent API v2 foundation and routing structure

  - [ ] 1.1 Create v2 API controller infrastructure

    - Create `app/controllers/api/v2/base_controller.rb` for v2 base functionality
    - Create `app/controllers/api/v2/client_controller.rb` for client authentication
    - Create `app/controllers/api/v2/client/agents_controller.rb` for agent-specific actions
    - Create `app/controllers/api/v2/client/tasks_controller.rb` for task-specific actions
    - Create `app/controllers/api/v2/client/attacks_controller.rb` for attack-specific actions
    - Create `app/controllers/api/v2/client/resources_controller.rb` for resource-specific actions
    - Add v2 API routes to `config/routes.rb` under `namespace :api do; namespace :v2 do; namespace :client do` block
    - _Requirements: 1.1, 8.1_

  - [ ] 1.2 Set up routing and authentication

    - Set up proper Rails routing with tags and documentation in `config/routes.rb`
    - Implement base authentication concern for agent token validation
    - Create error handling concern specific to agent API
    - Define v2 routes within the API namespace in `config/routes.rb`
    - _Requirements: 1.1, 8.1, 9.1_

- [ ] 2. Implement agent registration endpoint

  - [ ] 2.1 Create registration request/response schemas

    - Extend `Agent` model in `app/models/agent.rb` with v2-specific methods if needed
    - Create input validation class in `app/inputs/agent_registration_input.rb` if complex validation required
    - Add field validation and constraints for all input fields
    - Use ActiveRecord validations and callbacks for business logic
    - _Requirements: 1.1, 1.2, 1.3_

  - [ ] 2.2 Implement registration logic

    - Add `register_v2` class method to `Agent` model in `app/models/agent.rb`
    - Generate secure token with format `csa_<agent_id>_<random_token>`
    - Handle duplicate registration attempts and existing agent updates
    - Add proper error handling for database constraints
    - _Requirements: 1.1, 1.4, 9.2_

  - [ ] 2.3 Create registration API endpoint

    - Implement `POST /api/v2/client/agents/register` endpoint in `app/controllers/api/v2/client/agents_controller.rb`
    - Add input validation and error response handling
    - Return 201 status code on successful registration
    - Handle validation errors (422) and conflicts (409)
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ] 3. Implement agent heartbeat system

  - [ ] 3.1 Create heartbeat schemas and validation

    - Add v2 heartbeat validation to `Agent` model in `app/models/agent.rb`
    - Add rate limiting validation for 15-second minimum interval
    - Use ActiveRecord validations for state transitions
    - _Requirements: 2.1, 2.3, 10.1_

  - [ ] 3.2 Implement heartbeat logic

    - Add `heartbeat_v2` method to `Agent` model in `app/models/agent.rb`
    - Update agent `last_seen_at`, `last_ipaddress`, and state fields
    - Track missed heartbeats and connection status
    - Implement agent state validation and transitions
    - _Requirements: 2.1, 2.2, 2.5, 3.1, 3.2, 3.3_

  - [ ] 3.3 Create heartbeat API endpoint with rate limiting

    - Implement `POST /api/v2/client/agents/heartbeat` endpoint in `app/controllers/api/v2/client/agents_controller.rb`
    - Add rate limiting concern (max 1 request per 15 seconds) in `app/controllers/concerns/rate_limitable.rb`
    - Handle authentication and agent token validation
    - Return appropriate status codes (204, 401, 429)
    - _Requirements: 2.1, 2.2, 2.4, 10.1, 10.2_

- [ ] 4. Implement attack configuration system

  - [ ] 4.1 Create attack configuration schemas

    - Add v2-specific serialization methods to `Attack` model in `app/models/attack.rb`
    - Include mask, rules, and resource reference fields in serialization
    - Add forward-compatibility fields for Phase 3 resource management
    - Create corresponding jbuilder view if needed in `app/views/api/v2/client/attacks/`
    - _Requirements: 3.1, 3.4_

  - [ ] 4.2 Implement attack configuration logic

    - Add `configuration_v2` method to `Attack` model in `app/models/attack.rb`
    - Validate agent capability against hash type requirements
    - Fetch complete attack specification from database
    - Handle authorization and resource access validation
    - _Requirements: 3.1, 3.2, 3.5_

  - [ ] 4.3 Create attack configuration endpoint

    - Implement `GET /api/v2/client/attacks/{attack_id}` endpoint in `app/controllers/api/v2/client/attacks_controller.rb`
    - Add agent authentication and capability validation
    - Return 404 for non-existent or unauthorized attacks
    - Include proper error handling and status codes
    - _Requirements: 3.1, 3.2, 3.5_

- [ ] 5. Implement task assignment system

  - [ ] 5.1 Create task assignment schemas

    - Add v2-specific serialization to `Task` model in `app/models/task.rb`
    - Include hash file references and dictionary IDs (Phase 3 compatible)
    - Add skip and limit fields for keyspace distribution
    - Create corresponding jbuilder view in `app/views/api/v2/client/tasks/`
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ] 5.2 Implement task assignment logic

    - Add `assign_next_v2` class method to `Task` model in `app/models/task.rb`
    - Enforce one task per agent constraint
    - Find suitable tasks based on agent capabilities
    - Calculate and assign keyspace chunks for parallel processing
    - _Requirements: 4.1, 4.2, 4.4, 4.5_

  - [ ] 5.3 Create task assignment endpoint

    - Implement `GET /api/v2/client/tasks/next` endpoint in `app/controllers/api/v2/client/tasks_controller.rb`
    - Handle cases where no tasks are available
    - Prevent multiple task assignments to same agent
    - Return appropriate responses for different scenarios
    - _Requirements: 4.1, 4.4, 4.5_

- [ ] 6. Implement progress tracking system

  - [ ] 6.1 Create progress update schemas

    - Add progress validation to `Task` model in `app/models/task.rb`
    - Add validation for progress values (0-100% range)
    - Include optional estimated completion and current speed fields
    - Use ActiveRecord validations for constraints
    - _Requirements: 5.1, 5.3_

  - [ ] 6.2 Implement progress update logic

    - Add `update_progress_v2` method to `Task` model in `app/models/task.rb`
    - Validate task ownership and agent authorization
    - Update task progress tracking in real-time
    - Handle invalid progress data and edge cases
    - _Requirements: 5.1, 5.2, 5.4, 5.5_

  - [ ] 6.3 Create progress update endpoint

    - Implement `POST /api/v2/client/tasks/{task_id}/progress` endpoint in `app/controllers/api/v2/client/tasks_controller.rb`
    - Add task ID validation and agent ownership checks
    - Return appropriate status codes for different scenarios
    - Handle completed or non-existent tasks properly
    - _Requirements: 5.1, 5.2, 5.3, 5.5_

- [ ] 7. Implement result submission system

  - [ ] 7.1 Create result submission schemas

    - Add result validation to `Task` model in `app/models/task.rb`
    - Add JSON validation for hash format and structure using ActiveModel
    - Include error handling fields for failed tasks
    - Consider creating `app/inputs/task_result_input.rb` if complex validation needed
    - _Requirements: 6.1, 6.2, 6.5_

  - [ ] 7.2 Implement result processing logic

    - Add `submit_results_v2` method to `Task` model in `app/models/task.rb`
    - Validate hash format and associate with correct hash list
    - Handle duplicate result detection and prevention
    - Update campaign statistics and progress automatically
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ] 7.3 Create result submission endpoint

    - Implement `POST /api/v2/client/tasks/{task_id}/results` endpoint in `app/controllers/api/v2/client/tasks_controller.rb`
    - Add comprehensive input validation and error handling
    - Update task status and campaign progress
    - Broadcast success notifications for real-time updates
    - _Requirements: 6.1, 6.4, 6.5_

- [ ] 8. Implement resource management system

  - [ ] 8.1 Create presigned URL schemas

    - Add v2 serialization for resource models (WordList, RuleList, MaskList, etc.)
    - Add resource type validation and access control fields
    - Include hash verification requirements in response
    - Create jbuilder views in `app/views/api/v2/client/resources/`
    - _Requirements: 7.1, 7.3_

  - [ ] 8.2 Implement presigned URL generation logic

    - Add `generate_presigned_url_v2` method to resource models or create concern in `app/models/concerns/presignable.rb`
    - Generate time-limited URLs for ActiveStorage/S3 resources
    - Enforce hash verification requirements before task execution
    - Handle authorization and resource access validation
    - _Requirements: 7.1, 7.2, 7.4, 7.5_

  - [ ] 8.3 Create resource URL endpoint

    - Implement `GET /api/v2/client/resources/{resource_id}/url` endpoint in `app/controllers/api/v2/client/resources_controller.rb`
    - Add resource authorization and agent validation
    - Return 403 for unauthorized resource access
    - Handle expired or missing resources appropriately
    - _Requirements: 7.1, 7.3, 7.4, 7.5_

- [ ] 9. Implement authentication and authorization system

  - [ ] 9.1 Create agent token validation

    - Create `AgentAuthenticatable` concern in `app/controllers/concerns/agent_authenticatable.rb`
    - Implement `authenticate_agent_v2` method to parse and validate `csa_<agent_id>_<token>` format
    - Add token expiration and revocation support
    - Handle malformed or invalid tokens with proper errors
    - _Requirements: 9.1, 9.2, 9.4, 9.5_

  - [ ] 9.2 Implement token management

    - Add token generation methods to `Agent` model in `app/models/agent.rb` with cryptographic security
    - Add token revocation and renewal capabilities
    - Implement usage tracking and monitoring
    - Add automatic cleanup of expired tokens using background job
    - _Requirements: 9.2, 9.3, 9.5_

  - [ ] 9.3 Add comprehensive authorization checks

    - Implement resource-level authorization for agents in `Agent` model or create concern
    - Add project-scoped access control where applicable using existing CanCanCan patterns
    - Validate agent permissions for specific operations
    - Handle disabled or suspended agent accounts
    - _Requirements: 9.1, 9.3, 9.4_

- [ ] 10. Implement rate limiting and resource management

  - [ ] 10.1 Create rate limiting

    - Create `RateLimitable` concern in `app/controllers/concerns/rate_limitable.rb`
    - Implement per-agent rate limiting for heartbeats (15-second minimum) using Redis
    - Add global system rate limits for API endpoints
    - Create exponential backoff for rate limit violations
    - Return 429 status codes with retry-after headers
    - _Requirements: 10.1, 10.2, 10.4_

  - [ ] 10.2 Implement resource cleanup and management

    - Add automatic cleanup methods to `Agent` model in `app/models/agent.rb`
    - Create background job in `app/jobs/cleanup_disconnected_agents_job.rb`
    - Implement task reassignment for failed agents in `Task` model
    - Handle resource constraints and prioritization
    - Add monitoring for system resource usage
    - _Requirements: 10.3, 10.5_

- [x] 11. Maintain backward compatibility with v1 API

  - [x] 11.1 Ensure v1 endpoint compatibility

    - Verify all existing v1 endpoints continue to work unchanged
    - Test `GET /api/v1/client/agents/{id}` endpoint functionality
    - Validate `POST /api/v1/client/agents/{id}/benchmark` compatibility
    - Ensure error and shutdown endpoints work correctly
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [x] 11.2 Implement dual API support infrastructure

    - Create shared service layer for common operations between v1 and v2
    - Ensure database operations work for both API versions
    - Add version detection and routing logic
    - Handle concurrent v1 and v2 agent operations
    - _Requirements: 8.6_

- [ ] 12. Add comprehensive testing suite

  - [ ] 12.1 Create unit tests for models

    - Test agent registration with various input scenarios in `spec/models/agent_spec.rb`
    - Test heartbeat processing with state transitions and edge cases
    - Test task assignment logic with capability validation in `spec/models/task_spec.rb`
    - Test result processing with duplicate detection and validation
    - _Requirements: All requirements - validation through testing_

  - [ ] 12.2 Create integration tests for API endpoints

    - Test complete registration flow with database persistence in `spec/requests/api/v2/client/agents_spec.rb`
    - Test heartbeat endpoint with rate limiting and authentication
    - Test task assignment and progress tracking workflows in `spec/requests/api/v2/client/tasks_spec.rb`
    - Test result submission with real database operations
    - Test attack configuration in `spec/requests/api/v2/client/attacks_spec.rb`
    - _Requirements: All requirements - end-to-end validation_

  - [ ] 12.3 Create contract tests for API compatibility

    - Use rswag for OpenAPI documentation in integration specs
    - Test backward compatibility with v1 API contracts
    - Verify error response formats match specifications
    - Test rate limiting behavior and response codes
    - Run `rails rswag:specs:swaggerize` to generate documentation
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

- [ ] 13. Add monitoring, logging, and observability

  - [ ] 13.1 Implement comprehensive logging

    - Add structured logging for all agent operations using Rails.logger
    - Log authentication events and security-related activities
    - Include performance metrics and timing information
    - Add error tracking with appropriate log levels
    - _Requirements: 9.1, 9.3, 10.4_

  - [ ] 13.2 Add metrics collection and monitoring

    - Track agent registration and heartbeat rates using existing event service
    - Monitor task assignment latency and success rates
    - Collect result submission metrics and error rates
    - Add system resource usage monitoring
    - _Requirements: 10.3, 10.4, 10.5_

- [ ] 14. Create documentation and deployment configuration

  - [ ] 14.1 Generate OpenAPI documentation

    - Create comprehensive API documentation for all v2 endpoints using Rails automatic documentation
    - Include request/response examples and error codes in endpoint docstrings
    - Document authentication requirements and token formats
    - Add migration guide from v1 to v2 API in `docs/api/agent-api-v2-migration.md`
    - _Requirements: All requirements - documentation_

  - [ ] 14.2 Add deployment and configuration management

    - Create environment variable configuration for API settings in `config/application.rb` and environment-specific files
    - Add Docker configuration for containerized deployment (already exists)
    - Include monitoring and alerting configuration
    - Document scaling and performance considerations
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
