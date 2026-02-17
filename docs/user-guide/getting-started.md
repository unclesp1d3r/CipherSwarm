# Getting Started with CipherSwarm

This guide walks you through setting up CipherSwarm for the first time, from logging in to running your first campaign.

---

## Table of Contents

- [First-Time Setup](#first-time-setup)
- [Understanding the Dashboard](#understanding-the-dashboard)
- [Project Setup](#project-setup)
- [Your First Campaign](#your-first-campaign)
- [Agent Registration](#agent-registration)
- [Viewing Results](#viewing-results)
- [Next Steps](#next-steps)

---

## First-Time Setup

### Logging In

1. Open your browser and navigate to the CipherSwarm web interface URL provided by your administrator
2. Enter your email address and password on the login page
3. Click **Sign In**

If this is your first login, your administrator will have created an account for you. Contact them if you do not have credentials.

### Password Requirements

CipherSwarm enforces strong password policies:

- Minimum 8 characters
- Must include a mix of uppercase, lowercase, numbers, and symbols
- Passwords are stored securely using bcrypt hashing

### Setting Up Your Profile

After logging in for the first time:

1. Click your username in the top-right corner
2. Select **Edit Profile**
3. Update your display name and email preferences
4. Optionally change your password

---

## Understanding the Dashboard

The dashboard is the main landing page after login. It provides a real-time overview of your cracking operations.

### Navigation Bar

The top navigation bar provides access to all major sections:

- **Dashboard** - Overview of all operations (home page)
- **Campaigns** - Create and manage cracking campaigns
- **Hash Lists** - Upload and manage hash files
- **Agents** - Monitor and configure cracking agents
- **Resources** - Manage wordlists, rules, and masks
- **Admin** - System administration (admin users only)

### Status Cards

The dashboard displays four status cards at the top:

```
+-------------------+  +-------------------+  +-------------------+  +-------------------+
| Active Agents     |  | Running Tasks     |  | Recently Cracked  |  | Resource Usage    |
| 5 / 8 online      |  | 12 tasks active   |  | 342 in 24 hours   |  | 1.2 GH/s total    |
+-------------------+  +-------------------+  +-------------------+  +-------------------+
```

1. **Active Agents** - How many agents are online and working
2. **Running Tasks** - Number of active cracking tasks
3. **Recently Cracked** - Hashes cracked in the last 24 hours
4. **Resource Usage** - Aggregate hash rate across all agents

### Campaign List

Below the status cards, you will see a list of all campaigns in your current project, with live progress bars and state indicators.

---

## Project Setup

CipherSwarm organizes work into **Projects**. Each project contains its own campaigns, hash lists, and resources.

### Understanding Projects

- All data is scoped to the currently selected project
- Agents can be assigned to one or more projects
- Users may have access to multiple projects
- Project boundaries enforce data isolation

### Selecting a Project

If you have access to multiple projects:

1. Look for the **Project Selector** in the navigation bar
2. Click it to see available projects
3. Select the project you want to work in
4. The dashboard and all views will update to show data from that project

### Creating a New Project (Administrators)

Administrators can create new projects:

1. Go to **Admin** > **Projects**
2. Click **New Project**
3. Enter a project name and description
4. Assign users and agents to the project
5. Click **Create Project**

---

## Your First Campaign

Follow these steps to set up and run your first hash cracking campaign.

### Step 1: Upload a Hash List

Before creating a campaign, you need hashes to crack.

1. Navigate to **Hash Lists** in the top menu
2. Click **New Hash List**
3. Enter a name for the hash list (e.g., "Test Hashes")
4. Select the hash type from the dropdown (e.g., MD5, NTLM, SHA-256)
5. Choose one of the upload methods:
   - **File Upload**: Click **Choose File** and select your hash file
   - **Text Input**: Paste hashes directly into the text area (one per line)
6. Click **Create Hash List**
7. Wait for processing to complete (you will see a progress indicator)

### Step 2: Create a Campaign

1. Navigate to **Campaigns** in the top menu
2. Click **New Campaign**
3. Fill in the campaign details:
   - **Name**: Give your campaign a descriptive name (e.g., "Q1 Audit Hashes")
   - **Hash List**: Select the hash list you uploaded in Step 1
   - **Priority**: Leave as **Routine** for now (higher priorities preempt lower ones)
4. Click **Create Campaign**

### Step 3: Add a Dictionary Attack

The simplest way to start cracking is with a dictionary attack.

1. From the campaign page, click **New Attack**
2. Select **Dictionary** as the attack type
3. Configure the attack:
   - **Wordlist**: Select a wordlist from the dropdown (e.g., `rockyou.txt`)
   - **Rules** (optional): Add rule files for password mutations
4. Review the keyspace estimate shown in the sidebar
5. Click **Create Attack**

### Step 4: Start the Campaign

Once your attack is configured:

1. The attack will appear in the campaign's attack list
2. If agents are available, tasks will be created and assigned automatically
3. You will see the campaign status change to **Running**
4. Progress bars will update in real time as agents work

### Step 5: Monitor Progress

While the campaign is running:

- **Progress Bar**: Shows overall completion percentage
- **ETA Display**: Estimated time to completion
- **Attack Stepper**: Visual indicator of which attack step is active
- **Recent Cracks**: Live feed of newly cracked hashes

---

## Agent Registration

Agents are the machines that perform the actual hash cracking. For a complete guide, see [Agent Setup](agent-setup.md).

### Quick Overview

1. An administrator registers the agent in the web interface (**Agents** > **Register New Agent**)
2. The system generates a unique authentication token (shown only once)
3. The agent software is installed on the cracking machine
4. The token is configured in the agent's settings
5. The agent connects to the server and appears in the agent list

### Checking Agent Status

After registration, verify the agent is connected:

1. Go to **Agents** in the top menu
2. Look for your agent in the list
3. A green status indicator means the agent is online and ready
4. Click the agent name to see details, including hardware capabilities and performance

---

## Viewing Results

Once hashes start being cracked:

### From the Dashboard

- The **Recently Cracked** status card shows 24-hour counts
- Campaign progress bars update in real time
- Toast notifications appear when new hashes are cracked

### From a Campaign

1. Navigate to the campaign
2. Click on the hash list name to view results
3. You will see cracked and uncracked hashes listed
4. Use filters to show only cracked or only uncracked hashes

### Exporting Results

To export cracked hashes:

1. Go to the hash list results view
2. Click **Export**
3. Choose a format (CSV, TSV, or Hashcat format)
4. The file will download to your browser

For more details, see [Understanding Results](understanding-results.md).

---

## Next Steps

Now that you have your first campaign running, explore these topics to get more out of CipherSwarm:

- [Campaign Management](campaign-management.md) - Learn about campaign priorities, pause/resume, and advanced management
- [Attack Configuration](attack-configuration.md) - Configure mask attacks, brute force, hybrid attacks, and more
- [Resource Management](resource-management.md) - Upload and manage wordlists, rules, and masks
- [Understanding Results](understanding-results.md) - Interpret and export your cracking results
- [Performance Optimization](optimization.md) - Tune your agents and attacks for maximum performance
- [Agent Setup](agent-setup.md) - Deep dive into agent installation, configuration, and monitoring
