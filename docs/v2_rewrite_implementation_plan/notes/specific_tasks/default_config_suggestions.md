# Default Attack Config Suggestions

---

## 🧠 Task: Show Default Attack Config Suggestions

**ID:** `attack.default_config_suggestions` **Context:** Attack Editor UI (Web)

### 🧭 Purpose

Provide a curated list of **default attack configurations** (e.g., common mask patterns, rulesets, and charset combos) to guide new or casual users. These suggestions should be admin-managed and project-aware, enabling power users to surface battle-tested configurations to the rest of the team.

### ✅ Final Design Approach

Rather than hardcoding suggestions or adding a new system, we will **extend the existing `AttackTemplate` concept** to allow templates to be stored and flagged as "recommended" in the backend.

Templates with `recommended: true` will be exposed to the frontend as default suggestions for use in the attack editor. These templates will be stored in the database (not just as import/export files) and may be project-scoped or global.

---

## 🔧 Implementation Tasks

### 📦 Backend Tasks

- [ ] Add a new `AttackTemplateRecord` database model to persist named templates server-side

- [ ] Include fields:

  - `name: String`
  - `description: Text`
  - `attack_mode: Integer` (enum reference to AttackMode)
  - `recommended: Boolean`
  - `project_id: Integer` (nullable, belongs_to :project, optional: true)
  - `template_json: JSON`
  - `created_at: DateTime`

- [ ] Create API endpoint `GET /api/v1/web/templates/` - Returns only templates where `recommended = true` and `project_id` is null or equals the current project (unless the user is an admin)

  - Takes a parameter `attack_mode: Integer` to filter templates by attack mode
  - Takes a parameter `project_id: Integer` (nullable) to filter templates by project (unless the user is an admin)
  - Returns a JSON array of `AttackTemplateRecord` objects

- [ ] Add `POST /api/v1/web/templates/` for creating a new template in the database (admin-only)

- [ ] Add `GET /api/v1/web/templates/{id}` for retrieving a template from the database

- [ ] Add `PATCH /api/v1/web/templates/{id}` for updating a template in the database (admin-only)

- [ ] Add `DELETE /api/v1/web/templates/{id}` for deleting a template in the database (admin-only)

### 🧑‍💼 Admin UI Tasks

- [ ] Add UI to list and manage stored templates (admin-only)
- [ ] Add an upload form that accepts an AttackTemplate JSON file via drag and drop or file upload
- [ ] Allow global (project-less) templates to be marked as reusable across the entire instance
- [ ] Add a button to remove a template
- [ ] Add a button to open a modal to allow the assigned project to be selected via dropdown, with a save button, cancel button, and a "Clear Project" button to set it to null (global).

### 🎨 Attack Editor UI Tasks

- [ ] Display a new dropdown or section labeled "_"Use a Recommended Template"_
- [ ] Pull recommended templates from the new endpoint (show all templates where `project_id IS NULL` or `project_id` equals the current project)
- [ ] Autofill the attack editor with the selected template's config (mask, rule, charset, etc.)
- [ ] Allow editing after selection — this is just a starting point to prefill the attack editor with a template, but the user should be able to edit the attack editor after selection.

---

## 🧠 Benefits

- Admins can define reusable, pre-tuned configurations
- New users get battle-tested starting points without needing to understand hashcat internals
- Project-scoped recommendations allow tailored templates for different customers or ops
- TUI and CLI workflows can reuse the same backend logic
