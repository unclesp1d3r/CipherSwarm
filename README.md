# CipherSwarm

![GitHub](https://img.shields.io/github/license/unclesp1d3r/CipherSwarm) ![GitHub issues](https://img.shields.io/github/issues/unclesp1d3r/CipherSwarm) ![GitHub last commit](https://img.shields.io/github/last-commit/unclesp1d3r/CipherSwarm) ![Maintenance](https://img.shields.io/maintenance/yes/2025) [![wakatime](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm.svg)](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm)

[![Maintainability](https://api.codeclimate.com/v1/badges/347fc7e944ae3b9a5111/maintainability)](https://codeclimate.com/github/unclesp1d3r/CipherSwarm/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/347fc7e944ae3b9a5111/test_coverage)](https://codeclimate.com/github/unclesp1d3r/CipherSwarm/test_coverage) [![CircleCI](https://dl.circleci.com/status-badge/img/circleci/UWCMdwjzsT7X1qaHsgphoh/449a1171-f53f-45c9-9646-31cb1f9901f1/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/circleci/UWCMdwjzsT7X1qaHsgphoh/449a1171-f53f-45c9-9646-31cb1f9901f1/tree/main)

CipherSwarm is a distributed hash cracking system designed for efficiency and scalability and built on Ruby on Rails. Inspired by the principles of Hashtopolis, CipherSwarm leverages the power of collaborative computing to tackle complex cryptographic challenges, offering a web-based interface for managing and distributing hash-cracking tasks across multiple nodes.

> [!CAUTION]
> This project is currently under active development and is not ready for production. Please use it with caution.

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [CipherSwarm](#cipherswarm)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Docker Installation](#docker-installation)
    - [Project Assumptions and Target Audience](#project-assumptions-and-target-audience)
  - [Usage](#usage)
  - [Architecture](#architecture)
    - [Data Concepts](#data-concepts)
      - [Campaigns](#campaigns)
      - [Attacks](#attacks)
      - [Templates](#templates)
      - [Tasks](#tasks)
  - [Contributing](#contributing)
  - [Acknowledgments](#acknowledgments)

<!-- mdformat-toc end -->

## Features

- Distributed hash-cracking tasks managed through a user-friendly web interface.
- Scalable architecture to efficiently distribute workloads across a network of computers.
- Integration with hashcat for versatile hash cracking capabilities.
- Real-time monitoring of task progress and comprehensive result reporting.
- Secure, easy-to-use system for both setup and operation.

## Getting Started

### Prerequisites

- Ruby (version 3.4.5 or newer, managed with rbenv)
- Rails (version 8.0 or newer)
- PostgreSQL 17+ (or another Rails-supported database system)
- Redis 7.2+ for ActionCable support and job queue management
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

CipherSwarm is built on a modular architecture that separates task management, node communication, and hash-cracking processes. This design allows for easy scaling and customization.

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

## Contributing

We welcome contributions from the community! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines on how to get involved.

> [!NOTE]
> Many changes may not have been reflected in the CHANGELOG.md file before the v0.2.0 release. Please refer to the commit history for detailed information on changes.

## Acknowledgments

- We want to thank the [Hashtopolis](https://github.com/hashtopolis/server) team for inspiring us and providing us with the [Hashtopolis Communication Protocol v2](https://github.com/hashtopolis/server/blob/master/doc/protocol.pdf) documentation.
- Our sincere thanks to [Hashcat](https://github.com/hashcat/hashcat) for their incredible cracking tool.
- Thank you to the Ruby on Rails community for their guidance and support.
- Special thanks to our [contributors](https://github.com/unclesp1d3r/CipherSwarm/graphs/contributors) for their valuable input and feedback.
