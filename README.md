# CipherSwarm

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)
[![Python](https://img.shields.io/badge/python-3.11%2B-blue)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.109.0-009688.svg?style=flat&logo=FastAPI&logoColor=white)](https://fastapi.tiangolo.com)
[![HTMX](https://img.shields.io/badge/htmx-1.9.10-blue.svg)](https://htmx.org)

CipherSwarm is a powerful distributed password cracking management system designed for airgapped networks. It coordinates multiple hashcat instances across different machines to efficiently crack password hashes using various attack strategies.

## 🚀 Features

- **Distributed Task Management**: Efficiently distribute cracking tasks across multiple agents
- **Real-time Monitoring**: Track progress and performance of cracking tasks in real-time
- **Advanced Attack Configuration**: Support for various hashcat attack modes and configurations
- **Resource Management**: Efficient distribution and management of wordlists and rules
- **Agent Health Monitoring**: Track agent status, performance, and resource utilization
- **Modern Web Interface**: Responsive HTMX-powered interface with real-time updates
- **RESTful API**: Well-documented API for integration with other tools
- **Airgap Support**: Designed to work in airgapped environments

## 🛠️ Tech Stack

- **Backend**: FastAPI (Python 3.11+)
- **Frontend**: HTMX + Tailwind CSS
- **Database**: PostgreSQL
- **ORM**: SQLAlchemy
- **Task Queue**: Celery (for background tasks)
- **Authentication**: Bearer Token
- **API Documentation**: OpenAPI 3.0.1

## 📋 Prerequisites

- Python 3.11 or higher
- PostgreSQL 14 or higher
- hashcat
- uv (Python package installer)

## 🔧 Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/cipherswarm.git
   cd cipherswarm
   ```

2. Create and activate a virtual environment:

   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies using uv:

   ```bash
   pip install uv
   uv pip install -r requirements.txt
   ```

4. Set up the environment variables:

   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. Initialize the database:

   ```bash
   alembic upgrade head
   ```

6. Start the development server:
   ```bash
   uvicorn app.main:app --reload
   ```

## 🏗️ Project Structure

```
cipherswarm/
├── alembic/                    # Database migrations
├── app/
│   ├── api/                    # API endpoints
│   │   ├── v1/
│   │   │   ├── agents.py
│   │   │   ├── attacks.py
│   │   │   ├── tasks.py
│   │   │   └── client.py
│   ├── core/                   # Core functionality
│   │   ├── config.py
│   │   ├── security.py
│   │   └── dependencies.py
│   ├── db/                     # Database
│   │   ├── base.py
│   │   └── session.py
│   ├── models/                 # SQLAlchemy models
│   ├── schemas/                # Pydantic schemas
│   └── services/               # Business logic
├── static/                     # Static files
├── templates/                  # HTMX templates
└── tests/                     # Test suite
```

## 🔒 Security Considerations

- All communication is secured using bearer token authentication
- Designed for airgapped networks
- Implements rate limiting and connection monitoring
- Secure storage of hashes and results
- Comprehensive audit logging

## 🌐 API Documentation

The API documentation is available at:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## 🧪 Running Tests

```bash
pytest
```

For coverage report:

```bash
pytest --cov=app tests/
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the Mozilla Public License Version 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [hashcat](https://hashcat.net/) - The password recovery tool
- [FastAPI](https://fastapi.tiangolo.com/) - The web framework used
- [HTMX](https://htmx.org/) - For modern browser capabilities with minimal JavaScript
- [Tailwind CSS](https://tailwindcss.com/) - For the UI styling

## 📞 Support

For support, please open an issue in the GitHub issue tracker or contact the maintainers.

---

Built with ❤️ by the CipherSwarm team
