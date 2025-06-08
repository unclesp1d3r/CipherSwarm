# Agent Setup Guide

This guide covers the installation and configuration of CipherSwarm agents.

## Prerequisites

1. **System Requirements**

    - Python 3.13 or higher
    - hashcat 6.2.6 or higher
    - CUDA/OpenCL drivers (for GPU support)
    - 4GB RAM minimum
    - 10GB disk space

2. **Network Requirements**
    - Outbound access to CipherSwarm server
    - Port 8000 (default) accessible
    - Stable internet connection

## Installation

### 1. Install Dependencies

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y python3.13 python3.13-venv hashcat

# RHEL/CentOS
sudo dnf install -y python3.13 hashcat

# macOS
brew install python@3.13 hashcat

# Windows
choco install python313 hashcat
```

### 2. Install CipherSwarm Agent

```bash
# Create virtual environment
python3.13 -m venv .venv
source .venv/bin/activate  # Unix/macOS
# or
.venv\Scripts\activate     # Windows

# Install agent
pip install cipherswarm-agent
```

## Configuration

### 1. Basic Setup

```bash
# Initialize agent
cipherswarm-agent init

# Configure server connection
cipherswarm-agent config set server.url http://server:8000
cipherswarm-agent config set agent.name "agent1"
```

### 2. Advanced Configuration

Create `agent.yaml`:

```yaml
server:
    url: http://server:8000
    verify_ssl: true
    timeout: 30

agent:
    name: agent1
    description: "GPU Cracking Node 1"
    capabilities:
        gpus:
            - id: 0
              type: cuda
              name: "NVIDIA GeForce RTX 3080"
            - id: 1
              type: cuda
              name: "NVIDIA GeForce RTX 3080"
        cpu:
            cores: 16
            threads: 32
        memory: 32768

hashcat:
    binary: /usr/bin/hashcat
    workload: 3
    temp_abort: 90
    gpu_temp_retain: 80
    optimize: true
    backend: cuda

resources:
    cache_dir: /var/cache/cipherswarm
    temp_dir: /tmp/cipherswarm
    max_cache: 50GB
    cleanup_interval: 3600

performance:
    max_tasks: 5
    min_memory: 4096
    gpu_memory_limit: 90
    cpu_limit: 80

monitoring:
    interval: 60
    metrics:
        - gpu_temp
        - gpu_load
        - cpu_load
        - memory_usage
```

### 3. Security Configuration

```yaml
security:
    # Token settings
    token_file: /etc/cipherswarm/token
    token_permissions: 0600

    # TLS/SSL
    cert_file: /etc/cipherswarm/cert.pem
    key_file: /etc/cipherswarm/key.pem
    ca_file: /etc/cipherswarm/ca.pem

    # Network
    allowed_ips:
        - 192.168.1.0/24
        - 10.0.0.0/8
```

## Running the Agent

### 1. Systemd Service

Create `/etc/systemd/system/cipherswarm-agent.service`:

```ini
[Unit]
Description=CipherSwarm Agent
After=network.target

[Service]
Type=simple
User=cipherswarm
Group=cipherswarm
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PYTHONUNBUFFERED=1
WorkingDirectory=/var/lib/cipherswarm
ExecStart=/usr/local/bin/cipherswarm-agent run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl enable cipherswarm-agent
sudo systemctl start cipherswarm-agent
```

### 2. Docker Container

```dockerfile
FROM python:3.13-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    hashcat \
    cuda-toolkit \
    && rm -rf /var/lib/apt/lists/*

# Install agent
RUN pip install cipherswarm-agent

# Copy configuration
COPY agent.yaml /etc/cipherswarm/agent.yaml

# Run agent
CMD ["cipherswarm-agent", "run"]
```

Build and run:

```bash
docker build -t cipherswarm-agent .
docker run -d \
    --name cipherswarm-agent \
    --gpus all \
    -v /etc/cipherswarm:/etc/cipherswarm \
    -v /var/cache/cipherswarm:/var/cache/cipherswarm \
    cipherswarm-agent
```

## Monitoring

### 1. Log Files

```bash
# Service logs
journalctl -u cipherswarm-agent

# Agent logs
tail -f /var/log/cipherswarm/agent.log
```

### 2. Metrics

The agent exposes metrics at `http://localhost:9100/metrics`:

```text
# HELP cipherswarm_agent_tasks_total Total number of tasks processed
# TYPE cipherswarm_agent_tasks_total counter
cipherswarm_agent_tasks_total{status="completed"} 150
cipherswarm_agent_tasks_total{status="failed"} 5

# HELP cipherswarm_agent_gpu_temperature GPU temperature in celsius
# TYPE cipherswarm_agent_gpu_temperature gauge
cipherswarm_agent_gpu_temperature{gpu="0"} 75.5
cipherswarm_agent_gpu_temperature{gpu="1"} 73.2
```

## Troubleshooting

### 1. Connection Issues

```bash
# Test server connection
cipherswarm-agent test connection

# Check network
curl -v http://server:8000/api/v1/client/health

# Verify token
cipherswarm-agent verify token
```

### 2. Performance Issues

```bash
# Check GPU status
cipherswarm-agent diagnostics gpu

# Test hashcat
cipherswarm-agent test hashcat

# Benchmark performance
cipherswarm-agent benchmark
```

### 3. Common Problems

1. **Agent Not Registering**

    - Check server URL
    - Verify network connectivity
    - Check firewall rules

2. **GPU Not Detected**

    - Update GPU drivers
    - Check CUDA installation
    - Verify GPU permissions

3. **High Resource Usage**
    - Adjust workload settings
    - Check thermal throttling
    - Reduce concurrent tasks

## Maintenance

### 1. Updates

```bash
# Update agent
pip install --upgrade cipherswarm-agent

# Update configuration
cipherswarm-agent config update

# Restart service
sudo systemctl restart cipherswarm-agent
```

### 2. Backup

```bash
# Backup configuration
cp /etc/cipherswarm/agent.yaml /etc/cipherswarm/agent.yaml.bak

# Backup token
cp /etc/cipherswarm/token /etc/cipherswarm/token.bak
```

### 3. Cleanup

```bash
# Clear cache
cipherswarm-agent cleanup cache

# Remove temporary files
cipherswarm-agent cleanup temp

# Reset agent
cipherswarm-agent reset
```

## Best Practices

1. **Security**

    - Use HTTPS/TLS
    - Rotate tokens regularly
    - Limit network access
    - Run as non-root user

2. **Performance**

    - Monitor GPU temperatures
    - Adjust workload based on hardware
    - Use appropriate cache sizes
    - Regular benchmarking

3. **Maintenance**
    - Regular updates
    - Log rotation
    - Resource cleanup
    - Configuration backups

For more information:

- [API Documentation](../api/agent.md)
- [Security Guide](../development/security.md)
- [Performance Tuning](../development/performance.md)
