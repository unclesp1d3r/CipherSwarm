<!-- To simplify this file, I'm going to move pieces into sub-files and link them here. -->

<!-- I've added comment tags to make where sections begin to make it easier for AI to identify them. This is also in the linked files. -->

# Phase 2: API Implementation

This document defines the complete Phase 2 API architecture for CipherSwarm, including:

-   Agent API (stable, implemented)
-   Supporting algorithms like hash guessing
-   Web UI API for interactive HTMX-driven frontend
-   Control API for programmatic access
-   Shared schema structures (e.g. campaign/attack templates)

All tasks are organized by logical function with Skirmish-compatible `task_id:` markers. Prerequisite model or service-layer requirements appear before the endpoints or flows that use them.

To keep this file from getting too long, I've moved some sections into sub-files. I've also added comment tags to make it easier for AI to identify where sections begin. You can find the sub-files in the `phase-2-api-implementation-parts` directory. Shared algorithms and instructions are in this file.

---

## ✅ Table of Contents

1. 🔐 [Agent API (Stable)](phase-2-api-implementation-parts/phase-2-api-implementation-part-1.md)
2. 🧠 [Supporting Algorithms](#supporting-algorithms)

    - [Hash Guessing Logic](#hash-guessing-logic)

3. 🌐 [Web UI API (](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#-web-ui-api-apiv1web)[`/api/v1/web/*`](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#-web-ui-api-apiv1web)[)](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#-web-ui-api-apiv1web)

    - 🌟 [Campaign Management](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#campaign-management)
    - 💥 [Attack Management](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#attack-management)
    - ⚙️ [Agent Management](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#agent-management)
    - 📁 [Resource Browser](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#resource-browser)
    - 📂 [Crackable Uploads](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#crackable-uploads)
    - 👤 [Authentication & Profile](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#authentication--profile)
    - 🔧 [UX Utility](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#ux-support--utility)
    - 🛳️ [Live HTMX / WebSocket Feeds](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md#live-htmx--websocket-feeds)

4. ⌨️ [Control API (](phase-2-api-implementation-parts/phase-2-api-implementation-part-3.md#control-api-apiv1control)[`/api/v1/control/*`](phase-2-api-implementation-parts/phase-2-api-implementation-part-3.md#control-api-apiv1control)[)](phase-2-api-implementation-parts/phase-2-api-implementation-part-3.md#control-api-apiv1control)
5. 🧾 [Shared Schema: Save/Load](#shared-schema-saveload)
6. ✅ [Notes for Cursor](#notes-for-cursor)

---

This phase outlines the full API architecture for CipherSwarm, including agent interaction, web UI functionality, and future TUI support. All endpoints must follow RESTful conventions and enforce authentication, validation, and input sanitation.

---

## 🔐 Agent API (High Priority)

!!! note

    This section is moved to [Phase 2 - Part 1](phase-2-api-implementation-parts/phase-2-api-implementation-part-1.md).

<!-- Note to AI: This section is moved to [Phase 2 - Part 1](phase-2-api-implementation-parts/phase-2-api-implementation-part-1.md). -->

---

## Supporting Algorithms

### 🔍 Hash Guessing Logic

CipherSwarm should include a reusable hash analysis and type inference utility built around the [Name-That-Hash](https://github.com/bee-san/Name-That-Hash) library. This utility should be implemented in the service layer and callable from both the Web UI API and the Control API. It is responsible for examining pasted text, extracted hash lines, or uploaded artifacts and returning likely hash types based on structure, length, encoding, and known patterns.

The service must:

-   Use `name-that-hash`'s native Python API (not subprocess)
-   Wrap its response in CipherSwarm-style confidence-ranked outputs
-   Be independently unit tested
-   Be integration tested via the Web UI's hash validation endpoint capable of examining pasted text, extracted hash lines, or uploaded artifacts and returning likely hash types based on structure, length, encoding, and known patterns.

#### 🔧 Requirements

-   [ ] Accept pasted lines, files, or blobs of unknown hash material
-   [ ] Identify most likely matching hash types (from hashcat-compatible types)
-   [ ] Return ranked suggestions with confidence scores
-   [ ] Handle common multiline inputs like:

    -   `/etc/shadow` lines
    -   `secretsdump` output
    -   Cisco IOS config hash lines

-   [ ] Normalize formatting (e.g., strip usernames, delimiters)
-   [ ] Expose results in a format usable by both API layers and testable independently

Example response:

```json
{
    "candidates": [
        { "hash_type": 1800, "name": "sha512crypt", "confidence": 0.95 },
        { "hash_type": 7400, "name": "sha256crypt", "confidence": 0.35 }
    ]
}
```

This layer will power:

-   Crackable Uploads (Web UI)
-   Direct hash submission tools (Control API)
-   Potential future CLI tools like `cipherswarm guess-hash`

---

## 🌐 Web UI API (`/api/v1/web/*`)

!!! note

    This section is moved to [Phase 2 - Part 2](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md).

<!-- Note to AI: This section is moved to [Phase 2 - Part 2](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md). -->

---

### ⌨️ Control API (`/api/v1/control/*`)

!!! note

    This section is moved to [Phase 2 - Part 3](phase-2-api-implementation-parts/phase-2-api-implementation-part-3.md).

<!-- Note to AI: This section is moved to [Phase 2 - Part 3](phase-2-api-implementation-parts/phase-2-api-implementation-part-3.md). -->

---

## 🧾 Shared Schema: Save/Load

CipherSwarm supports export and import of core objects using a shared JSON-based schema. These templates are used by both the Web UI and the Control API to persist, modify, and replicate campaign structures across environments.

### 🔗 Scope

The following object types support import/export:

-   Campaigns
-   Attacks
-   Resource Bundles (optional future feature)

### 📁 Usage

-   Web UI: save/load dialogs, Crackable Upload post-processing
-   Control API: `csadmin campaign export`, `csadmin attack import`, etc.
-   JSON files may be checked into version control or bundled for transport

### 🧾 Format Requirements

-   Schema must match Web UI expectations exactly (round-trip safe)
-   All fields must be versioned implicitly or explicitly
-   Reserved fields:

    -   `_schema_version` (optional)
    -   `project_id` may be omitted or overridden during import.&#x20;

### 🧪 Validation

-   JSON templates must be validated against their Pydantic schema before use
-   Cipherswarm should ignore unknown fields on templates

### 🔧 Sample Structure

Each referenced resource (wordlist, rule, mask) must use a stable UUID (`guid`) if it is a named, non-ephemeral file. This GUID is assigned at resource creation and used to re-link templates during import.

On import:

-   If a referenced `guid` does not exist in the target project, the importer must prompt for a replacement, skip the attack, or abort
-   Ephemeral files may be inlined in the template (e.g., a `wordlist_inline` or `masks: []` field)
-   📌 _Note: HashLists are not embedded in save/load templates. Campaigns reference existing hashlists by ID. HashList metadata and crackable hash import/export are handled through the HashList API, not the template layer._
-   If both `id` and `guid` are present, `id` should be ignored

```json
{
    "_schema_version": "20250511",
    "name": "Weekly Campaign 12",
    "description": "Pulled from red team box dump",
    "attacks": [
        {
            "mode": "dictionary",
            "wordlist_guid": "f3b85a92-45c8-4e7d-a1cd-6042d0e2deef",
            "rule_file": "best64.rule",
            "min_length": 6,
            "max_length": 16
        }
    ]
}
```

### ✅ Implementation Tasks

-   [x] `schemas.shared.AttackTemplate` – JSON-compatible model for attacks `task_id:schema.attack_template`
-   [x] `schemas.shared.CampaignTemplate` – Top-level structure including attacks/hashlist `task_id:schema.campaign_template`
-   [ ] `schema_loader.validate()` – Helper to validate, coerce, and upgrade templates `task_id:schema.validation_layer`

---

## ✅ Notes for Cursor

📘 **API Format Policy**

-   The **Agent API** must remain fully compliant with the legacy v1 contract as defined in `swagger.json`. No deviations are permitted.
-   The **Web UI API** may use whatever response structure best supports HTMX rendering — typically HTML fragments or minimal JSON structures, not JSON\:API.
-   The **Control API** should adopt regular **FastAPI + Pydantic v2 JSON** response models, optionally supporting MsgPack for performance-critical feeds.

Skirmish and other coding assistants should apply response formatting standards based on the API family:

-   `/api/v1/client/*`: legacy, strict
-   `/api/v1/web/*`: HTMX-friendly (HTML or minimal JSON)
-   `/api/v1/control/*`: structured JSON — the canonical interface for automation, scripts, or CLI clients
