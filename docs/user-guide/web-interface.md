# Web Interface Guide

The CipherSwarm web interface provides a modern, responsive dashboard for managing your password cracking operations.

## Dashboard Overview

The main dashboard is divided into several key sections:

1. **Status Overview**

    - Active agents count
    - Running tasks
    - Overall system performance
    - Recent results

2. **Navigation**
    - Attacks
    - Agents
    - Resources
    - Results
    - Settings

## Attack Management

### Creating an Attack

1. Navigate to "Attacks" → "New Attack"
2. Fill in the attack details:

    ```yaml
    Name: Descriptive name for the attack
    Type: Dictionary, Mask, or Hybrid
    Hash Type: MD5, SHA1, etc.
    Resources:
        - Wordlist
        - Rules (optional)
        - Masks (for mask/hybrid attacks)
    ```

3. Upload your hash file
4. Configure advanced options (optional)
5. Click "Create Attack"

### Monitoring Attacks

The attack details page shows:

1. **Progress Information**

    - Overall completion percentage
    - Estimated time remaining
    - Current speed (H/s)
    - Cracked passwords count

2. **Agent Distribution**

    - Active agents
    - Agent performance
    - Resource utilization

3. **Results**
    - Live results feed
    - Export options
    - Statistics

## Agent Management

### Agent Overview

The agents page displays:

1. **Agent Status**

    ```html
    <div class="agent-card">
        <div class="status-indicator active"></div>
        <div class="agent-info">
            <h3>Agent Name</h3>
            <p>Status: Active</p>
            <p>Tasks: 2/5</p>
        </div>
    </div>
    ```

2. **Performance Metrics**
    - CPU usage
    - GPU utilization
    - Memory usage
    - Network stats

### Agent Configuration

1. **Basic Settings**

    - Name
    - Description
    - Max tasks
    - Priority

2. **Resource Limits**
    - CPU cores
    - GPU selection
    - Memory limits
    - Network bandwidth

## Resource Management

### Wordlists

1. **Upload**

    ```html
    <form class="upload-form">
        <input type="file" accept=".txt,.dict" />
        <input type="text" placeholder="Description" />
        <button type="submit">Upload</button>
    </form>
    ```

2. **Management**
    - View details
    - Check integrity
    - Delete unused
    - Tag and categorize

### Rule Files

1. **Organization**

    - Categories
    - Tags
    - Usage statistics
    - Performance metrics

2. **Testing**
    - Rule validation
    - Sample testing
    - Performance testing

## Results Analysis

### Results View

```html
<div class="results-table">
    <table>
        <thead>
            <tr>
                <th>Hash</th>
                <th>Password</th>
                <th>Time</th>
                <th>Method</th>
            </tr>
        </thead>
        <tbody>
            <!-- Results rows -->
        </tbody>
    </table>
</div>
```

### Analysis Tools

1. **Statistics**

    - Password patterns
    - Character distribution
    - Length analysis
    - Time to crack

2. **Reporting**
    - Export formats
    - Custom reports
    - Scheduled reports

## Settings

### System Configuration

1. **Performance**

    ```yaml
    Task Distribution:
        max_tasks_per_agent: 5
        min_task_size: 1000000
        adaptive_distribution: true

    Resource Management:
        cache_wordlists: true
        compress_results: true
        cleanup_interval: 3600
    ```

2. **Security**
    - Authentication settings
    - API access
    - Rate limits
    - IP restrictions

### User Management

1. **User Roles**

    - Administrator
    - Manager
    - Operator
    - Viewer

2. **Permissions**
    - Attack creation
    - Resource management
    - Result access
    - System configuration

## Keyboard Shortcuts

| Action     | Shortcut |
| ---------- | -------- |
| New Attack | `Ctrl+N` |
| Refresh    | `F5`     |
| Search     | `Ctrl+/` |
| Help       | `?`      |

## Notifications

The system uses toast notifications for important events:

```html
<div class="toast success">
    <div class="toast-header">Success</div>
    <div class="toast-body">Attack created successfully</div>
</div>
```

Types of notifications:

- Success (green)
- Warning (yellow)
- Error (red)
- Info (blue)

## Dark Mode

Toggle dark mode using the theme switcher in the navigation bar:

```html
<button class="theme-toggle" onclick="toggleTheme()">
    <i class="moon-icon"></i>
</button>
```

## Mobile Support

The interface is fully responsive and supports:

- Touch gestures
- Mobile-friendly layouts
- Simplified views for small screens
- Progressive loading

## Troubleshooting

Common issues and solutions:

1. **Slow Loading**

    - Clear browser cache
    - Check network connection
    - Verify server status

2. **Display Issues**

    - Try different browser
    - Update browser
    - Clear local storage

3. **Authentication Problems**
    - Check credentials
    - Clear cookies
    - Verify account status

For additional help:

- Check the [FAQ](../faq.md)
- Contact support
- Review error logs
