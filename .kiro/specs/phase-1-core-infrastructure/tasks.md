# Implementation Plan

- [ ] 1. Validate and consolidate existing database foundation

  - Verify ActiveRecord connection pool configuration with PostgreSQL
  - Confirm base model patterns are consistent across all models
  - Validate Rails conventions for database connection management
  - Create or verify health check endpoint for database connectivity
  - _Requirements: Requirement 1_

- [ ] 2. Consolidate User model and authentication system

  - [ ] 2.1 Validate existing User model implementation

    - Review current Devise-based User model for completeness
    - Verify authentication tracking fields are properly configured
    - Confirm security fields and validations meet requirements
    - Validate existing indexes on email, name, and reset_password_token
    - _Requirements: Requirement 2_

  - [ ] 2.2 Create User service layer for business logic

    - Extract business logic from User model into UserService class
    - Create app/services/user_service.rb with CRUD operations
    - Implement user management methods (create, find, list, update, destroy)
    - Add proper error handling with custom exceptions
    - _Requirements: Requirement 2, Requirement 9_

  - [ ] 2.3 Enhance User model validations and API serialization

    - Review and enhance existing User model validations
    - Create API serializers for user responses
    - Ensure proper field descriptions for OpenAPI documentation
    - Add any missing validation rules for role enum values
    - _Requirements: Requirement 2, Requirement 9_

- [ ] 3. Consolidate Project model and organization system

  - [ ] 3.1 Validate existing Project model implementation

    - Review current Project model and associations
    - Verify project_users join table implementation
    - Confirm project name uniqueness validation
    - Validate relationships with campaigns, hash_lists, and agents
    - _Requirements: Requirement 3_

  - [ ] 3.2 Create Project service layer

    - Extract business logic from Project model into ProjectService class
    - Create app/services/project_service.rb with CRUD operations
    - Implement user association management methods
    - Add project archival logic if needed (currently not in schema)
    - _Requirements: Requirement 3, Requirement 9_
    - _Requirements: Requirement 3, Requirement 9_

- [ ] 4. Create missing OperatingSystem model

  - Create OperatingSystem ActiveRecord model with name enum and cracker_command
  - Implement enum validation matching Agent model's operating_system field
  - Add unique index on name field and proper validations
  - Create OperatingSystemService class in app/services/operating_system_service.rb
  - Update Agent model to reference OperatingSystem instead of enum
  - _Requirements: Requirement 4, Requirement 9_

- [ ] 5. Consolidate Agent model and management system

  - [ ] 5.1 Validate existing Agent model implementation

    - Review current Agent model with state machine implementation
    - Verify authentication fields (token, last_seen_at, last_ipaddress)
    - Confirm state management and JSONB configuration fields
    - Validate relationships with User and Projects (HABTM)
    - Check indexes on token, state, and custom_label
    - _Requirements: Requirement 5_

  - [ ] 5.2 Create Agent service layer

    - Extract business logic from Agent model into AgentService class
    - Create app/services/agent_service.rb with CRUD operations
    - Implement agent registration and state management logic
    - Add methods for project assignment and device management
    - Include token generation and validation logic
    - _Requirements: Requirement 5, Requirement 9_

  - [ ] 5.3 Enhance Agent model validations and API serialization

    - Review and enhance existing Agent model validations
    - Create API serializers for agent registration and responses
    - Ensure proper serialization for JSONB fields
    - Add validation for device array structure
    - _Requirements: Requirement 5, Requirement 9_

- [ ] 6. Enhance AgentError model for comprehensive error tracking

  - Review existing AgentError model implementation
  - Add missing error_code field if not present
  - Enhance severity enum and validation rules
  - Verify relationships with Agent and Task models
  - Create AgentErrorService class in app/services/agent_error_service.rb
  - _Requirements: Requirement 6_

- [ ] 7. Consolidate Campaign model and organization system

  - [ ] 7.1 Validate existing Campaign model implementation

    - Review current Campaign model with extended priority enum (-1 to 5)
    - Verify soft delete support with acts_as_paranoid
    - Confirm attacks counter cache implementation
    - Validate relationships with Project and HashList models
    - Check indexes on project_id, hash_list_id, and deleted_at
    - _Requirements: Requirement 3_

  - [ ] 7.2 Create Campaign service layer

    - Extract business logic from Campaign model into CampaignService class
    - Create app/services/campaign_service.rb with CRUD operations
    - Implement priority-based campaign management logic
    - Add methods for listing campaigns by project
    - Include proper error handling with custom exceptions
    - _Requirements: Requirement 9_

  - [ ] 7.3 Enhance Campaign model validations and API serialization

    - Review and enhance existing Campaign model validations
    - Create API serializers for campaign creation, updates, and responses
    - Ensure proper field descriptions for OpenAPI documentation
    - Validate priority enum values and business rules
    - _Requirements: Requirement 9_

