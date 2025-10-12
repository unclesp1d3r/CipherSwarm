# Implementation Plan

- [ ] 1. Set up database foundation and base model infrastructure

  - Create ActiveRecord connection pool configuration with PostgreSQL 17+
  - Implement base model pattern with id, created_at, updated_at fields
  - Set up Rails conventions for database connection management
  - Create health check endpoint for database connectivity
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ] 2. Implement User model and authentication system

  - [ ] 2.1 Create User model with authentication fields

    - Implement User ActiveRecord model with name, email, role fields
    - Add authentication tracking fields (sign_in_count, current_sign_in_at, etc.)
    - Add security fields (reset_password_token, unlock_token, failed_attempts)
    - Create unique indexes on email, name, and reset_password_token
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ] 2.2 Create User ActiveModel validations and schemas

    - Implement form objects and serializers for user creation, updates, and responses
    - Add validation for email format and role enum values
    - Include proper field descriptions and examples for OpenAPI
    - _Requirements: 2.1, 9.1, 9.2_

  - [ ] 2.3 Implement user service layer

    - Create UserService class in app/services/user_service.rb with CRUD operations
    - Implement create, find, list, update, and destroy methods
    - Add business logic for authentication tracking and security features
    - Include proper error handling with custom exceptions
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 9.4_

- [ ] 3. Implement Project model and organization system

  - [ ] 3.1 Create Project model with user associations

    - Implement Project ActiveRecord model with name, description, private fields
    - Add archived_at and notes optional fields
    - Create many-to-many association table with User model
    - Add unique index on project name
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ] 3.2 Create Project ActiveModel validations and service

    - Implement form objects and serializers for project creation, updates, and responses
    - Create ProjectService class in app/services/project_service.rb with CRUD operations and user association methods
    - Add validation for project name uniqueness and archival logic
    - _Requirements: 3.1, 3.2, 9.1, 9.4_

- [ ] 4. Implement OperatingSystem model

  - Create OperatingSystem ActiveRecord model with name enum and cracker_command
  - Implement enum validation in both ActiveModel and database constraints
  - Add unique index on name field
  - Create OperatingSystemService class in app/services/operating_system_service.rb with basic CRUD operations
  - _Requirements: 4.1, 4.2, 4.3, 9.2_

- [ ] 5. Implement Agent model and management system

  - [ ] 5.1 Create Agent model with comprehensive tracking

    - Implement Agent ActiveRecord model with identity fields (client_signature, host_name, custom_label)
    - Add authentication fields (token, last_seen_at, last_ipaddress)
    - Add state management fields (state enum, enabled boolean)
    - Add configuration fields (advanced_configuration JSON, devices array)
    - Create relationships with OperatingSystem, User, and Project models
    - Add indexes on token, state, and custom_label
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [ ] 5.2 Create Agent ActiveModel validations and schemas

    - Implement form objects and serializers for agent registration, updates, and responses
    - Add validation for state enum and device array structure
    - Include proper serialization for JSON fields
    - _Requirements: 5.1, 5.3, 5.4, 9.1, 9.2_

  - [ ] 5.3 Implement agent service layer

    - Create AgentService class in app/services/agent_service.rb with CRUD operations
    - Implement agent registration and state management logic
    - Add methods for project assignment and device management
    - Include token generation and validation logic
    - _Requirements: 5.1, 5.2, 5.3, 5.6, 9.4_

- [ ] 6. Implement AgentError model for error tracking

  - Create AgentError ActiveRecord model with message, severity, error_code fields
  - Add metadata JSON field and timestamp fields
  - Create relationships with Agent and Task models
  - Add indexes on agent_id and task_id
  - Create AgentErrorService class in app/services/agent_error_service.rb with CRUD operations
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 7. Implement Attack model and configuration system

  - [ ] 7.1 Create Attack model with comprehensive configuration

    - Implement Attack ActiveRecord model with basic fields (name, description, state, hash_type)
    - Add attack mode configuration (attack_mode enum)
    - Add mask attack fields (mask, increment_mode, increment_minimum, increment_maximum)
    - Add performance tuning fields (optimized, workload_profile, slow_candidate_generators)
    - Add Markov configuration fields (disable_markov, classic_markov, markov_threshold)
    - Add rule and charset fields (left_rule, right_rule, custom_charset_1-4)
    - Add scheduling fields (priority, start_time, end_time)
    - Create relationships with Campaign and resource lists
    - Add indexes on campaign_id and state
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9_

  - [ ] 7.2 Create Attack ActiveModel validations and service

    - Implement form objects and serializers for attack creation, updates, and responses
    - Add validation for all enum fields and configuration constraints
    - Create AttackService class in app/services/attack_service.rb with CRUD operations and configuration validation
    - _Requirements: 7.1, 7.2, 9.1, 9.2, 9.4_

