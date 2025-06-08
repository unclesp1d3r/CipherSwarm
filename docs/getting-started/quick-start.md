# Quick Start Guide

This guide will help you get started with CipherSwarm by walking you through the basic setup and your first password cracking task.

## Prerequisites

- CipherSwarm installed and running (see [Installation Guide](installation.md))
- Admin account created
- At least one agent ready to connect

## 1. Access the Web Interface

1. Open your browser and navigate to:

    - Development: <http://localhost:8000>
    - Production: <https://your-domain.com>

2. Log in with your admin credentials:

    ```text
    Username: admin@cipherswarm.local
    Password: (your admin password)
    ```

## 2. Configure Your First Agent

### A. Register Agent

1. Generate an agent registration token:

    ```bash
    docker compose exec app python -m scripts.generate_agent_token
    ```

2. Note the generated token:

    ```text
    Agent Registration Token: csa_reg_xxxxxxxxxxxxxxxx
    ```

### B. Start Agent

1. On the agent machine, run:

    ```bash
    docker run -e "CS_SERVER=http://your-server:8000" \
           -e "CS_REG_TOKEN=csa_reg_xxxxxxxxxxxxxxxx" \
           cipherswarm/agent:latest
    ```

2. The agent will automatically:
    - Register with the server
    - Receive a permanent token
    - Begin accepting tasks

### C. Verify Agent

1. In the web interface, go to "Agents" → "Management"
2. Your new agent should appear with status "Active"
3. Click the agent to view its details and capabilities

## 3. Create Your First Attack

### A. Upload Resources

1. Go to "Resources" → "Upload"
2. Upload your files:
    - Wordlist (e.g., `rockyou.txt`)
    - Rules (e.g., `best64.rule`)
    - Hash file (e.g., `hashes.txt`)

### B. Configure Attack

1. Go to "Attacks" → "New Attack"
2. Fill in the basic settings:

    ```text
    Name: First Attack
    Description: Testing CipherSwarm setup
    Priority: Normal
    ```

3. Configure attack parameters:

    ```text
    Attack Type: Dictionary
    Hash Type: NTLM
    Wordlist: rockyou.txt
    Rules: best64.rule
    ```

4. Upload or paste your hash file

5. Click "Create Attack"

### C. Monitor Progress

1. Go to "Dashboard" to see:

    - Active tasks
    - Agent status
    - Cracking progress
    - Found passwords

2. View detailed progress:
    - Click the attack for detailed stats
    - Monitor agent performance
    - Check resource usage

## 4. View Results

### A. Check Findings

1. Go to "Attacks" → "Results"
2. Select your attack to see:
    - Cracked passwords
    - Success rate
    - Performance metrics
    - Time statistics

### B. Export Results

1. Click "Export Results"
2. Choose format:
    - CSV
    - JSON
    - Plain text

## 5. Basic Management

### A. Agent Management

1. **View Agent Status**

    - Go to "Agents" → "Overview"
    - Check health and performance
    - Monitor resource usage

2. **Control Agents**
    - Start/Stop tasks
    - Update configuration
    - Remove agents

### B. Resource Management

1. **Manage Files**

    - Upload new resources
    - Organize with tags
    - Delete unused files

2. **Monitor Usage**
    - Track resource usage
    - Check file integrity
    - View usage statistics

### C. Task Management

1. **Control Tasks**

    - Pause/Resume tasks
    - Adjust priority
    - Cancel tasks

2. **Monitor Performance**
    - View speed metrics
    - Check completion estimates
    - Analyze efficiency

## 6. Common Operations

### A. Start/Stop Attack

1. **Start Attack**

    ```text
    Attacks → Select Attack → Start
    ```

2. **Pause Attack**

    ```text
    Attacks → Select Attack → Pause
    ```

3. **Resume Attack**

    ```text
    Attacks → Select Attack → Resume
    ```

### B. Agent Control

1. **Pause Agent**

    ```text
    Agents → Select Agent → Pause
    ```

2. **Resume Agent**

    ```text
    Agents → Select Agent → Resume
    ```

3. **Update Agent**

    ```text
    Agents → Select Agent → Update
    ```

### C. Resource Management

1. **Add Resource**

    ```text
    Resources → Upload → Select Files
    ```

2. **Remove Resource**

    ```text
    Resources → Select Resource → Delete
    ```

## 7. Next Steps

After completing this guide, explore:

1. [Advanced Attack Configuration](../user-guide/attack-configuration.md)
2. [Agent Management Guide](../user-guide/agent-setup.md)
3. [Resource Management](../user-guide/web-interface.md)
4. [Performance Optimization](../user-guide/web-interface.md)

## Quick Reference

### Common Commands

```bash
# Check agent status
docker compose exec app python -m scripts.check_agent_status

# Generate new agent token
docker compose exec app python -m scripts.generate_agent_token

# View attack progress
docker compose exec app python -m scripts.show_progress

# Export results
docker compose exec app python -m scripts.export_results
```

### Important URLs

- Dashboard: `/dashboard`
- Agents: `/agents`
- Attacks: `/attacks`
- Resources: `/resources`
- Results: `/results`

### Default Ports

- Web Interface: 8000
- Agent API: 8000
- Database: 5432
- Redis: 6379
- MinIO: 9000/9001

### Common Issues

1. **Agent Won't Connect**

    - Check network connectivity
    - Verify registration token
    - Ensure server URL is correct

2. **Attack Won't Start**

    - Verify resource availability
    - Check agent status
    - Confirm hash format

3. **Slow Performance**
    - Check agent resources
    - Verify network speed
    - Monitor system load

## Support Resources

- [Troubleshooting Guide](../user-guide/web-interface.md)
- [FAQ](../user-guide/faq.md)
- [Discord Community](https://discord.gg/cipherswarm)
- [GitHub Issues](https://github.com/yourusername/cipherswarm/issues)
