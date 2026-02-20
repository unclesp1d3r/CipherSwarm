# CipherSwarm Documentation

Welcome to the CipherSwarm documentation. This directory contains comprehensive documentation for the CipherSwarm distributed password cracking platform.

## 📚 Documentation Structure

### Getting Started

- [Quick Start Guide](getting-started/quick-start.md) - Get CipherSwarm running quickly
- [User Guide](user-guide/) - Comprehensive user documentation

### V2 Upgrade Information

- [V2 Upgrade Overview](v2-upgrade-overview.md) - Complete overview of the V2 upgrade
- [Strategic Direction](strategy.md) - V2 vision and design intent
- [Implementation Plan](v2_rewrite_implementation_plan/implementation_plan.md) - Detailed implementation roadmap

### User Guides

- [**User Guide Index**](user-guide/README.md) - Complete table of contents and quick navigation
- [Getting Started](user-guide/getting-started.md) - First-time setup, dashboard overview, and your first campaign
- [Campaign Management](user-guide/campaign-management.md) - Creating, monitoring, and managing campaigns
- [Attack Configuration](user-guide/attack-configuration.md) - Configuring dictionary, mask, brute force, and hybrid attacks
- [Understanding Results](user-guide/understanding-results.md) - Viewing, interpreting, and exporting cracking results
- [Agent Setup](user-guide/agent-setup.md) - Installing, registering, and configuring agents
- [Agent Troubleshooting](user-guide/troubleshooting-agents.md) - Task lifecycle diagnostics and recovery
- [Resource Management](user-guide/resource-management.md) - Managing wordlists, rules, masks, and charsets
- [Web Interface](user-guide/web-interface.md) - Complete web interface reference
- [Troubleshooting](user-guide/troubleshooting.md) - System diagnostics, common issues, and solutions
- [Common Issues](user-guide/common-issues.md) - Quick fixes for frequently encountered problems
- [FAQ](user-guide/faq.md) - Frequently asked questions
- [Performance Optimization](user-guide/optimization.md) - Hardware tuning, attack strategies, and system optimization
- [Air-Gapped Deployment](user-guide/air-gapped-deployment.md) - Deploying in isolated environments

### Deployment Guides

- [Production Load Balancing](deployment/production-load-balancing.md) - Nginx load balancing with horizontal web scaling

### Development Documentation

- [Style Guide](development/style-guide.md) - Code style and conventions
- [User Journey Flowchart](development/user_journey_flowchart.mmd) - User workflow visualization

### API Documentation

- [Agent API Reference](api-reference-agent-auth.md) - Agent authentication overview
- [**Agent API Complete Reference**](api/agent-api-complete-reference.md) - Full API documentation with examples

The API documentation is automatically generated using Rswag from RSpec request tests. Use the following commands to generate and update API documentation:

- `just docs-api` - Generate basic Swagger/OpenAPI documentation
- `just docs-api-full` - Generate comprehensive documentation with examples
- `just docs-generate` - Run integration tests and generate API docs

### Architecture Documentation

- [**Architecture Diagrams**](architecture/diagrams.md) - System, domain, and sequence diagrams (Mermaid)
- [Architecture Analysis](architecture-analysis.md) - Detailed architecture review and recommendations

### Development Documentation

- [**Developer Guide**](development/developer-guide.md) - Comprehensive developer onboarding guide
- [Style Guide](development/style-guide.md) - Code style and conventions
- [Logging Guide](development/logging-guide.md) - Logging patterns and best practices
- [User Journey Flowchart](development/user_journey_flowchart.mmd) - User workflow visualization

### Quick Reference

- [**Quick Reference Card**](quick-reference.md) - Commands, patterns, and common operations

### Technical Reference

- [Current Hashcat Hash Modes](current_hashcat_hashmodes.txt) - Supported hash types

## 🔄 V2 Upgrade Status

CipherSwarm is currently undergoing a comprehensive V2 upgrade. The upgrade maintains the existing Ruby on Rails + Hotwire technology stack while delivering enhanced user experiences, improved real-time capabilities, and better operational management.

### Key V2 Improvements

- **Real-time Operations Dashboard** with live agent monitoring
- **Enhanced Campaign Management** with guided wizards and DAG support
- **Advanced Agent Management** with intelligent task distribution
- **Comprehensive Reporting & Analytics** for security insights
- **Team Collaboration Features** with activity feeds and notifications
- **Production-Ready Deployment** with containerization, nginx load balancing, horizontal scaling, and monitoring

For complete details, see the [V2 Upgrade Overview](v2-upgrade-overview.md).

## 🎯 Target Audience

CipherSwarm is designed for:

- **Red Team Operators**: Efficient campaign creation and attack orchestration
- **Blue Team Analysts**: Comprehensive reporting and password pattern analysis
- **Infrastructure Administrators**: Intelligent resource management and system monitoring
- **Project Managers**: Team coordination and project oversight

## 🏗️ Architecture Overview

CipherSwarm uses a modern Rails 8.0+ architecture with:

- **Web Interface Layer**: Controllers, Views, and ViewComponents using Hotwire
- **Service Layer**: Business logic, state management, and validation services
- **Model Layer**: ActiveRecord models with associations and validations
- **Data Layer**: PostgreSQL 17+ database with Redis for caching and background jobs

### Key Technologies

- **Ruby 3.4.5** with **Rails 8.0+**
- **PostgreSQL 17+** for primary data storage
- **Redis 7.2+** for Solid Cache and Sidekiq job processing
- **Hotwire** (Turbo + Stimulus) for interactive frontend
- **ViewComponent** for reusable UI components
- **Sidekiq** for background job processing

## 📖 Additional Resources

- [Contributing Guidelines](../CONTRIBUTING.md) - How to contribute to the project
- [Code of Conduct](../CODE_OF_CONDUCT.md) - Community guidelines
- [License](../LICENSE) - Project license information
- [Changelog](../CHANGELOG.md) - Version history and changes

## 🆘 Getting Help

If you need help with CipherSwarm:

1. Check the [FAQ](user-guide/faq.md) for common questions
2. Review the [Common Issues](user-guide/common-issues.md) troubleshooting guide
3. Search existing [GitHub Issues](https://github.com/unclesp1d3r/CipherSwarm/issues)
4. Create a new issue if your problem isn't covered

## 📝 Contributing to Documentation

We welcome contributions to improve the documentation! Please see the [Contributing Guidelines](../CONTRIBUTING.md) for information on how to contribute.

When contributing documentation:

- Follow the existing structure and style
- Use clear, concise language
- Include examples where helpful
- Test any code examples
- Update the table of contents if adding new sections
