# Implementation Plan

- [ ] 1. Set up database foundation and base model infrastructure

  - Create ActiveRecord connection pool configuration with PostgreSQL 17+
  - Implement base model pattern with id, created_at, updated_at fields
  - Set up Rails conventions for database connection management
  - Create health check endpoint for database connectivity
  - _Requirements: Requirement 1_

- [ ] 2. Implement User model and authentication system

  - [ ] 2.1 Create User model with authentication fields

    - Implement User ActiveRecord model with name, email, role fields
    - Add authentication tracking fields (sign_in_count, current_sign_in_at, etc.)
    - Add security fields (reset_password_token, unlock_token, failed_attempts)
    - Create unique indexes on email, name, and reset_password_token
    - _Requirements: Requirement 2_

  - [ ] 2.2 Create User ActiveModel validations and schemas

    - Implement form objects and serializers for user creation, updates, and responses
    - Add validation for email format and role enum values
    - Include proper field descriptions and examples for OpenAPI
    - _Requirements: Requirement 2, Requirement 9_

  - [ ] 2.3 Implement user service layer

    - Create UserService class in app/services/user_service.rb with CRUD operations
    - Implement create, find, list, update, and destroy methods
    - Add business logic for authentication tracking and security features
    - Include proper error handling with custom exceptions
    - _Requirements: Requirement 2, Requirement 9_

- [ ] 3. Implement Project model and organization system

  - [ ] 3.1 Create Project model with user associations

    - Implement Project ActiveRecord model with name, description, private fields
    - Add archived_at and notes optional fields
    - Create many-to-many association table with User model
    - Add unique index on project name
    - _Requirements: Requirement 3_

  - [ ] 3.2 Create Project ActiveModel validations and service

    - Implement form objects and serializers for project creation, updates, and responses
    - Create ProjectService class in app/services/project_service.rb with CRUD operations and user association methods
    - Add validation for project name uniqueness and archival logic
    - _Requirements: Requirement 3, Requirement 9_

- [ ] 4. Implement OperatingSystem model

  - Create OperatingSystem ActiveRecord model with name enum and cracker_command
  - Implement enum validation in both ActiveModel and database constraints
  - Add unique index on name field
  - Create OperatingSystemService class in app/services/operating_system_service.rb with basic CRUD operations
  - _Requirements: Requirement 4, Requirement 9_

- [ ] 5. Implement Agent model and management system

  - [ ] 5.1 Create Agent model with comprehensive tracking

    - Implement Agent ActiveRecord model with identity fields (client_signature, host_name, custom_label)
    - Add authentication fields (token, last_seen_at, last_ipaddress)
    - Add state management fields (state enum, enabled boolean)
    - Add configuration fields (advanced_configuration JSON, devices array)
    - Create relationships with OperatingSystem, User, and Project models
    - Add indexes on token, state, and custom_label
    - _Requirements: Requirement 5_

  - [ ] 5.2 Create Agent ActiveModel validations and schemas

    - Implement form objects and serializers for agent registration, updates, and responses
    - Add validation for state enum and device array structure
    - Include proper serialization for JSON fields
    - _Requirements: Requirement 5, Requirement 9_

  - [ ] 5.3 Implement agent service layer

    - Create AgentService class in app/services/agent_service.rb with CRUD operations
    - Implement agent registration and state management logic
    - Add methods for project assignment and device management
    - Include token generation and validation logic
    - _Requirements: Requirement 5, Requirement 9_

- [ ] 6. Implement AgentError model for error tracking

  - Create AgentError ActiveRecord model with message, severity, error_code fields
  - Add metadata JSON field and timestamp fields
  - Create relationships with Agent and Task models
  - Add indexes on agent_id and task_id
  - Create AgentErrorService class in app/services/agent_error_service.rb with CRUD operations
  - _Requirements: Requirement 6_

