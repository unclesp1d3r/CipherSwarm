# Contributing to CipherSwarm

Thank you for your interest in contributing to CipherSwarm! This guide will help you get started and understand how to contribute effectively.

## Quick Start

1. **Fork and clone** the repository
2. **Set up your environment** (see Setup section below)
3. **Pick an issue** from the [Issues](https://github.com/unclesp1d3r/CipherSwarm/issues) page
4. **Make your changes** and test them
5. **Submit a pull request**

## Setup Your Environment

### Prerequisites

- Python 3.13+
- Node.js 20.19+
- pnpm 9.12.3 (pinned version used in CI)
- Docker and Docker Compose
- Git

### Installation

1. **Fork the repository** on GitHub, then clone your fork:

    ```bash
    git clone https://github.com/YOUR_USERNAME/CipherSwarm.git
    cd CipherSwarm
    ```

2. **Install dependencies**:

    ```bash
    # Install uv (choose one method):
    # Option 1: Official installer (recommended)
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Option 2: Using pipx
    pipx install uv

    # Install Python dependencies
    uv sync

    # Install frontend dependencies
    cd frontend
    pnpm install
    cd ..
    ```

3. **Start the development environment**:

    ```bash
    # Start backend services (PostgreSQL, Redis, etc.)
    docker compose up -d

    # Start the backend API server
    uv run python -m app.main

    # In another terminal, start the frontend
    cd frontend
    pnpm run dev
    ```

4. **Verify everything is working**:

    - Backend API: <http://localhost:8000/docs>
    - Frontend: <http://localhost:5173>
    - Database: PostgreSQL on localhost:5432

## Finding Something to Work On

### Good First Issues

Look for issues labeled with:

- `good first issue` - Perfect for newcomers
- `help wanted` - Areas where we need help
- `bug` - Issues that need fixing

### Areas You Can Contribute

- **Frontend (SvelteKit)**: UI components, user experience improvements
- **Backend (FastAPI)**: API endpoints, business logic, database models
- **Documentation**: Guides, API docs, code comments
- **Testing**: Unit tests, integration tests, end-to-end tests
- **DevOps**: Docker configuration, CI/CD improvements

## Making Changes

### Development Workflow

1. **Create a feature branch**:

    ```bash
    git checkout -b feature/your-feature-name
    ```

2. **Make your changes** and test them locally

3. **Run tests** to ensure nothing is broken:

    ```bash
    # Backend tests
    pytest

    # Frontend tests
    cd frontend
    pnpm test
    ```

4. **Commit your changes** with a clear message:

    ```bash
    git commit -m "Add user authentication feature"
    ```

5. **Push to your fork**:

    ```bash
    git push origin feature/your-feature-name
    ```

### Code Style

- **Python**: Follow PEP 8, use type hints, and write docstrings
- **JavaScript/TypeScript**: Use Prettier formatting, ESLint rules
- **Svelte**: Follow SvelteKit conventions and component patterns
- **Tests**: Write tests for new functionality

## Submitting Your Contribution

### Before Submitting

- [ ] Your code follows the project's style guidelines
- [ ] You've added tests for new functionality
- [ ] All tests pass locally
- [ ] You've updated documentation if needed

### Creating a Pull Request

1. **Go to your fork** on GitHub
2. **Click "New Pull Request"**
3. **Select the correct base branch** (usually `main`)
4. **Fill out the PR template** with:
    - Description of your changes
    - Any related issues
    - Screenshots (if UI changes)
    - Testing steps

### What Happens Next

1. **Automated checks** will run (tests, linting, etc.)
2. **Review process** - we'll review your code and provide feedback
3. **Iteration** - you may need to make changes based on feedback
4. **Merge** - once approved, your changes will be merged!

## Getting Help

- **GitHub Issues**: Ask questions or report bugs
- **Discussions**: Join community discussions
- **Documentation**: Check the [docs](docs/) folder for detailed guides

## Code of Conduct

Please note that we have a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Thank You

We appreciate every contribution, no matter how small. Whether you're fixing a typo, adding a feature, or improving documentation, your help makes CipherSwarm better for everyone.

Happy coding! 🚀
