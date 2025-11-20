# CipherSwarm

[![GitHub](https://img.shields.io/github/license/unclesp1d3r/CipherSwarm)](https://github.com/unclesp1d3r/CipherSwarm/blob/main/LICENSE) [![GitHub issues](https://img.shields.io/github/issues/unclesp1d3r/CipherSwarm)](https://github.com/unclesp1d3r/CipherSwarm/issues) [![GitHub last commit](https://img.shields.io/github/last-commit/unclesp1d3r/CipherSwarm)](https://github.com/unclesp1d3r/CipherSwarm/graphs/commit-activity) ![Maintenance](https://img.shields.io/maintenance/yes/2025) [![wakatime](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm.svg)](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm)

[![Maintainability](https://api.codeclimate.com/v1/badges/347fc7e944ae3b9a5111/maintainability)](https://codeclimate.com/github/unclesp1d3r/CipherSwarm/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/347fc7e944ae3b9a5111/test_coverage)](https://codeclimate.com/github/unclesp1d3r/CipherSwarm/test_coverage)

CipherSwarm is a distributed hash cracking system designed for efficiency and scalability and built on Ruby on Rails. Inspired by the principles of Hashtopolis, CipherSwarm leverages the power of collaborative computing to tackle complex cryptographic challenges, offering a web-based interface for managing and distributing hash-cracking tasks across multiple nodes.

## 🚀 CipherSwarm V2 Upgrade

CipherSwarm is currently undergoing a comprehensive V2 upgrade that transforms the platform from a functional tool into a modern, user-friendly distributed password cracking platform. The upgrade maintains the existing Ruby on Rails + Hotwire technology stack while delivering:

- **Enhanced User Experience**: Real-time dashboards, guided workflows, and intuitive interfaces
- **Advanced Collaboration**: Multi-user coordination with role-based access controls
- **Intelligent Automation**: Smart task distribution and dependency management
- **Enterprise Features**: Production-ready deployment, comprehensive monitoring, and analytics

For detailed information about the V2 upgrade, see the [V2 Upgrade Overview](docs/v2-upgrade-overview.md).

> [!CAUTION]
> This project is currently under active development and is not ready for production. Please use it with caution.

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [CipherSwarm](#cipherswarm)
  - [🚀 CipherSwarm V2 Upgrade](#%F0%9F%9A%80-cipherswarm-v2-upgrade)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Getting Started](#getting-started)
  - [Usage](#usage)
  - [Architecture](#architecture)
  - [Documentation](#documentation-1)
  - [Contributing](#contributing)
  - [Acknowledgments](#acknowledgments)

<!-- mdformat-toc end -->

## Features

### Current V1 Features

- Distributed hash-cracking tasks managed through a web interface
- Scalable architecture to efficiently distribute workloads across multiple agents
- Integration with hashcat for versatile hash cracking capabilities
- Campaign and attack management with priority-based execution
- Project-based multi-tenancy with role-based access control

### Upcoming V2 Features

- **Real-time Operations Dashboard**: Live agent monitoring, campaign progress, and crack result feeds
- **Enhanced Campaign Management**: Guided wizard with DAG-based attack dependencies
- **Advanced Agent Management**: Intelligent task distribution based on agent capabilities
- **Comprehensive Analytics**: Password pattern analysis and security insights
- **Team Collaboration**: Activity feeds, commenting, and project coordination
- **Production-Ready Deployment**: Containerized deployment with monitoring and scaling

See the [V2 Upgrade Overview](docs/v2-upgrade-overview.md) for complete feature details.

## Getting Started

### Prerequisites

- Ruby 3.4.5 (managed with rbenv)
- Rails 8.0+
- PostgreSQL 17+ (primary database)
- Redis 7.2+ (for Solid Cache and Sidekiq job processing)
- [Just](https://github.com/casey/just) task runner (optional but recommended)

### Installation

1. Clone the repository to your local machine:

   ```bash
   git clone https://github.com/unclesp1d3r/CipherSwarm.git
   cd CipherSwarm
   ```

2. Install dependencies and setup the database:

   Using Just (recommended):

   ```bash
   just install
   just setup
   ```

   Or manually:

   ```bash
   bundle install
   yarn install
   rails db:create
   rails db:migrate
   ```

3. Start the development server:

   Using Just:

   ```bash
   just dev
   ```

   Or manually:

   ```bash
   bin/dev
   ```

   This starts Rails, asset compilation, and Sidekiq workers.

4. Access the application at <http://localhost:3000>

#### Quick Start with Just

CipherSwarm includes a `justfile` for common development tasks. See all available commands:

```bash
just --list
```

Common commands:

- `just install` - Install all dependencies
- `just setup` - Setup database and configuration
- `just dev` - Start full development environment
- `just test` - Run all tests with coverage
- `just check` - Run linters and security checks
- `just db-reset` - Reset database

### System Tests (UI/UX Testing)

CipherSwarm includes comprehensive UI tests implemented using Capybara and Selenium WebDriver. These tests provide end-to-end coverage for critical user workflows:

- **Authentication**: Sign in, password reset, account management
- **Agent Management**: Create, edit, delete agents with authorization checks
- **Campaign and Attack Workflows**: Create campaigns, add attacks, manage nested resources
- **File Upload Operations**: Hash lists, word lists, and other file resources with Active Storage
- **Admin User Management**: User creation, locking/unlocking, role management
- **Navigation and Authorization**: Navbar, sidebar, access control verification
- **Error Handling**: Validation errors, authorization errors, error pages

#### Running System Tests

```bash
# Run all system tests
bundle exec rspec spec/system

# Run specific test directory
bundle exec rspec spec/system/agents

# Run with visible browser for debugging
HEADLESS=false bundle exec rspec spec/system
```

#### Documentation

For detailed information on writing and maintaining system tests, see the [System Tests Guide](docs/testing/system-tests-guide.md).

The test suite uses the **Page Object Pattern** for maintainability, with page objects located in `spec/support/page_objects/`. Screenshots are automatically captured on test failures and saved to `tmp/capybara/`.

#### CI/CD

System tests run automatically in GitHub Actions as part of the test suite. Test results and screenshots from failed tests are available as artifacts.

See `.kiro/steering/justfile.md` for complete command documentation.

### Docker Installation

The quickest way to get CipherSwarm up and running is to use Docker. The following steps will guide you through the process:

1. Clone the repository to your local machine:

   ```bash
   git clone https://github.com/unclesp1d3r/CipherSwarm.git
   cd CipherSwarm
   ```

2. Deploy the Docker containers:

   ```bash
   docker compose -f docker-compose-production.yml up
   ```

3. Access the CipherSwarm web interface at <http://localhost:3000>.

4. Log in with the default admin credentials (username: admin, password: password) and change the password immediately.

### Project Assumptions and Target Audience

CipherSwarm, while performing functions similar to Hashtopolis, is not a reiteration of the latter. It is a unique project, conceived with a specific target audience in mind and shaped by several guiding assumptions:

1. **Cracking Tool**: CipherSwarm exclusively supports Hashcat as the cracking tool.

2. **Connectivity**: All clients connected to CipherSwarm are assumed to use a reliable, high-speed connection, typically found in a Local Area Network (LAN) environment.

3. **Trust Level**: CipherSwarm operates under the assumption that all client machines are trustworthy and are under the direct control and management of the user utilizing CipherSwarm.

4. **User Base**: The system assumes that users, though having different levels of administrative access, belong to the same organization or project team, ensuring a level of trust and common purpose.

5. **Hashlist Management**: CipherSwarm is designed to handle hash lists derived from various projects or operations. Depending on access privileges, it lets users view results from specific projects or across all projects.

6. **Client-Project Affiliation**: Cracking clients can be associated with specific projects, executing operations solely for that project. Alternatively, they can perform operations across all projects, with defined priorities for particular projects.

CipherSwarm is crafted explicitly for medium to large-scale cracking infrastructure, interconnected via high-speed networks. It does not support utilization over the Internet or integration with anonymous user systems acting as cracking clients. By focusing on secure, centralized, and high-performance environments, CipherSwarm delivers tailored scalability and efficiency to meet the demands of sophisticated cracking operations.

## Usage

1. Access the CipherSwarm web interface at <http://localhost:3000>.
2. Log in with the default admin credentials (username: admin, password: password) and change the password immediately.
3. Add nodes to your network through the interface.
4. Create new cracking tasks, specifying the hash types and input files.
5. Monitor the progress of your tasks in real-time through the dashboard.

## Architecture

CipherSwarm is built on a modern Rails 8.0+ architecture with clear separation of concerns and service-oriented design patterns. The system follows Rails conventions while implementing a distributed password cracking management system.

### System Architecture

The application uses a monolithic Rails architecture with the following layers:

- **Web Interface Layer**: Controllers, Views, and ViewComponents using Hotwire (Turbo + Stimulus)
- **Service Layer**: Business logic, state management, and validation services
- **Model Layer**: ActiveRecord models with associations and validations
- **Data Layer**: PostgreSQL 17+ database with Redis for caching and background jobs

### Authentication & Authorization

- **Web UI**: Rails 8 built-in authentication with secure session cookies
- **Agent API**: Bearer token authentication for distributed agents
- **Authorization**: Project-based multi-tenancy with role-based access control

### Key Technologies

- **Ruby 3.4.5** with **Rails 8.0+**
- **PostgreSQL 17+** for primary data storage
- **Redis 7.2+** for Solid Cache and Sidekiq job processing
- **Hotwire** (Turbo + Stimulus) for interactive frontend
- **ViewComponent** for reusable UI components
- **Sidekiq** for background job processing

### Data Concepts

In the CipherSwarm system, hashcat cracking jobs are managed around four core objects: Campaigns, Attacks, Templates, and Tasks. Understanding these objects and their interrelations is critical to effectively leveraging the system for distributed hash cracking.

#### Campaigns

Campaigns represent a comprehensive unit of work focused on a single hash list. Each Campaign is designed to achieve a specific goal, such as recovering passwords from a set of hashes. A Campaign may encompass multiple Attacks, each tailored to run against the Campaign's hash list using different strategies or parameters. Campaigns facilitate the organization and prioritization of attacks, allowing for sequential execution based on priority or effectiveness.

#### Attacks

An Attack is a defined unit of hashcat work characterized by its attack type and the word list and rules it employs. An attack embodies a specific approach to cracking hashes, such as brute force or dictionary attacks, complete with all necessary parameters. Large attacks can be subdivided into Tasks to distribute the workload across multiple Agents, enabling parallel processing and thus speeding up the cracking process.

#### Templates

A Template serves as a reusable definition of an attack. It specifies the attack type and parameters (such as word lists and rules) but is not bound to a specific hash list. Templates allow for the rapid configuration of new attacks by applying a pre-defined set of strategies to different hash lists and types. This abstraction facilitates the quick adaptation to new cracking challenges without needing reconfiguring from scratch.

#### Tasks

The Task is the smallest unit of work within the system, representing a segment of an Attack that an individual Agent is tasked with processing at any given time. Tasks are the fundamental work packets distributed to Agents in the network, allowing for the division of a larger attack into manageable pieces. This division not only enhances efficiency through parallel processing but also allows for dynamic load balancing across the network of Agents.

## Documentation

Comprehensive documentation is available in the [docs/](docs/) directory:

- [V2 Upgrade Overview](docs/v2-upgrade-overview.md) - Complete overview of the V2 upgrade
- [User Guide](docs/user-guide/) - How to use CipherSwarm
- [Getting Started](docs/getting-started/quick-start.md) - Quick start guide
- [API Reference](docs/api-reference-agent-auth.md) - Agent API documentation
- [Development Guide](docs/development/) - Development and contribution guidelines

## Contributing

We welcome contributions from the community! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines on how to get involved.

> [!NOTE]
> Many changes may not have been reflected in the CHANGELOG.md file before the v0.2.0 release. Please refer to the commit history for detailed information on changes.

## Acknowledgments

- We want to thank the [Hashtopolis](https://github.com/hashtopolis/server) team for inspiring us and providing us with the [Hashtopolis Communication Protocol v2](https://github.com/hashtopolis/server/blob/master/doc/protocol.pdf) documentation.
- Our sincere thanks to [Hashcat](https://github.com/hashcat/hashcat) for their incredible cracking tool.
- Thank you to the Ruby on Rails community for their guidance and support.
- Special thanks to our [contributors](https://github.com/unclesp1d3r/CipherSwarm/graphs/contributors) for their valuable input and feedback.
