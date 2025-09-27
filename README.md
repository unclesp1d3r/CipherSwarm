# CipherSwarm

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)
[![Python](https://img.shields.io/badge/python-3.13%2B-blue)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.109.0-009688.svg?style=flat&logo=FastAPI&logoColor=white)](https://fastapi.tiangolo.com)
[![SvelteKit](https://img.shields.io/badge/sveltekit-latest-orange.svg)](https://kit.svelte.dev)

![GitHub issues](https://img.shields.io/github/issues/unclesp1d3r/CipherSwarm)
![GitHub last commit](https://img.shields.io/github/last-commit/unclesp1d3r/CipherSwarm)
![Maintenance](https://img.shields.io/maintenance/yes/2025)
[![wakatime](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm.svg)](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm)

CipherSwarm is a distributed password cracking management system designed for efficiency, scalability, and airgapped networks. It coordinates multiple hashcat instances across different machines to efficiently crack password hashes using various attack strategies, with a modern web interface and robust API.

> [!IMPORTANT]
> **V2 Migration Status**
>
> CipherSwarm has migrated to v2 development on the `main` branch. This is the **active development preview** with modern FastAPI backend and SvelteKit frontend, but is **not yet stable for production use**.
>
> - **`main` branch**: Active v2 development (unstable, preview)
> - **`v1-archive` branch**: Stable v1 production version
>
> All new contributions should target the `main` branch for v2 development.

---

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=3 --minlevel=1 -->

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
  - [Development Workflow](#development-workflow)
  - [Tech Stack](#tech-stack)
  - [API Documentation](#api-documentation)
    - [Agent API v1 (Legacy)](#agent-api-v1-legacy)
    - [Agent API v2 (Preview)](#agent-api-v2-preview)
    - [Web UI API](#web-ui-api)
    - [Control API](#control-api)
    - [Interactive Documentation](#interactive-documentation)
  - [Running Tests](#running-tests)
    - [Test Organization](#test-organization)
  - [Contributing](#contributing)
  - [Acknowledgments](#acknowledgments)
  - [License](#license)

<!-- mdformat-toc end -->

---

## Features

- Distributed hash-cracking tasks managed through user-friendly web interfaces
- Scalable architecture to efficiently distribute workloads across a network of computers
- Integration with hashcat for versatile hash cracking capabilities
- Real-time monitoring of task progress and comprehensive result reporting
- Secure, easy-to-use system for both setup and operation
- **Dual Web Interface Options**:
  - **SvelteKit Frontend**: Modern, high-performance web UI with Flowbite Svelte and DaisyUI
  - **NiceGUI Interface**: Python-native web interface integrated directly into the FastAPI backend
- RESTful API (OpenAPI 3.0.1)
- Airgap and LAN support

---

## Getting Started

### Prerequisites

- Python 3.13 or higher
- PostgreSQL 16 or higher
- hashcat
- uv (Python package installer)
- [just](https://github.com/casey/just) (recommended for all developer tasks)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/unclesp1d3r/CipherSwarm.git
   cd CipherSwarm
   ```

2. Create and activate a virtual environment:

   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies and set up pre-commit hooks:

   ```bash
   just install
   ```

4. Set up the environment variables:

   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. Initialize the database and start the development server:

   ```bash
   just dev
   ```

### Docker Installation

The quickest way to get CipherSwarm up and running is to use Docker Compose:

1. Clone the repository:

   ```bash
   git clone https://github.com/unclesp1d3r/CipherSwarm.git
   cd CipherSwarm
   ```

2. Deploy the Docker containers:

   ```bash
   docker compose -f docker-compose.dev.yml up
   ```

3. Access the CipherSwarm web interface at <http://localhost:8000>.

### Project Assumptions and Target Audience

CipherSwarm is designed for medium to large-scale cracking infrastructure, interconnected via high-speed networks. It assumes:

1. **Cracking Tool**: Only Hashcat is currently supported.
2. **Connectivity**: All clients use reliable, high-speed LAN connections.
3. **Trust Level**: All client machines are trustworthy and under direct user control.
4. **User Base**: Users belong to the same organization or project team.
5. **Hashlist Management**: Handles hash lists from various projects/operations, with access control.
6. **Client-Project Affiliation**: Clients can be project-specific or shared, with defined priorities.

CipherSwarm is not intended for use over the Internet or with anonymous clients.

---

## Usage

1. Access the CipherSwarm web interface at <http://localhost:8000>.
2. Log in with your credentials (admin user setup required on first run).
3. Add agents/nodes to your network through the interface.
4. Create new cracking campaigns and attacks, specifying hash types and input files.
5. Monitor the progress of your tasks in real-time through the dashboard.

---

## Architecture

CipherSwarm is built on a modular architecture that separates task management, agent communication, and hash-cracking processes. This design allows for easy scaling and customization.

### Data Concepts

CipherSwarm manages hashcat cracking jobs around several core objects:

- **Campaigns**: A comprehensive unit of work focused on a single hash list. Each campaign may encompass multiple attacks, each with different strategies or parameters.
- **Attacks**: A defined unit of hashcat work (mode, wordlist, rules, etc.). Large attacks can be subdivided into tasks for parallel processing across agents.
- **Templates**: In CipherSwarm, templates are implemented as reusable attack definitions. This is achieved by allowing an Attack to reference another Attack as its template via the `template_id` field. There is no separate Template model; instead, any attack can serve as a template for others.
- **Tasks**: The smallest unit of work, representing a segment of an attack assigned to an agent. Tasks enable parallel processing and dynamic load balancing.
- **Agents**: Registered clients capable of executing tasks, reporting benchmarks, and maintaining a heartbeat.
- **HashLists**: Sets of hashes targeted by campaigns. Each campaign is linked to one hash list, but a hash list may be reused across campaigns.
- **Other Entities**: CrackResults, AgentErrors, Sessions, Audits, and Users, each supporting the distributed cracking workflow and security model.

---

## Development Workflow

CipherSwarm uses [`just`](https://github.com/casey/just) for all common developer tasks. The most important commands are:

- **Setup & Install:**
  - `just install` — Install Python/JS dependencies and pre-commit hooks
- **Development Server:**
  - `just dev` — Run DB migrations and start the FastAPI dev server with hot reload
- **Linting & Formatting:**
  - `just check` — Run all code and commit checks
  - `just format` — Auto-format code with ruff
  - `just format-check` — Check formatting only
- **Testing & Coverage:**
  - `just test` — Run the full test suite with coverage
  - `just ci-check` — Run formatting, lint, and all tests (CI equivalent)
  - `just coverage` — Show coverage report
- **Docs:**
  - `just docs` — Run the local docs server (MkDocs)
  - `just docs-test` — Build docs for test
- **Database (test DB):**
  - `just db-reset` — Drop, recreate, and migrate the test database

> **Tip:** Run `just` or `just --summary` to see all available tasks.

---

## Tech Stack

- **Backend**: FastAPI (Python 3.13+)
- **Frontend**: SvelteKit + JSON API + Shadcn Svelte
- **Database**: PostgreSQL 16+
- **ORM**: SQLAlchemy 2.0
- **Authentication**: Multi-tier (Bearer tokens, JWT cookies, API keys)
- **API Documentation**: OpenAPI 3.0.1
- **Caching**: Redis with Cashews
- **Object Storage**: MinIO S3-compatible
- **Task Queue**: Celery

---

## API Documentation

CipherSwarm provides multiple API interfaces for different use cases:

### Agent API v1 (Legacy)

- **Endpoint**: `/api/v1/client/*`

- **Purpose**: Legacy compatibility for existing hashcat agents

- **Authentication**: Bearer tokens (`csa_<agent_id>_<token>`)

- **Status**: Stable, production-ready

- **Contract**: Strict adherence to OpenAPI 3.0.1 specification

### Agent API v2 (Preview)

- **Endpoint**: `/api/v2/client/*`

- **Purpose**: Modernized agent interface with enhanced features

- **Authentication**: Bearer tokens with improved security

- **Status**: Development preview (v2.0.0+)

- **Features**: Enhanced state management, better error handling, improved resource management

### Web UI API

- **Endpoint**: `/api/v1/web/*`

- **Purpose**: Rich interface for SvelteKit frontend

- **Authentication**: JWT tokens with HTTP-only cookies

- **Features**: Campaign management, real-time SSE updates, comprehensive CRUD operations

### Control API

- **Endpoint**: `/api/v1/control/*`

- **Purpose**: Programmatic access for CLI tools and automation

- **Authentication**: API keys (`cst_<user_id>_<token>`)

- **Error Format**: RFC9457 Problem Details

### Interactive Documentation

- **Swagger UI**: `http://localhost:8000/docs`

- **ReDoc**: `http://localhost:8000/redoc`

---

## Running Tests

CipherSwarm has comprehensive test coverage with 712+ tests across unit, integration, and contract testing layers.

To run the full test suite:

```bash
just test
```

To run all checks (formatting, lint, tests — as in CI):

```bash
just ci-check
```

To see a coverage report:

```bash
just coverage
```

### Test Organization

- **Unit Tests** (106 files): Service layer and component testing
- **Integration Tests** (36 files): API endpoint and cross-component testing
- **Contract Tests**: Agent API v1 compliance validation against OpenAPI spec
- **Coverage**: 80%+ across all modules with comprehensive reporting

For detailed testing information, see [Testing Guide](docs/development/testing.md).

---

## Contributing

We welcome contributions from the community! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines on how to get involved.

---

## Acknowledgments

- Thanks to the Hashtopolis team for inspiration and protocol documentation.
- Thanks to Hashcat for their incredible cracking tool.
- Thanks to the Python, FastAPI, and open source communities.
- Special thanks to all contributors for their valuable input and feedback.

---

## License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ by the CipherSwarm team
