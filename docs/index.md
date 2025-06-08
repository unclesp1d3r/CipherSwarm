# Welcome to CipherSwarm

CipherSwarm is a distributed password cracking management system built with FastAPI and SvelteKit. It coordinates multiple agents running hashcat to efficiently distribute password cracking tasks across a network of machines.

## Features

- **Distributed Task Management**: Efficiently distribute password cracking tasks across multiple agents
- **Real-time Monitoring**: Track progress and performance of cracking tasks in real-time
- **Modern Web Interface**: Built with SvelteKit, JSON API, and Flowbite Svelte/DaisyUI components for a responsive, dynamic experience
- **RESTful API**: Well-documented API for agent communication and automation
- **Resource Management**: Centralized management of wordlists, rules, and masks
- **Secure Authentication**: JWT-based authentication for both web and agent interfaces
- **Docker Support**: Full containerization support for easy deployment

## Quick Links

- [Installation Guide](getting-started/installation.md)
- [Quick Start Tutorial](getting-started/quick-start.md)
- [Architecture Overview](architecture/overview.md)
- [API Documentation](api/agent.md)
- [Contributing Guide](development/contributing.md)

## Project Status

CipherSwarm is under active development. The core features are stable and the API specification is fixed, but we're continuously adding new features and improvements.

## Support

If you need help or want to contribute:

- Check out our [Contributing Guide](development/contributing.md)
- Review the [Development Setup](development/setup.md)
- Read the [Architecture Documentation](architecture/overview.md)

## License

CipherSwarm is open source software licensed under the MPL-2.0 license.