- [ ] 7. Implement Campaign model and organization system

  - [ ] 7.1 Create Campaign model with project and hash list associations

    - Implement Campaign ActiveRecord model with name, description, priority fields
    - Add soft delete support with deleted_at timestamp
    - Add attacks counter cache (attacks_count)
    - Create relationship with Project model (belongs_to :project)
    - Create relationship with HashList model (belongs_to :hash_list)
    - Add unique index on name field
    - Add indexes on project_id, hash_list_id, and deleted_at
    - _Requirements: Requirement 3_

  - [ ] 7.2 Create Campaign ActiveModel validations and schemas

    - Implement form objects and serializers for campaign creation, updates, and responses
    - Add validation for name presence and uniqueness
    - Add validation for priority enum values (-1 to 1: Deferred, Routine, Priority)
    - Add validation for project_id and hash_list_id presence
    - Include proper field descriptions and examples for OpenAPI
    - _Requirements: Requirement 9_

  - [ ] 7.3 Implement campaign service layer

    - Create CampaignService class in app/services/campaign_service.rb with CRUD operations
    - Implement create, find, list, update, and destroy methods
    - Add business logic for soft deletion and priority management
    - Add methods for listing campaigns by project
    - Include proper error handling with custom exceptions
    - _Requirements: Requirement 9_

  - [ ] 7.4 Create database migration for campaigns table

    - Generate migration to create campaigns table
    - Include name (string, not null), description (text)
    - Include hash_list_id (bigint, not null, FK), project_id (bigint, not null, FK)
    - Include attacks_count (integer, default 0, not null)
    - Include priority (integer, default 0, not null, comment: "-1: Deferred, 0: Routine, 1: Priority")
    - Include deleted_at (datetime) for soft deletion
    - Include timestamps (created_at, updated_at)
    - Add foreign key constraints with cascade delete for hash_lists and projects
    - Add indexes on hash_list_id, project_id, and deleted_at
    - _Requirements: Requirement 9_

  - [ ] 7.5 Create Campaign model tests

    - Write tests for campaign creation with valid attributes
    - Test validation rules for name, priority, associations
    - Test soft deletion behavior
    - Test counter cache for attacks_count
    - Test relationships with Project and HashList models
    - _Requirements: Requirement 9_

  - [ ] 7.6 Create Campaign service tests

    - Write unit tests for all CampaignService CRUD operations
    - Test business logic for priority management
    - Test soft deletion and listing with/without deleted records
    - Test error handling and custom exceptions
    - Test filtering campaigns by project
    - _Requirements: Requirement 9_

- [ ] 8. Implement Attack model and configuration system

  - [ ] 8.1 Create Attack model with comprehensive configuration

    - Implement Attack ActiveRecord model with basic fields (name, description, state, type)
    - Add attack mode configuration (attack_mode enum)
    - Add mask attack fields (mask, increment_mode, increment_minimum, increment_maximum)
    - Add performance tuning fields (optimized, workload_profile, slow_candidate_generators)
    - Add Markov configuration fields (disable_markov, classic_markov, markov_threshold)
    - Add rule and charset fields (left_rule, right_rule, custom_charset_1-4)
    - Add scheduling fields (priority, start_time, end_time)
    - Add soft delete support with deleted_at timestamp
    - Add complexity_value field for attack complexity tracking
    - Create relationship with Campaign model (belongs_to :campaign)
    - Create relationships with resource lists (word_list, rule_list, mask_list)
    - Add indexes on campaign_id, state, attack_mode, and deleted_at
    - _Requirements: Requirement 7_

  - [ ] 8.2 Create Attack ActiveModel validations and service

    - Implement form objects and serializers for attack creation, updates, and responses
    - Add validation for all enum fields and configuration constraints
    - Add validation for campaign_id presence
    - Create AttackService class in app/services/attack_service.rb with CRUD operations and configuration validation
    - _Requirements: Requirement 7, Requirement 9_