- [ ] 8. Implement Task model and execution tracking

  - [ ] 8.1 Create Task model with progress tracking

    - Implement Task ActiveRecord model with state and stale fields
    - Add timing fields (start_date, end_date, completed_at)
    - Add progress tracking fields (progress_percent, progress_keyspace)
    - Add result storage field (result_json)
    - Create relationships with Agent and Attack models
    - Add indexes on agent_id, state, and completed_at
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7_

  - [ ] 8.2 Create Task ActiveModel validations and service

    - Implement form objects and serializers for task creation, updates, and responses
    - Add validation for state transitions and progress values
    - Create TaskService class in app/services/task_service.rb with CRUD operations and state management
    - _Requirements: 8.1, 8.3, 8.4, 9.1, 9.2, 9.4_

- [ ] 9. Create database migrations and enum definitions

  - [ ] 9.1 Define all enum classes

    - Create UserRole enum (admin, analyst, operator)
    - Create AgentState enum (pending, active, error, offline, disabled)
    - Create AttackMode enum (dictionary, brute_force, hybrid_dict, hybrid_mask)
    - Create TaskState enum (pending, dispatched, running, completed, failed, cancelled)
    - Ensure enum validation in both ActiveModel and ActiveRecord
    - _Requirements: 9.2_

  - [ ] 9.2 Generate database migrations

    - Generate initial migration for all models
    - Include all indexes, constraints, and relationships
    - Add enum type definitions and constraints
    - Test migration up and down operations
    - _Requirements: 9.3, 9.4_

- [ ] 10. Implement basic API endpoints

  - [ ] 10.1 Create user management endpoints

    - Implement POST /api/v1/users (create user)
    - Implement GET /api/v1/users (list users with pagination)
    - Implement GET /api/v1/users/{id} (get user by ID)
    - Implement PUT /api/v1/users/{id} (update user)
    - Implement DELETE /api/v1/users/{id} (delete user)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ] 10.2 Create project management endpoints

    - Implement POST /api/v1/projects (create project)
    - Implement GET /api/v1/projects (list projects with pagination)
    - Implement GET /api/v1/projects/{id} (get project by ID)
    - Implement PUT /api/v1/projects/{id} (update project)
    - Implement DELETE /api/v1/projects/{id} (delete project)
    - Implement POST /api/v1/projects/{id}/users (assign user to project)
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ] 10.3 Create agent management endpoints

    - Implement POST /api/v1/agents (register agent)
    - Implement GET /api/v1/agents (list agents with filtering)
    - Implement GET /api/v1/agents/{id} (get agent by ID)
    - Implement PUT /api/v1/agents/{id} (update agent)
    - Implement DELETE /api/v1/agents/{id} (delete agent)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

- [ ] 11. Create comprehensive test suite

  - [ ] 11.1 Create model unit tests

    - Write tests for all model creation and validation
    - Test enum constraints and field validation
    - Test relationship integrity and foreign key constraints
    - Test index effectiveness and query performance
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ] 11.2 Create service layer tests

    - Write unit tests for all service CRUD operations
    - Test business logic and validation rules
    - Test error handling and custom exceptions
    - Mock external dependencies and database operations
    - _Requirements: 9.4_

  - [ ] 11.3 Create API integration tests

    - Write integration tests for all endpoints
    - Test with real database using test containers
    - Test authentication and authorization flows
    - Test error responses and status codes
    - Test pagination and filtering functionality
    - _Requirements: 9.4_

- [ ] 12. Set up development environment and tooling

  - Configure ActiveRecord with proper connection pooling
  - Set up Rails migration system for database schema management
  - Configure RSpec with database fixtures and transactional tests
  - Set up FactoryBot factories for consistent test data
  - Create development database seeding scripts
  - _Requirements: 1.1, 1.2, 9.3, 9.4_
