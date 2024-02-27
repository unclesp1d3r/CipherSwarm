# CipherSwarm

![GitHub](https://img.shields.io/github/license/unclesp1d3r/CipherSwarm)
![GitHub issues](https://img.shields.io/github/issues/unclesp1d3r/CipherSwarm)
![GitHub Repo stars](https://img.shields.io/github/stars/unclesp1d3r/CipherSwarm?style=social)
![GitHub last commit](https://img.shields.io/github/last-commit/unclesp1d3r/CipherSwarm)
![Maintenance](https://img.shields.io/maintenance/yes/2024)
[![LoC](https://tokei.rs/b1/github/unclesp1d3r/CipherSwarm?category=code)](https://github.com/unclesp1d3r/CipherSwarm)
[![wakatime](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm.svg)](https://wakatime.com/badge/github/unclesp1d3r/CipherSwarm)

CipherSwarm is a distributed hash cracking system designed for efficiency and scalability, built on Ruby on Rails.
Inspired by the principles of Hashtopolis, CipherSwarm leverages the power of collaborative computing to tackle complex
cryptographic challenges, offering a web-based interface for managing and distributing hash cracking tasks across
multiple nodes.

## Features

- Distributed hash cracking tasks managed through a user-friendly web interface.
- Scalable architecture to efficiently distribute workloads across a network of computers.
- Integration with hashcat for versatile hash cracking capabilities.
- Real-time monitoring of task progress and comprehensive result reporting.
- Secure, easy-to-use system for both setup and operation.

## Getting Started

## Project Assumptions and Target Audience

CipherSwarm, while performing functions similar to Hashtopolis, is not a reiteration of the latter. It is a unique
project, conceived with a specific target audience in mind and shaped by several guiding assumptions:

1. **Cracking Tool**: CipherSwarm exclusively supports Hashcat as the cracking tool.

2. **Connectivity**: It is assumed that all clients connected to CipherSwarm will use a reliable, high-speed
   connection, typically found in a Local Area Network (LAN) environment.

3. **Trust Level**: CipherSwarm operates under the assumption that all client machines are trustworthy and are under
   the direct control and management of the user utilizing CipherSwarm.

4. **User Base**: The system assumes that users, though having different levels of administrative access, belong to the
   same organization or project team, ensuring a level of trust and common purpose.

5. **Hashlist Management**: CipherSwarm is designed to handle hashlists derived from various projects or operations. It
   enables users to view results from specific projects or across all projects, depending on access privileges.

6. **Client-Project Affiliation**: Cracking clients can be associated with specific projects, executing operations
   solely for that project. Alternatively, they can be permitted to perform operations across all projects, with defined
   priorities for specific projects.

CipherSwarm is specifically crafted for medium to large-scale cracking infrastructure, interconnected via high-speed
networks. It does not support utilization over the Internet or integration with anonymous user systems acting as
cracking clients. By focusing on secure, centralized, and high-performance environments, CipherSwarm delivers tailored
scalability and efficiency to meet the demands of sophisticated cracking operations.

### Prerequisites

- Ruby (version 2.7.0 or newer)
- Rails (version 6.0.0 or newer)
- PostgreSQL (or another Rails-supported database system)
- Redis for ActionCable support and job queue management

### Installation

1. Clone the repository to your local machine:

```bash
git clone https://github.com/unclesp1d3r/CipherSwarm.git
cd CipherSwarm
```

2. Install the required gems:

```bash
bundle install
```

3. Create the database and run migrations:

- Configure your database settings in config/database.yml.
- Set up environment variables for secure operation in config/secrets.yml.

```bash
rails db:create
rails db:migrate
```

4. Start the rails server:

```bash
rails s
```

### Usage

1. Access the CipherSwarm web interface at http://localhost:3000.
2. Log in with the default admin credentials (username: admin, password: password) and change the password immediately.
3. Add nodes to your network through the interface.
4. Create new cracking tasks, specifying the hash types and input files.
5. Monitor the progress of your tasks in real-time through the dashboard.

### Architecture

CipherSwarm is built on a modular architecture that separates task management, node communication, and hash cracking
processes. This design allows for easy scaling and customization.

### Contributing

We welcome contributions from the community! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines
on how to get involved.

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -am 'Add some feature`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

### Acknowledgments

- We would like to acknowledge the [Hashtopolis](https://github.com/hashtopolis/server) team for inspiring us and
  providing us with
  the [Hashtopolis Communication Protocol v2](https://github.com/hashtopolis/server/blob/master/doc/protocol.pdf)
  documentation.
- Our sincere thanks to [Hashcat](https://github.com/hashcat/hashcat) for their incredible cracking tool.
- Thank you to the Ruby on Rails community for their guidance and support.
- Special thanks to our contributors for their valuable input and feedback.