- [ ] 8. Consolidate Attack model and configuration system

  - [ ] 8.1 Validate existing Attack model implementation

    - Review current Attack model with comprehensive hashcat configuration
    - Verify attack mode enum uses correct hashcat values (0, 3, 6, 7)
    - Confirm state machine implementation with proper transitions
    - Validate relationships with Campaign and resource lists (word_list, rule_list, mask_list)
    - Check soft delete support and complexity_value tracking
    - _Requirements: Requirement 7_

  - [ ] 8.2 Create Attack service layer

    - Extract business logic from Attack model into AttackService class
    - Create app/services/attack_service.rb with CRUD operations
    - Implement attack configuration validation logic
    - Add complexity calculation and state management methods
    - Include proper error handling with custom exceptions
    - _Requirements: Requirement 7, Requirement 9_

- [ ] 9. Consolidate Task model and execution tracking

  - [ ] 9.1 Validate existing Task model implementation

    - Review current Task model with state machine implementation
    - Verify timing fields (start_date, activity_timestamp, claimed_at, expires_at)
    - Confirm keyspace tracking and retry mechanism fields
    - Validate optimistic locking with lock_version field
    - Check relationships with Agent and Attack models
    - Verify indexes on critical fields for performance
    - _Requirements: Requirement 8_

  - [ ] 9.2 Create Task service layer

    - Extract business logic from Task model into TaskService class
    - Create app/services/task_service.rb with CRUD operations
    - Implement task assignment and state management logic
    - Add progress tracking and retry mechanism methods
    - Include proper error handling with custom exceptions
    - _Requirements: Requirement 8, Requirement 9_

- [ ] 10. Validate database schema and enum definitions

  - [ ] 10.1 Review existing enum implementations

    - Validate User role enum (basic: 0, admin: 1) matches requirements
    - Review Agent operating_system enum (unknown, linux, windows, darwin, other)
    - Confirm Attack attack_mode enum uses correct hashcat values
    - Verify Campaign priority enum (-1 to 5: deferred to flash_override)
    - Ensure all enums have proper validation in both ActiveModel and database
    - _Requirements: Requirement 9_

  - [ ] 10.2 Create missing database migrations if needed

    - Review existing migrations for completeness
    - Create OperatingSystem model migration if needed
    - Add any missing indexes or constraints
    - Ensure all foreign key relationships are properly defined
    - _Requirements: Requirement 9_

- [ ] 11. Implement missing API endpoints

  - [ ] 11.1 Create basic user management API endpoints

    - Implement GET /api/v1/users (list users with pagination)
    - Implement GET /api/v1/users/{id} (get user by ID)
    - Implement PUT /api/v1/users/{id} (update user)
    - Add proper authentication and authorization
    - _Requirements: Requirement 2_

  - [ ] 11.2 Create basic project management API endpoints

    - Implement POST /api/v1/projects (create project)
    - Implement GET /api/v1/projects (list projects with pagination)
    - Implement GET /api/v1/projects/{id} (get project by ID)
    - Implement PUT /api/v1/projects/{id} (update project)
    - Implement POST /api/v1/projects/{id}/users (assign user to project)
    - _Requirements: Requirement 3_

  - [ ] 11.3 Enhance existing agent management API endpoints

    - Review existing agent API endpoints for completeness
    - Add any missing CRUD operations
    - Ensure proper filtering and pagination
    - Validate authentication and authorization
    - _Requirements: Requirement 5_

- [ ] 12. Create comprehensive test suite with full coverage

  - [ ] 12.1 Enhance existing model tests

    - Review existing model tests for completeness
    - Add tests for any missing validations or relationships
    - Test state machine transitions and callbacks for Agent, Campaign, Attack, Task
    - Test enum constraints and field validation
    - Test association integrity and foreign key constraints
    - Test model scopes and query methods
    - _Requirements: Requirement 9_

  - [ ] 12.2 Create comprehensive service layer tests

    - Write unit tests for UserService CRUD operations and business logic
    - Write unit tests for ProjectService CRUD operations and user associations
    - Write unit tests for AgentService registration and state management
    - Write unit tests for CampaignService priority management and soft deletion
    - Write unit tests for AttackService configuration validation
    - Write unit tests for TaskService assignment and progress tracking
    - Test error handling and custom exceptions for all services
    - Mock external dependencies and database operations appropriately
    - _Requirements: Requirement 9_

  - [ ] 12.3 Create API integration tests

    - Write integration tests for user management API endpoints
    - Write integration tests for project management API endpoints
    - Write integration tests for agent management API endpoints
    - Test authentication and authorization flows for all endpoints
    - Test error responses and status codes
    - Test pagination and filtering functionality
    - Test request/response serialization
    - Use existing test infrastructure and patterns
    - _Requirements: Requirement 9_

  - [ ] 12.4 Create system and performance tests

    - Write system tests for complete user workflows
    - Test database performance with proper indexing
    - Test concurrent access and optimistic locking
    - Test state machine transitions under load
    - Validate memory usage and query optimization
    - _Requirements: Requirement 9_

- [ ] 13. Validate development environment and tooling

  - Verify ActiveRecord connection pooling configuration
  - Confirm Rails migration system is properly configured
  - Validate RSpec configuration and existing test patterns
  - Review FactoryBot factories for consistency
  - Ensure development database seeding works correctly
  - _Requirements: Requirement 1, Requirement 9_