- [ ] 9. Implement Task model and execution tracking

  - [ ] 9.1 Create Task model with progress tracking

    - Implement Task ActiveRecord model with state and stale fields
    - Add timing fields (start_date, activity_timestamp, claimed_at, expires_at)
    - Add keyspace tracking fields (keyspace_offset, keyspace_limit)
    - Add retry mechanism fields (max_retries, retry_count, last_error)
    - Add optimistic locking with lock_version field
    - Create relationships with Agent and Attack models
    - Add claimed_by_agent_id for task claiming mechanism
    - Add indexes on agent_id, attack_id, state, activity_timestamp, expires_at, and claimed_by_agent_id
    - _Requirements: Requirement 8_

  - [ ] 9.2 Create Task ActiveModel validations and service

    - Implement form objects and serializers for task creation, updates, and responses
    - Add validation for state transitions and state enum values
    - Add validation for keyspace values and retry counts
    - Create TaskService class in app/services/task_service.rb with CRUD operations and state management
    - _Requirements: Requirement 8, Requirement 9_

- [ ] 10. Create database migrations and enum definitions

  - [ ] 10.1 Define all enum classes

    - Create UserRole enum (admin, analyst, operator)
    - Create AgentState enum (pending, active, error, offline, disabled)
    - Create AttackMode enum (dictionary, brute_force, hybrid_dict, hybrid_mask)
    - Create TaskState enum (pending, dispatched, running, completed, failed, cancelled)
    - Create CampaignPriority enum (-1 to 1: Deferred, Routine, Priority)
    - Ensure enum validation in both ActiveModel and ActiveRecord
    - _Requirements: Requirement 9_

  - [ ] 10.2 Generate database migrations

    - Generate initial migration for all models
    - Include all indexes, constraints, and relationships
    - Add enum type definitions and constraints
    - Test migration up and down operations
    - _Requirements: Requirement 9_

- [ ] 11. Implement basic API endpoints

  - [ ] 11.1 Create user management endpoints

    - Implement POST /api/v1/users (create user)
    - Implement GET /api/v1/users (list users with pagination)
    - Implement GET /api/v1/users/{id} (get user by ID)
    - Implement PUT /api/v1/users/{id} (update user)
    - Implement DELETE /api/v1/users/{id} (delete user)
    - _Requirements: Requirement 2_

  - [ ] 11.2 Create project management endpoints

    - Implement POST /api/v1/projects (create project)
    - Implement GET /api/v1/projects (list projects with pagination)
    - Implement GET /api/v1/projects/{id} (get project by ID)
    - Implement PUT /api/v1/projects/{id} (update project)
    - Implement DELETE /api/v1/projects/{id} (delete project)
    - Implement POST /api/v1/projects/{id}/users (assign user to project)
    - _Requirements: Requirement 3_

  - [ ] 11.3 Create agent management endpoints

    - Implement POST /api/v1/agents (register agent)
    - Implement GET /api/v1/agents (list agents with filtering)
    - Implement GET /api/v1/agents/{id} (get agent by ID)
    - Implement PUT /api/v1/agents/{id} (update agent)
    - Implement DELETE /api/v1/agents/{id} (delete agent)
    - _Requirements: Requirement 5_

- [ ] 12. Create comprehensive test suite

  - [ ] 12.1 Create model unit tests

    - Write tests for all model creation and validation
    - Test enum constraints and field validation
    - Test relationship integrity and foreign key constraints
    - Test index effectiveness and query performance
    - _Requirements: Requirement 9_

  - [ ] 12.2 Create service layer tests

    - Write unit tests for all service CRUD operations
    - Test business logic and validation rules
    - Test error handling and custom exceptions
    - Mock external dependencies and database operations
    - _Requirements: Requirement 9_

  - [ ] 12.3 Create API integration tests

    - Write integration tests for all endpoints
    - Test with real database using test containers
    - Test authentication and authorization flows
    - Test error responses and status codes
    - Test pagination and filtering functionality
    - _Requirements: Requirement 9_

- [ ] 13. Set up development environment and tooling

  - Configure ActiveRecord with proper connection pooling
  - Set up Rails migration system for database schema management
  - Configure RSpec with database fixtures and transactional tests
  - Set up FactoryBot factories for consistent test data
  - Create development database seeding scripts
  - _Requirements: Requirement 1, Requirement 9_
