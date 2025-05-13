### Phase 3: Web UI Foundation

This phase introduces the foundational work to implement the web-based UI for CipherSwarm. The UI should prioritize usability for red team operators and analysts, following modern UX principles and improving on limitations of the original UI (e.g., excess clicks, unclear layout).

Skirmish should implement the UI using **HTMX** (per prior design guidance) and **Flowbite components** (for Tailwind abstraction). All pages should support dark mode and use purple as the primary accent color.

**Note:** Any API endpoint required to support UI functionality but not present in the current implementation should be created as part of this phase.

---

### ✅ Implementation Tasks

#### 🧱 Core Setup

-   [ ] Integrate HTMX with the frontend project.
-   [ ] Integrate Flowbite (ensure base CSS and JS are loaded). This must be available offline and not require a CDN.
-   [ ] Create a base layout template (`base.html`) using Flowbite’s layout components with:

    -   Header
    -   Sidebar
    -   Main content area
    -   Toast/alert system for real-time feedback
    -   Dark mode toggle

-   [ ] Implement user authentication-aware layout state (i.e., menu items hidden/shown based on role).

#### 👤 User Management UI (Admin only)

-   [ ] User table view with filters for role, locked/unlocked status.
-   [ ] Modal or drawer form for:

    -   Creating new user
    -   Editing existing user (role, lock/unlock, reset password)

-   [ ] Backend integration:

    -   Create, update, lock/unlock, delete/reset password API support (if missing)

#### ⚙️ Agent Management UI

-   [ ] Agent list view showing:

    -   Agent ID
    -   Status (online/offline)
    -   Last heartbeat
    -   Assigned campaigns

-   [ ] Admin controls to:

    -   Add new agents
    -   Disable/reactivate agents

#### 📦 Hash List Management (User-level)

-   [ ] List view for hash lists scoped to assigned projects
-   [ ] Create/edit form:

    -   Name
    -   Project
    -   Upload hashes
    -   Sensitivity toggle

-   [ ] Detail view:

    -   Cracked vs. uncracked count
    -   Table of cracked hashes with:

        -   Plaintext
        -   Cracking agent
        -   Cracking attack
        -   Metadata

-   [ ] Link to relaunch attack against hash list

#### 🎯 Attack Resource Management

-   [ ] Attack resource list view with filters by type (wordlist, rules, mask) and sensitivity
-   [ ] Upload/edit form for new resources
-   [ ] Display resource metadata:

    -   Size
    -   Associated campaigns
    -   Sensitivity

#### 📈 Live Campaign Monitor View

-   [ ] Main activity dashboard showing campaigns (including ones user is not assigned to):

    -   Campaign name
    -   Progress bar
    -   State
    -   Short summary of running attack

-   [ ] Expandable details for owned/assigned campaigns:

    -   Each attack’s:

        -   Type
        -   Progress bar
        -   Estimated time to completion
        -   Attack config summary (resource used, attack type)

-   [ ] WebSocket-based live updates for:

    -   Campaign progress
    -   Attack progress
    -   Toasts for cracked hashes

📷 **Visual Style Reference Description**
The campaign and attack overview layout should resemble a modern expandable list view. Campaigns appear as top-level rows with progress bars embedded in each row. When expanded, nested entries display the individual attacks with their own progress bars and estimated time to completion. Each row uses subtle shading and iconography to convey state (running, paused, completed), and columns include human-readable descriptions of current operations.

The mask attack editor should include a vertical form with clearly labeled sections:

-   An optional mask file upload field.
-   A dropdown for selecting the language or encoding.
-   A list of editable mask patterns where the user can add/remove rows of masks.
-   An expandable section to define custom symbol sets.
-   A set of blue buttons labeled with operations like `+ Change case`, `+ Change chars order`, and `+ Substitute chars`.
    At the bottom, it includes a password estimate and a visual indicator of complexity.

The attack list should display all attack configurations in a clean table:

-   Columns include attack type, language, length, attack settings, password count, and complexity (rendered as dot indicators).
-   Joined/append attacks are grouped with a visual nesting structure and numbering indicators.
-   Each row includes a small gear icon to access a context menu with options like "Move Up", "Move Down", "Remove", etc.

#### 🔁 Relaunch Attack / Modify Wordlists

-   [ ] Add UI controls on campaign detail to:

    -   Relaunch attack (confirmation modal)
    -   Modify wordlist/ruleset and resubmit

#### 🔔 Toast Notifications (Rate-Limited)

-   [ ] Users should receive notifications when a hash is cracked for a hash list they are assigned to

    -   Toast should show plaintext, attack used, hashlist, and time
    -   Rate-limit to avoid flooding (batch into a single toast if needed)

#### 🧪 Testing/Validation

While formal frontend unit testing is not required in this phase:

-   [ ] Ensure manual testing checklist is followed:

    -   Login/logout flow
    -   Page routing
    -   Access control based on role
    -   Functional buttons for create/edit/delete
    -   Live updates work reliably on dashboard

-   [ ] Backend endpoint test coverage expanded where needed to support UI logic

---

### 📎 Notes

-   Use idiomatic HTMX + Flowbite combinations; do not introduce SPA logic or React/Vue-style dynamic behavior
-   Prioritize click-reduction and layout clarity
-   Support real-time UX without requiring full page reloads
-   Ensure backend schema and permissions match the operations surfaced in the UI

---

### 🧩 Appendix: Recommended Flowbite Components

Here are suggested Flowbite components for each major feature:

**Layout**

-   Sidebar: [Sidebar component](https://flowbite.com/docs/components/sidebar/)
-   Navbar/Header: [Navbar component](https://flowbite.com/docs/components/navbar/)
-   Dark mode toggle: [Dark Theme Toggle](https://flowbite.com/docs/customize/dark-mode/)
-   Toasts: [Toast notifications](https://flowbite.com/docs/components/toast/)

**User & Agent Management**

-   Tables: [Table component](https://flowbite.com/docs/components/table/) with icons
-   Modals for user/agent edit: [Modal component](https://flowbite.com/docs/components/modal/)
-   Badges for status (locked/unlocked, online/offline): [Badge](https://flowbite.com/docs/components/badge/)
-   Toggle: [Toggle switch](https://flowbite.com/docs/forms/toggle/)

**Hashlist/Resource Upload Forms**

-   File Upload: [File input](https://flowbite.com/docs/forms/file-input/)
-   Text Input: [Text inputs](https://flowbite.com/docs/forms/input/)
-   Dropdown: [Select](https://flowbite.com/docs/forms/select/)
-   Textarea: [Textarea](https://flowbite.com/docs/forms/textarea/)

**Campaign Monitoring**

-   Accordion for expandable campaigns: [Accordion](https://flowbite.com/docs/components/accordion/)
-   Progress bar: [Progress bar](https://flowbite.com/docs/components/progress/)
-   Tooltip for attack metadata: [Tooltip](https://flowbite.com/docs/components/tooltip/)
-   Skeleton loading (optional): [Skeleton](https://flowbite.com/docs/components/skeleton/)

**Attack Editor**

-   Table for step list: [Table + Context Menu Dropdown](https://flowbite.com/docs/components/dropdown/)
-   Dot-based complexity: [Progress dots or custom icons with Tooltip]
-   Add/Delete buttons: [Buttons + Icon buttons](https://flowbite.com/docs/components/buttons/)

This will help enforce consistency and reduce Skirmish's temptation to create one-off layouts or bring in unapproved third-party CSS nonsense. Keep the UI modular and clean—just like a well-structured ops report.
