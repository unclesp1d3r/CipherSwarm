# Requirements Document

## Introduction

This specification outlines the requirements for upgrading CipherSwarm from V1 to V2 while maintaining the existing Ruby on Rails + Hotwire technology stack. The upgrade focuses on delivering enhanced user experiences, improved real-time capabilities, and better operational management without requiring a complete rewrite to Python microservices.

The upgrade will build upon the existing Rails application's strong foundation including campaign orchestration, agent state management, project-based multi-tenancy, and Hotwire real-time features to deliver the V2 user stories and acceptance criteria.

## Requirements

### Requirement 1: Enhanced Authentication & Project Context Management

**User Story:** As a CipherSwarm user, I want to easily switch between projects and have role-based access controls that reflect my responsibilities, so that I can work efficiently within my assigned scope and maintain proper security boundaries.

#### Acceptance Criteria

1. WHEN a user logs in THEN the system SHALL display a project selector interface
2. WHEN a user selects an active project THEN the system SHALL persist this selection in their session
3. WHEN a user navigates the application THEN all data SHALL be filtered by their active project context
4. IF a user has multiple roles THEN the system SHALL enforce persona-specific permissions (Red Team, Blue Team, Infrastructure, Project Manager)
5. WHEN project membership changes THEN the system SHALL invalidate cached permissions immediately
6. WHEN a user switches projects THEN the system SHALL update the UI without requiring a full page reload

### Requirement 2: Real-Time Operations Dashboard

**User Story:** As an operations manager, I want a live dashboard showing agent status, campaign progress, and cracked hash feeds, so that I can monitor system health and respond quickly to issues.

#### Acceptance Criteria

1. WHEN the dashboard loads THEN the system SHALL display real-time agent health status
2. WHEN agents report status updates THEN the dashboard SHALL reflect changes within 5 seconds
3. WHEN hashes are cracked THEN the system SHALL stream results to the dashboard immediately
4. WHEN viewing hash rate trends THEN the system SHALL display 8-hour rolling averages
5. IF the dashboard has high update frequency THEN the system SHALL throttle updates to prevent performance degradation
6. WHEN multiple users view the dashboard THEN each SHALL receive personalized updates based on their project context

### Requirement 3: Enhanced Campaign Management with DAG Support

**User Story:** As a Red Team operator, I want to create campaigns using a guided wizard with dependency management, so that I can orchestrate complex attack sequences efficiently.

#### Acceptance Criteria

1. WHEN creating a campaign THEN the system SHALL provide a multi-step wizard interface
2. WHEN uploading files in the wizard THEN the system SHALL support direct uploads with progress tracking
3. WHEN configuring attacks THEN the system SHALL allow dependency relationships (DAG) between attacks
4. WHEN a campaign has dependencies THEN the system SHALL only execute attacks when prerequisites are complete
5. WHEN reordering attacks THEN the system SHALL provide drag-and-drop functionality
6. WHEN saving campaign configuration THEN the system SHALL validate all dependencies and file uploads

### Requirement 4: Advanced Agent Management & Task Distribution

**User Story:** As an infrastructure administrator, I want intelligent task distribution based on agent capabilities and campaign priorities, so that resources are utilized optimally.

#### Acceptance Criteria

1. WHEN agents register THEN the system SHALL collect capability information (GPU/CPU, hash types supported)
2. WHEN distributing tasks THEN the system SHALL match tasks to capable agents
3. WHEN multiple campaigns are active THEN the system SHALL respect priority-based scheduling
4. WHEN an agent becomes unavailable THEN the system SHALL reassign its tasks automatically
5. WHEN agent configuration changes THEN the system SHALL update task assignments accordingly
6. WHEN viewing agent status THEN the system SHALL display real-time performance metrics

### Requirement 5: Comprehensive Reporting & Analytics

**User Story:** As a Blue Team analyst, I want detailed reports on password patterns and cracking statistics, so that I can identify security weaknesses and trends.

#### Acceptance Criteria

1. WHEN generating reports THEN the system SHALL aggregate cracked password statistics by project
2. WHEN viewing trends THEN the system SHALL display historical data with configurable time ranges
3. WHEN exporting data THEN the system SHALL support multiple formats (CSV, JSON, PDF)
4. WHEN analyzing patterns THEN the system SHALL identify common password characteristics
5. WHEN scheduling reports THEN the system SHALL generate and deliver them automatically
6. WHEN accessing reports THEN the system SHALL enforce role-based visibility restrictions

### Requirement 6: Enhanced Collaboration Features

**User Story:** As a project manager, I want activity feeds and collaboration tools within projects, so that team members can coordinate effectively and track progress.

#### Acceptance Criteria

1. WHEN project activities occur THEN the system SHALL log them in a project timeline
2. WHEN viewing the timeline THEN users SHALL see real-time updates via live streaming
3. WHEN commenting on campaigns THEN the system SHALL notify relevant team members
4. WHEN significant events happen THEN the system SHALL broadcast notifications to project members
5. WHEN searching activity THEN the system SHALL provide filtering by user, date, and activity type
6. WHEN exporting project history THEN the system SHALL generate comprehensive audit reports

### Requirement 7: Production-Ready Deployment & Operations

**User Story:** As a system administrator, I want containerized deployment with monitoring and scaling capabilities, so that I can operate CipherSwarm reliably in production environments.

#### Acceptance Criteria

1. WHEN deploying the system THEN it SHALL use Docker containers with health checks
2. WHEN scaling is needed THEN the system SHALL support horizontal scaling of Rails and Sidekiq workers
3. WHEN monitoring performance THEN the system SHALL expose metrics for Prometheus/Grafana
4. WHEN errors occur THEN the system SHALL provide structured logging and alerting
5. WHEN backing up data THEN the system SHALL include automated backup procedures
6. WHEN updating the system THEN it SHALL support zero-downtime deployments

### Requirement 8: API Compatibility & Extension

**User Story:** As an agent developer, I want backward-compatible APIs with enhanced configuration capabilities, so that existing agents continue working while new features are available.

#### Acceptance Criteria

1. WHEN existing agents connect THEN the v1 API SHALL maintain full backward compatibility
2. WHEN new configuration is needed THEN the API SHALL provide extended endpoints
3. WHEN agents request tasks THEN the system SHALL consider agent capabilities in assignment
4. WHEN API responses are generated THEN they SHALL include comprehensive configuration data
5. WHEN documenting APIs THEN the system SHALL maintain up-to-date OpenAPI specifications
6. WHEN testing API changes THEN the system SHALL validate against existing agent contracts
