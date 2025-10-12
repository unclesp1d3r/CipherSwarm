# CipherSwarm v2: Intent and Strategic Direction

## 🔄 Context & Motivation

CipherSwarm v2 is a comprehensive upgrade of the original CipherSwarm platform. The existing system was functional but limited — it provided basic agent/task control and some UI affordances, but was hard to scale, automate, or modernize.

The upgrade is about more than just updating dependencies. It's a shift in philosophy:

- From _a tool_ to _a platform_
- From _manual config_ to _guided workflows_
- From _hard-to-debug_ to _live feedback and observability_

We're building this for red team operators, system admins, and long-term maintainability — with the flexibility to grow into automation, integration, and multi-user coordination.

---

## ✅ Design Intent by Feature

### 🧠 **Live Agent Monitoring**

- **Intent:** Give users and admins better visibility into what's really happening with agents — speed, utilization, errors, job assignments.
- **Pain Point Solved:** In the original system, it was unclear if agents were alive or doing anything meaningful.
- **What We're Building:** Real-time telemetry, performance graphs, per-agent tabs (settings, performance, errors, capabilities).

### 🛠️ **Redesigned Attack Editor**

- **Intent:** Make the creation and tuning of attacks easier and more approachable for both non-experts and power users.
- **Pain Point Solved:** The original system used a massive form with all hashcat options shown at once. It was overwhelming.
- **What We're Building:** Modal-based editors with attack-specific fields, live keyspace/complexity estimates, intuitive modifiers, and JSON import/export.

### 🎯 **Campaign Dashboard & Orchestration**

- **Intent:** Make campaign state and flow easier to control, understand, and monitor.
- **Pain Point Solved:** The original system had poor visibility into attack order, lifecycle, or status.
- **What We're Building:** Live progress indicators, sortable/controllable attack tables, editable metadata, and start/stop toggles.

### 📂 **Inline Resource Management**

- **Intent:** Let users iteratively refine resources without having to download, edit, and re-upload files repeatedly.
- **Pain Point Solved:** Editing a wordlist or mask required deleting and recreating linked attacks.
- **What We're Building:** In-browser editing for wordlists, masks, and rules with line validation, metadata previews, and size-based gating.

### 🔓 **Crackable Uploads (in progress)**

- **Intent:** Simplify cracking workflows for less-technical users by handling extraction, validation, and attack building automatically.
- **Pain Point Solved:** Users had to manually extract hashes and guess types before running attacks.
- **What We're Building:** Upload UI that accepts files or pasted hash dumps, detects hash types, and pre-generates attacks.

### 🧪 **Infrastructure & Testing**

- **Intent:** Build a stable, testable foundation that's easier to maintain and extend.
- **Pain Point Solved:** The existing stack was brittle, poorly modularized, and hard to test.
- **What We're Building:** Comprehensive test coverage, improved API documentation and error handling, modernized development environment, and enhanced system monitoring.

### 🧑‍💻 **Control API + TUI**

- **Intent:** Provide a scriptable, headless interface for red team automation and CLI use.
- **Pain Point Solved:** The existing system has limited CLI/TUI or integration interfaces.
- **What We're Building:** A full Control API with planned TUI client; will support scripting, outside system integration, and role-scoped control surfaces.

---

## 🧭 Strategic North Star

CipherSwarm v2 isn't just about cracking faster — it's about cracking **smarter**:

- Give users the tools they need without making them learn internals
- Make live feedback and visibility the default
- Design for automation, auditability, and multi-user coordination

This upgrade is where the platform reaches its full potential.
