<!-- section: web-ui-api -->

## 🌐 Web UI API (`/api/v1/web/*`)

These endpoints support the HTMX-based dashboard that human users interact with. They power views, forms, toasts, and live updates. Agents do not use these endpoints. All list endpoints must support pagination and query filtering.

---

⚠️ HTMX requires each of these endpoints to return **HTML fragments or partials**, not JSON. This is essential for proper client-side rendering and dynamic behavior. Every endpoint should return a rendered Jinja2 or equivalent template suitable for `hx-target` or `ws-replace` swaps.

🧭 These endpoints define the backend interface needed to support the user-facing views described in [Phase 3 - Web UI Foundation](../phase-3-web-ui-foundation.md). As you implement the frontend (Phase 3), be sure to reference this section to ensure every view or modal maps to a corresponding route here. We recommend annotating templates with source endpoint comments and may add cross-references in Phase 3 to maintain that alignment.

These endpoints support the HTMX-based dashboard that human users interact with. They power views, forms, toasts, and live updates. Agents do not use these endpoints. All list endpoints must support pagination and query filtering.

<!-- section: web-ui-api-campaign-management -->

### _🌟 Campaign Management_

<!-- section: web-ui-api-campaign-management-model-requirements -->

#### 🧩 Model Requirements

To fully support UI ordering, user-friendly attack summaries, and richer campaign lifecycle controls, the following model-level fields must be added or updated:

-   [x] Add `Attack.position: int` – numeric ordering field within a campaign `task_id:model.attack.position`
-   [x] Add `Attack.comment: Optional[str]` – user-provided description for UI display `task_id:model.attack.comment`
-   [x] Add `Attack.complexity_score: Optional[int]` – derived from keyspace or agent benchmarks, range 1–5 `task_id:model.attack.complexity_score`
-   [x] Optionally evolve `Campaign.active: bool` into `Campaign.state: Enum` (`draft`, `active`, `archived`, etc.) to support lifecycle toggles and clear workflow states `task_id:model.campaign.state_enum`

These fields must be integrated into campaign detail responses, sortable/queryable in the DB layer, and respected in API output.

<!-- section: web-ui-api-campaign-management-implementation-tasks -->

#### 🧩 Implementation Tasks

> [!NOTE]
> Some agent configuration and telemetry endpoints (e.g., fine-grained device toggles, temperature abort thresholds, hashcat backend flags) may not be fully supported by the current v1 Agent API.
>
> These are earmarked for Phase 5 implementation when Agent API v2 is introduced.
>
> Be sure to encapsulate such features behind feature flags or optional fields in the backend to avoid breaking compatibility.

> [!NOTE]
> Agent display name
>
> logic
> `display_name = agent.custom_label or agent.host_name`
>
> This fallback logic must be applied anywhere an agent is shown to the user. Include this behavior in both API response schemas and frontend template logic to ensure consistent display.

-   [x] Add `guid: UUID = uuid4()` field to `AttackResourceFile` to enable export/import referencing `task_id:model.resource.guid_support`
-   [x] Add `POST /api/v1/web/campaigns/{id}/reorder_attacks` to accept a list of attack IDs and persist order `task_id:campaign.reorder_attacks`
-   [x] Add `POST /api/v1/web/attacks/{id}/move` with direction (`up`, `down`, `top`, `bottom`) to reposition relative to other attacks `task_id:attack.move_relative`
-   [x] Add `POST /api/v1/web/attacks/{id}/duplicate` to clone an attack in-place `task_id:attack.duplicate`
-   [x] Add `DELETE /api/v1/web/attacks/bulk` to delete multiple attacks by ID `task_id:attack.bulk_delete`
-   [x] Add `POST /api/v1/web/campaigns/{id}/start` and `POST /api/v1/web/campaigns/{id}/stop` to manage lifecycle state `task_id:campaign.lifecycle_toggle`
-   [x] Add or enrich campaign attack view model to support: type label, length, friendly settings summary, keyspace, complexity, and user comments `task_id:campaign.attack_summary_viewmodel`
-   [x] `GET /api/v1/web/campaigns/` – List campaigns (paginated, filterable). Should support HTMX polling or WebSocket-driven update triggers to notify the browser when campaign progress changes and refresh the relevant list view. `task_id:campaign.list_view`
-   [x] `POST /api/v1/web/campaigns/` – Create a new campaign `task_id:campaign.create`
-   [x] `GET /api/v1/web/campaigns/{id}` – Campaign detail view with attacks/tasks `task_id:campaign.detail_view`
-   [x] `PATCH /api/v1/web/campaigns/{id}` – Update campaign `task_id:campaign.update`
-   [x] `DELETE /api/v1/web/campaigns/{id}` – Archive/delete campaign `task_id:campaign.archive_delete`
-   [x] `POST /api/v1/web/campaigns/{id}/add_attack` – Add attack to campaign `task_id:campaign.add_attack`
-   [x] `GET /api/v1/web/campaigns/{id}/progress` – Structure and return campaign progress/status fragment for HTMX polling `task_id:campaign.progress_fragment`
-   [x] `GET /api/v1/web/campaigns/{id}/metrics` – Aggregate stats (see items 3 and 5 of [Core Algorithm Implementation Guide](../core_algorithm_implementation_guide.md)) `task_id:campaign.metrics_summary`
-   [x] `POST /api/v1/web/campaigns/{id}/relaunch` – Relaunch attack if previously failed, or if any linked resource (wordlist, mask, rule) has been modified since the last run. Requires re-validation and explicit user confirmation. `task_id:campaign.rerun_attack`

<!-- section: web-ui-api-attack-management -->

### _💥 Attack Management_

<!-- section: web-ui-api-campaign-management-ux-design-goals -->

#### 🧩 UX Design Goals

These design goals are for the attack editor modal and should be applied to the fragment sent to the client. Though not exclusively API-related, these are important considerations for the API implementation and will be finalized in Phase 3 with the full user interface implementation. After adding the appropriate supporting functionality to the models and endpoints, Skirmish should add stub templates for these views with TODO comments to ease implementing phase 3 frontend.

##### 🔁 Common Editing Features

-   [x] Dynamically update keyspace and complexity score for unsaved changes `task_id:attack.ux_estimate_unpersisted`
-   [x] Show these values in attack editor view like campaign detail view `task_id:attack.ux_estimate_view`
-   [x] Warn and require confirmation when editing an `exhausted` or `running` attack `task_id:attack.ux_edit_lifecycle_reset`
-   [x] Confirming edit resets attack to `pending` and triggers reprocessing `task_id:attack.ux_edit_lifecycle_reset`
-   [ ] Allow export/import of JSON files for Attack or Campaign (supports template reuse) `task_id:attack.ux_export_import_json`

##### 📚 Dictionary Attack UX

-   [ ] Min/max length fields default to typical hash type range (e.g., 1–32) `task_id:attack.ux_dictionary_length_defaults`
-   [ ] Wordlist dropdown with search, sorted by last modified, includes entry count `task_id:attack.ux_dictionary_wordlist_dropdown`
-   [ ] "Modifiers" button group for non-expert users (e.g., `+ Change Case`, `+ Substitute Characters`) `task_id:attack.ux_dictionary_modifiers`
-   [ ] Optional rule list dropdown for expert users `task_id:attack.ux_dictionary_rule_dropdown`
-   [ ] Support "Previous Passwords" as dynamic wordlist option `task_id:attack.ux_dictionary_previous_passwords`
-   [ ] Support ephemeral wordlist field with "Add Word" UI for small throwaway lists `task_id:attack.ux_dictionary_ephemeral_wordlist`

##### 🎭 Mask Attack UX

-   [x] Add/remove inline mask lines (ephemeral mask list) `task_id:attack.ux_mask_inline_lines`
-   [ ] Validate mask syntax in real-time `task_id:attack.ux_mask_syntax_validation`
-   [ ] Ephemeral mask list stored only with the attack, deleted when attack is removed `task_id:attack.ux_mask_ephemeral_storage`

##### 🔢 Brute Force UX

-   [ ] Checkbox UI for charset selection (`Lowercase`, `Uppercase`, `Numbers`, `Symbols`, `Space`) `task_id:attack.ux_brute_force_charset_selection`
-   [ ] Range selector for mask length (min/max) `task_id:attack.ux_brute_force_length_selector`
-   [ ] Automatically generate `?1?1?...` style mask based on selected length `task_id:attack.ux_brute_force_mask_generation`
-   [ ] Derive `?1` charset from selected charsets (e.g., `?l?d` for lowercase + digits) `task_id:attack.ux_brute_force_charset_derivation`

<!-- section: web-ui-api-campaign-management-save-load-schema-design -->

#### 🧩 Save/Load Schema Design

CipherSwarm should allow saving and loading of both individual Attacks and entire Campaigns via a custom JSON format. This will support backup, sharing, and preconfiguration workflows.

🔐 The exported format must include:

-   All editable fields of the attack or campaign, including position and comment
-   For campaigns: the order of attached attacks must be preserved
-   Any ephemeral word or mask lists used by an attack must be serialized as inline content
-   For linked non-ephemeral resources (wordlists, masks, rules), include their stable UUID (`guid`) for re-linking

🚫 The exported format must **not** include:

-   Project ID or User ID bindings
-   Internal database primary keys

📥 On import:

-   The backend must validate schema correctness
-   Rehydrate ephemeral resources directly
-   Look up non-ephemeral resources by GUID (`AttackResourceFile.guid`)
-   Prompt the user or fail gracefully if a GUID reference does not resolve

This schema should be versioned and tested against a validation spec.

A new `guid: UUID` field must be added to the `AttackResourceFile` model to support this. It should be unique, stable across sessions, and used as the canonical identifier for serialization workflows. The GUID should be generated using `uuid4()` at the time the resource is first created, and must remain immutable and internal-only (not exposed to Agent APIs).

If a resource referenced by GUID cannot be matched during import (either due to deletion or lack of permission), the user must be prompted with three fallback options:

1. **Select a Replacement** – Choose a compatible resource of the same `resource_type` from a dropdown
2. **Skip Affected Attack** – Import the rest of the campaign, omitting attacks missing required resources
3. **Abort Import** – Cancel the import entirely

All fallback logic should be implemented server-side with support for frontend prompting. to support this. It should be unique, stable across sessions, and used as the canonical identifier for serialization workflows. of both individual Attacks and entire Campaigns via a custom JSON format. This will support backup, sharing, and preconfiguration workflows.

🔐 The exported format must include:

-   All editable fields of the attack or campaign, including position and comment
-   For campaigns: the order of attached attacks must be preserved
-   Any ephemeral word or mask lists used by an attack must be serialized as inline content

🚫 The exported format must **not** include:

-   Project ID or User ID bindings
-   Hash list references (campaigns must be re-linked to a hash list upon import)
-   Internal database IDs

📥 On import:

-   The backend must validate schema correctness
-   Attachments to new or existing campaigns must be confirmed explicitly
-   Inline ephemeral resources must be rehydrated as temporary DB records

This schema should be versioned and tested against a validation spec.

---

#### Ephemeral Resources

<!-- section: web-ui-api-ephemeral-resources -->

Attacks can support ephemeral resources that can be created and edited within the attack editor. These resources are still persisted to the database, but they are stored as part of an AttackResourceFile record as a JSON structure, and are not visible in the Resource Browser or available for reuse in other attacks. They are deleted when the attack is deleted, they do not have a backing file in S3, and they are exported inline if the attack is exported within the same JSON file. The Agent API will provide a non-signed URL to agents to access these resources when the attack is running and they are downloaded directly from CipherSwarm, rather than the MinIO service.

---

<!-- section: web-ui-api-campaign-management-extended-implementation-tasks -->

#### 🧩 Extended Implementation Tasks

These tasks expand the attack editing interface and logic to support contextual UIs, one-off resources, and user-friendly modifiers without exposing raw hashcat details.

-   [x] Implement `POST /api/v1/web/attacks/estimate` to return keyspace + complexity score for unsaved attack input `task_id:attack.estimate_unpersisted` (see [Phase 2 Implementation Tasks](../phase-2-api-implementation-tasks.md#hash-guessing-logic))
-   [x] Add edit-protection logic to warn if attack is `running` or `completed` before allowing edit (Web UI API) `task_id:attack.edit_protect`
-   [x] Support ephemeral inline wordlists (multiple `add word` fields) stored in memory or DB during attack creation, deleted when the attack is deleted. (Web UI API) `task_id:attack.ephemeral_wordlist`
-   [x] Support ephemeral inline masks (`add mask` line interface) with same lifecycle behavior `task_id:attack.ephemeral_masklist` (see section [Ephemeral Resources](#ephemeral-resources) above)
-   [ ] Implement "Modifiers" UI: map toggled options (change case, swap characters, etc.) to preselected rules files under the hood `task_id:attack.modifier_ui_to_rules`
-   [ ] Dictionary attack UI must support: min/max length, searchable wordlist dropdown (sorted by last modified), option to use dynamic wordlist from previous project cracks `task_id:attack.dictionary_ui_controls`
-   [x] Brute force UI must allow checkbox-driven charset selection, range selector, and generate corresponding `?1?1?...` style masks and `?1` custom charset `task_id:attack.brute_force_ui_logic` (strong typing enforced)
-   [x] Add support to export any single Attack or entire Campaign to a JSON file `task_id:attack.export_json`
-   [ ] Add support to load campaign or attack JSON file and prefill the editor `task_id:attack.import_json_schema`

The attack editor must support a modal-based, multi-form interface with per-attack-type customization. It should dynamically update keyspace estimates and complexity scores as the user changes input.

-   ⚙️ The editor must show real-time keyspace and complexity values, even for non-persisted attacks. Backend support is needed for live estimation.
-   ⚠️ Editing an attack that is already running or exhausted must trigger a confirmation prompt and reset the state if confirmed. This restarts the attack lifecycle.
-   ✍️ User-facing options should be simplified (e.g. "+ Change Case") and map to hashcat rule resources internally.
-   🔁 Certain attack types (e.g., dictionary, brute force) must support one-off word/mask lists that are ephemeral and attack-local.

<!-- section: web-ui-api-campaign-management-implementation-tasks -->

#### 🧩 Implementation Tasks

-   [ ] Implement `POST /attacks/validate` for dry-run validation with error + keyspace response `task_id:attack.validate`
-   [ ] Validate resource linkage: masks, rules, wordlists must match attack mode `task_id:attack.resource_type_constraints`
-   [ ] Support creation via `POST /attacks/` with full config validation `task_id:attack.create_endpoint`
-   [ ] Return Pydantic validation error format on failed creation `task_id:attack.validation_error_format`
-   [ ] Support reordering attacks in campaigns (if UI exposes it) `task_id:attack.reorder_within_campaign`
-   [ ] Implement performance summary endpoint: `GET /attacks/{id}/performance` `task_id:attack.performance_summary`
-   [ ] Implement toggle: `POST /attacks/{id}/disable_live_updates` `task_id:attack.disable_live_updates`
-   [ ] All views must return HTML fragments (not JSON) suitable for HTMX rendering `task_id:attack.html_fragments_htmx`
-   [ ] All views should support WebSocket/HTMX auto-refresh triggers `task_id:attack.live_updates_htmx`
-   [ ] Add human-readable formatting for rule preview (e.g., rule explanation tooltips) `task_id:attack.rule_preview_explanation`
-   [ ] Implement default value suggestions (e.g., for masks, charset combos) `task_id:attack.default_config_suggestions`

_Includes support for a full-featured attack editor with configurable mask, rule, wordlist resources; charset fields; and validation logic. Endpoints must power form-based creation, preview validation, reordering, and config visualization._

_All views should support HTMX WebSocket triggers or polling to allow dynamic refresh when agent-submitted updates occur._

-   [ ] `GET /api/v1/web/attacks/` – List attacks (paginated, searchable) `task_id:attack.list_paginated_searchable`
-   [ ] `POST /api/v1/web/attacks/` – Create attack with config validation `task_id:attack.ux_created_with_validation`
-   [ ] `GET /api/v1/web/attacks/{id}` – View attack config and performance `task_id:attack.ux_view_config_performance`
-   [ ] `PATCH /api/v1/web/attacks/{id}` – Edit attack `task_id:attack.ux_edit_attack`
-   [ ] `DELETE /api/v1/web/attacks/{id}` – Delete attack `task_id:attack.ux_delete_attack`
-   [ ] `POST /api/v1/web/attacks/validate` – Return validation errors or keyspace estimate (see [Core Algorithm Implementation Guide](../core_algorithm_implementation_guide.md)) `task_id:attack.validate_errors_keyspace`
-   [ ] `GET /api/v1/web/attacks/{id}/performance` – Return task/agent spread, processing rate, and agent participation for a given attack. Used to diagnose bottlenecks or performance issues by surfacing which agents worked the task, their individual speed, and aggregate throughput. Useful for verifying whether a slow campaign is due to insufficient agent coverage or unexpectedly large keyspace. `task_id:attack.performance_diagnostics`
-   [ ] `POST /api/v1/web/attacks/{id}/disable_live_updates` – Toggle WS/HTMX sync `task_id:attack.disable_live_updates`

<!-- section: web-ui-api-agent-management -->

### _⚙️ Agent Management_

#### 🧩 UX Design Goals

##### 🖥️ Agent List View

-   Everyone can see all agents and their state
-   Admin-only gear menu (Disable Agent / View Details)
-   Columns:

    -   Agent Name + OS
    -   Status
    -   Temp (°C) and Utilization (avg of enabled devices)
    -   Current and Average Attempts/sec
    -   Current Job (Project, Campaign, Attack)

##### ➕ Agent Registration

-   Modal to enter label and select Projects (multi-toggle)

    -   Upon creating a new agent, the UI must immediately display the generated token for copy/paste. Tokens are only shown once.

-   Upon save, display generated token to admin

##### ⚙️ Agent Detail Tabs

###### 🔧 Settings

-   `display_name = agent.custom_label or agent.host_name`
-   Toggle: Enabled/Disabled
-   Agent Update Interval (sec, default randomized 1–15)
-   Toggle: Use Native Hashcat (sets `AdvancedAgentConfiguration.use_native_hashcat = true`)
-   Toggle: Enable Additional Hash Types (`--benchmark-all`)
-   List: Project assignment toggles
-   Static: OS, IP, Signature, Token

###### 🖥️ Hardware

-   List of backend devices from `--backend-info`
-   Toggle each device on/off → updates `backend_device`
-   Device toggling prompts: Apply now / Next Task / Cancel if task is running
-   Show gray placeholder if no devices reported yet
-   HW Settings:

    -   `--hwmon-temp-abort` (note only, default to 90°C)

        -   Note: This field is not yet supported by the v1 Agent API, but could be added safely to `AdvancedAgentConfiguration` as an optional key. The agent will ignore unknown fields.

    -   OpenCL Device Type selector (`opencl_devices`)

-   Backend toggles: CUDA, HIP, Metal, OpenCL → affect `--backend-ignore-*`

###### 📈 Performance

-   Line chart of `DeviceStatus.guess_rate` over time (8hr window)
-   Donut chart per device within card: Utilization as a percentage (or N/A)
-   Live updating via WebSocket

###### 🪵 Log

-   Timeline of `AgentError` entries
-   Color-coded severity
-   Fields: message, code, task link, details

###### 🧠 Capabilities

-   Pulls from `HashcatBenchmark`
-   Table (rollup view): Toggle / Hash ID / Name / Speed / Category
-   Expandable rows per device
-   Filterable + searchable
-   Caption with benchmark timestamp
-   Header button to trigger benchmark (sets `agent.state = pending`)

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/web/agents/` – List/filter agents `task_id:agent.list_filter`
-   [ ] `GET /api/v1/web/agents/{id}` – Detail view `task_id:agent.detail_view`
-   [ ] `PATCH /api/v1/web/agents/{id}` – Toggle enable/disable `task_id:agent.toggle_state`
-   [ ] `POST /api/v1/web/agents/{id}/requeue` – Requeue failed task `task_id:agent.manual_requeue`
-   [ ] `GET /api/v1/web/agents/{id}/benchmarks` – View benchmark summary `task_id:agent.benchmark_summary`
-   [ ] `POST /api/v1/web/agents/{id}/test_presigned` – Validate URL access `task_id:agent.presigned_url_test`
-   [ ] `PATCH /api/v1/web/agents/{id}/config` – Update `AdvancedAgentConfiguration` toggles (backend_ignore, opencl, etc.) `task_id:agent.config_update`
-   [ ] `PATCH /api/v1/web/agents/{id}/devices` – Toggle individual backend devices (stored as stringified int list) `task_id:agent.device_toggle`
-   [ ] `POST /api/v1/web/agents/{id}/benchmark` – Trigger new benchmark run (set to `pending`) `task_id:agent.benchmark_trigger`
-   [ ] `GET /api/v1/web/agents/{id}/errors` – Fetch structured log stream `task_id:agent.log_stream`
-   [ ] `GET /api/v1/web/agents/{id}/performance` – Stream guesses/sec time series `task_id:agent.performance_graph`
-   [ ] `POST /api/v1/web/agents` – Register new agent + return token `task_id:agent.create`
-   [ ] `GET /api/v1/web/agents/{id}/hardware` – Report backend devices, temp limits, platform support flags `task_id:agent.hardware_detail`
-   [ ] `PATCH /api/v1/web/agents/{id}/hardware` – Update hardware limits + platform toggles `task_id:agent.hardware_update`
-   [ ] `GET /api/v1/web/agents/{id}/capabilities` – Show benchmark results (table + graph) `task_id:agent.capabilities_table`

_Includes real-time updating views, hardware configuration toggles, performance monitoring, and error visibility. Most endpoints should use HTMX/WebSocket triggers to refresh data without full page reloads._ should be supported on list and detail views for dynamic agent status refresh.\*

-   [ ] `GET /api/v1/web/agents/` – List/filter agents `task_id:agent.list_filter`
-   [ ] `GET /api/v1/web/agents/{id}` – Detail view `task_id:agent.detail_view`
-   [ ] `PATCH /api/v1/web/agents/{id}` – Toggle enable/disable `task_id:agent.toggle_state`
-   [ ] `POST /api/v1/web/agents/{id}/requeue` – Requeue failed task `task_id:agent.manual_requeue`
-   [ ] `GET /api/v1/web/agents/{id}/benchmarks` – View benchmark summary `task_id:agent.benchmark_summary`
-   [ ] `POST /api/v1/web/agents/{id}/test_presigned` – Validate URL access `task_id:agent.presigned_url_test`

<!-- section: web-ui-api-resource-browser -->

### _📁 Resource Browser_

CipherSwarm uses `AttackResourceFile` objects to represent reusable cracking resources such as mask lists, wordlists, rule files, and custom charsets. All uploads go through the CipherSwarm backend, which creates the database record and issues a presigned S3 upload URL. No object in storage should exist without a matching DB entry. Each file includes a declared `resource_type` that drives editor behavior, validation rules, and allowed usage in attacks.

Line-oriented resources (masks, rules, small wordlists) may be edited interactively in the Web UI. Each line is validated individually and exposed via a dedicated endpoint. Larger files must be downloaded, edited offline, and reuploaded.

<!-- section: web-ui-api-resource-browser-implementation-tasks -->

#### 🧩 Implementation Tasks

-   [x] Implement `AttackResourceFile.resource_type` with enum (`mask_list`, `rule_list`, etc.) `task_id:resource.define_enum`
-   [x] Store and expose `line_format`, `line_encoding`, `used_for_modes`, `source` `task_id:resource.augment_metadata`
-   [x] Expose line-count and byte-size metadata for edit gating `task_id:resource.expose_editability_metrics`
-   [ ] Validate allowed attack usage based on resource type `task_id:resource.enforce_attack_mode_constraints`
-   [ ] Reject file uploads over configured size/line threshold (configurable) `task_id:resource.upload_limit_check`
-   [ ] Create line-editing endpoints: `task_id:resource.line_api_endpoints`

    -   [ ] `GET /resources/{id}/lines`
    -   [ ] `POST /resources/{id}/lines`
    -   [ ] `PATCH /resources/{id}/lines/{line_id}`
    -   [ ] `DELETE /resources/{id}/lines/{line_id}`

-   [ ] Add model: `ResourceLineValidationError` `task_id:resource.line_validation_model`
-   [ ] Validate line syntax per type (`mask_list`, `rule_list`) and return structured JSON `task_id:resource.validate_line_content`
-   [ ] Return `204 No Content` on valid edits, `422` JSON otherwise `task_id:resource.line_edit_response`
-   [ ] Disable editing for `dynamic_word_list` and oversize files `task_id:resource.edit_restrictions`
-   [ ] Support inline preview and batch validation (`?validate=true`) `task_id:resource.line_preview_mode`
-   [ ] Ensure file uploads always create an `AttackResourceFile` (via presign + DB insert) `task_id:resource.upload_contract_enforcement`
-   [ ] Implement orphan file audit to catch mislinked objects `task_id:resource.orphan_audit`
-   [ ] Detect `resource_type` from filename or user input during upload `task_id:resource.detect_type_on_upload`
-   [ ] Store resource metadata in `AttackResourceFile` for frontend use `task_id:resource.persist_frontend_metadata`

🧠 Attack resource files share a common storage and metadata model, but differ significantly in validation, UI affordances, and where they are used within attacks. To support this diversity while enabling structured handling, each resource must declare a `resource_type`, which drives editor behavior, validation rules, and attack compatibility.

Supported `resource_type` values:

```python
 class AttackResourceType(str, enum.Enum):
     MASK_LIST = "mask_list"
     RULE_LIST = "rule_list"
     WORD_LIST = "word_list"
     CHARSET = "charset"
     DYNAMIC_WORD_LIST = "dynamic_word_list"  # Read-only, derived from cracked hashes
```

Each `AttackResourceFile` (defined in `app/models/attack_resource_file.py`) should include:

```python
 resource_type: AttackResourceType
 used_for_modes: list[AttackMode]           # Enforced compatibility with hashcat attack modes
 line_encoding: Literal["ascii", "utf-8"]   # Affects validation + editor behavior
 line_format: Literal["freeform", "mask", "rule", "charset"]
 source: Literal["upload", "generated", "linked"]
```

Editor behavior must respect the declared type:

| **Resource TypeEditable?Line FormatEncodingNotes** |      |              |       |                                           |
| -------------------------------------------------- | ---- | ------------ | ----- | ----------------------------------------- |
| `mask_list`                                        | ✅   | mask syntax  | ASCII | one per line, validated mask syntax       |
| `rule_list`                                        | ✅   | rule grammar | ASCII | strict per-line validation                |
| `word_list`                                        | ✅\* | freeform     | UTF-8 | loose rules, allow unicode, strip control |
| `charset`                                          | ✅   | charset def  | ASCII | e.g. `custom1 = abc123`, used in attacks  |
| `dynamic_word_list`                                | ❌   | N/A          | UTF-8 | read-only, generated from cracked hashes  |

(\*) Editing of large word lists may be disabled based on configured size thresholds.

Uploads must be initiated via CipherSwarm, which controls both presigned S3 access and DB row creation. No orphaned files should exist. The backend remains source of truth for metadata, content type, and validation enforcement.

🚨 Validation errors for resource line editing should follow FastAPI + Pydantic idioms. Use `HTTPException(status_code=422, detail=...)` for top-level form errors, and structured `ValidationError` objects for per-line issues:

Example response for per-line validation:

Suggested reusable model:

```python
 class ResourceLineValidationError(BaseModel):
     line_index: int
     content: str
     valid: bool = False
     message: str
```

```json
{
    "errors": [
        {
            "line_index": 3,
            "content": "+rfoo",
            "valid": false,
            "message": "Unknown rule operator 'f'"
        },
        {
            "line_index": 7,
            "content": "?u?d?l?l",
            "valid": false,
            "message": "Duplicate character class at position 3"
        }
    ]
}
```

This should be returned from:

-   `GET /resources/{id}/lines?validate=true`
-   `PATCH /resources/{id}/lines/{line_id}` if content is invalid

For valid input, return `204 No Content` or the updated fragment., which controls both presigned S3 access and DB row creation. No orphaned files should exist. The backend remains source of truth for metadata, content type, and validation enforcement.

🔒 All uploaded resource files must originate from the CipherSwarm backend, which controls presigned upload URLs and creates the corresponding database entry in \`AttackResourceFile `(defined in`app.models.attack_resource_file`)`. There should never be a case where a file exists in the object store without a corresponding DB row. The S3-compatible backend is used strictly for offloading large file transfer workloads (uploads/downloads by UI and agents), not as an authoritative metadata source.

💡 The UI should detect resource type and size to determine whether inline editing or full download is allowed. The backend should expose content metadata to guide this decision, such as `line_count`, `byte_size`, and `resource_type`. The frontend may display masks, rules, and short wordlists with line-level controls; long wordlists or binary-formatted resources must fall back to download/reupload workflows.

_Includes support for uploading, viewing, linking, and editing attack resources (mask lists, word lists, rule lists, and custom charsets). Resources are stored in an S3-compatible object store (typically MinIO), but CipherSwarm must track metadata, linkage, and validation. Users should be able to inspect and edit resource content directly in the browser via HTMX-supported interactions._

🔐 Direct editing is permitted only for resources under a safe size threshold (e.g., < 5,000 lines or < 1MB). Larger files must be downloaded, edited offline, and reuploaded. This threshold should be configurable via an environment variable or application setting (e.g., `RESOURCE_EDIT_MAX_SIZE_MB`, `RESOURCE_EDIT_MAX_LINES`) to allow for deployment-specific tuning.

📐 Line-Oriented Editing

For eligible resource types (e.g., masks, rules, short wordlists), the Web UI should support a line-oriented editor mode:

-   Each line can be edited, removed, or validated individually.
-   Validation logic should be performed per line to ensure syntax correctness (e.g., valid mask syntax, hashcat rule grammar).
-   Inline editing should be driven via HTMX (`hx-get`, `hx-post`, `hx-swap="outerHTML"`) using line-targeted components.

Suggested line-editing endpoints:

-   [ ] `GET /api/v1/web/resources/{id}/lines` – Paginated and optionally validated list of individual lines `task_id:resource.line_api_endpoints`
-   [ ] `POST /api/v1/web/resources/{id}/lines` – Add a new line `task_id:resource.add_line`
-   [ ] `PATCH /api/v1/web/resources/{id}/lines/{line_id}` – Modify an existing line `task_id:resource.update_line`
-   [ ] `DELETE /api/v1/web/resources/{id}/lines/{line_id}` – Remove a line `task_id:resource.delete_line`

The backend should expose a virtual `ResourceLine` model:

```python
 class ResourceLine(BaseModel):
     id: int
     index: int
     content: str
     valid: bool
     error_message: Optional[str]
```

These may be backed by temporary parsed representations for S3-stored resources, cached in memory or a staging DB table for edit sessions.

_Includes support for uploading, viewing, linking, and editing attack resources (mask lists, word lists, rule lists, and custom charsets). Resources are stored in an S3-compatible object store (typically MinIO), but CipherSwarm must track metadata, linkage, and validation. Users should be able to inspect and edit resource content directly in the browser via HTMX-supported interactions._

🔐 Direct editing is permitted only for resources under a safe size threshold (e.g., < 5,000 lines or < 1MB). Larger files must be downloaded, edited offline, and reuploaded. This threshold should be configurable via an environment variable or application setting (e.g., `RESOURCE_EDIT_MAX_SIZE_MB`, `RESOURCE_EDIT_MAX_LINES`) to allow for deployment-specific tuning.

-   [ ] `GET /api/v1/web/resources/` – Combined list of all resources (filterable by type) `task_id:resource.list_all`
-   [ ] `GET /api/v1/web/resources/{id}` – Metadata + linking `task_id:resource.get_by_id`
-   [ ] `GET /api/v1/web/resources/{id}/preview` – Small content preview `task_id:resource.preview`
-   [ ] `GET /api/v1/web/resources/upload` – Render form to upload new resource `task_id:resource.upload_form`
-   [ ] `POST /api/v1/web/resources/` – Upload metadata, request presigned upload URL `task_id:resource.upload_metadata`
-   [ ] `GET /api/v1/web/resources/{id}/edit` – View/edit metadata (name, tags, visibility) `task_id:resource.edit_metadata`
-   [ ] `PATCH /api/v1/web/resources/{id}` – Update metadata `task_id:resource.update_metadata`
-   [ ] `DELETE /api/v1/web/resources/{id}` – Remove or disable resource `task_id:resource.delete`
-   [x] `GET /api/v1/web/resources/{id}/content` – Get raw editable text content (masks, rules, wordlists) `task_id:resource.get_content`
-   [ ] `PATCH /api/v1/web/resources/{id}/content` – Save updated content (inline edit) `task_id:resource.update_content`
-   [ ] `POST /api/v1/web/resources/{id}/refresh_metadata` – Recalculate hash, size, and linkage from updated file `task_id:resource.refresh_metadata`

<!-- section: web-ui-api-authentication -->

### _👤 Authentication & Profile_

_Includes endpoints for administrator management of users and project access rights._

💡 _Note: Users can only update their own name and email. Role assignment and project membership changes are restricted to admins._

-   [ ] `POST /api/v1/web/auth/login` – Login `task_id:auth.login`
-   [ ] `POST /api/v1/web/auth/logout` – Logout `task_id:auth.logout`
-   [ ] `GET /api/v1/web/auth/me` – Profile details `task_id:auth.me`
-   [ ] `PATCH /api/v1/web/auth/me` – Update name/email `task_id:auth.update_me`
-   [ ] `POST /api/v1/web/auth/change_password` – Change password `task_id:auth.change_password`
-   [ ] `GET /api/v1/web/auth/context` – Get current user + project context `task_id:auth.get_context`
-   [ ] `POST /api/v1/web/auth/context` – Switch active project `task_id:auth.set_context`
-   [ ] `GET /api/v1/web/users/` – 🔐 Admin: list all users (paginated, filterable) `task_id:auth.list_users`
-   [ ] `POST /api/v1/web/users/` – 🔐 Admin: create user `task_id:auth.create_user`
-   [ ] `GET /api/v1/web/users/{id}` – 🔐 Admin: view user detail `task_id:auth.get_user`
-   [ ] `PATCH /api/v1/web/users/{id}` – 🔐 Admin: update user info or role `task_id:auth.update_user`
-   [ ] `DELETE /api/v1/web/users/{id}` – 🔐 Admin: deactivate or delete user `task_id:auth.delete_user`
-   [ ] `GET /api/v1/web/projects/` – 🔐 Admin: list all projects `task_id:auth.list_projects`
-   [ ] `POST /api/v1/web/projects/` – 🔐 Admin: create new project `task_id:auth.create_project`
-   [ ] `GET /api/v1/web/projects/{id}` – 🔐 Admin: view project info `task_id:auth.get_project`
-   [ ] `PATCH /api/v1/web/projects/{id}` – 🔐 Admin: update name, visibility, user assignment `task_id:auth.update_project`
-   [ ] `DELETE /api/v1/web/projects/{id}` – 🔐 Admin: archive project `task_id:auth.delete_project`

<!-- section: web-ui-api-ux-support -->

### _🔧 UX Support & Utility_

#### 🧩 Purpose

This section defines endpoints used by the frontend to dynamically populate UI elements, fetch partials, and support dropdowns, summaries, and metadata helpers that don't belong to a specific resource type.

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/web/options/agents` – Populate agent dropdowns `task_id:ux.populate_agents`
-   [ ] `GET /api/v1/web/options/resources` – Populate resource selectors (mask, wordlist, rule) `task_id:ux.populate_resources`
-   [ ] `GET /api/v1/web/options/charsets` – Return preset charset definitions `task_id:ux.charset_presets`
-   [ ] `GET /api/v1/web/dashboard/summary` – Return campaign/task summary data for dashboard widgets `task_id:ux.summary_dashboard`
-   [ ] `GET /api/v1/web/health/overview` – Lightweight system health view `task_id:ux.system_health_overview`
-   [ ] `GET /api/v1/web/health/components` – Detailed health of core services (MinIO, Redis, DB) `task_id:ux.system_health_components`
-   [ ] `GET /api/v1/web/modals/rule_explanation` – Return rule explanation partials `task_id:ux.rule_explanation_modal`
-   [ ] `GET /api/v1/web/fragments/validation` – Return a reusable validation error component `task_id:ux.fragment_validation_errors`
-   [ ] `GET /api/v1/web/fragments/metadata_tag` – Partial for UI metadata tags (e.g., "ephemeral", "auto-generated") `task_id:ux.fragment_metadata_tag`

    Partial for UI metadata tags (e.g., "ephemeral", "auto-generated"). Used to display reusable indicators across multiple views — e.g., ephemeral wordlist tags in attack detail, auto-generated resource badges, or benchmark status pills. This endpoint should return a rendered HTML fragment suitable for HTMX swaps.

---

### _📂 Crackable Uploads_

<!-- section: web-ui-api-crackable-uploads-implementation-tasks -->

#### 🧩 Implementation Tasks

-   [ ] Implement `GET /api/v1/web/hash/guess` endpoint for live hash validation and guessing via service layer `task_id:guess.web_endpoint`
-   [ ] Ensure Crackable Upload UI uses guess response to validate pasted hashes before campaign creation `task_id:guess.integrate_into_crackable_uploads`
-   [ ] Add hash type selection UI allowing user to confirm or override guess results
        Display `name-that-hash` results with confidence scores and let user manually adjust if needed
        `task_id:upload.hash_type_override_ui`

*   [ ] Automatically generate a temporary project-scoped wordlist when usernames or prior passwords are available from the uploaded content
        Useful for NTLM pairs, `/etc/shadow`, or cracked zip headers
        `task_id:upload.create_dynamic_wordlist`

*   [ ] Add confirmation/preview screen before launching a generated campaign
        Shows detected hash type, parsed sample lines, and proposed attacks/resources
        `task_id:upload.preview_summary_ui`

To streamline the cracking workflow for non-technical users, we should support uploading raw data (files or hash fragments) and automating the detection, validation, and campaign creation process. The system must distinguish between:

-   **File uploads** (e.g., `.zip`, `.docx`, `.pdf`, `.kdbx`) that require binary hash extraction
-   **Pasted or raw hash text** (e.g., lines from `/etc/shadow`, `impacket`'s `secretsdump`, Cisco config dumps)

In the case of pasted hashes, the system should automatically isolate the actual hash portion, remove surrounding metadata, and sanitize formatting issues. This includes stripping login expiration flags from shadow lines or extracting just the hash field from NTLM pairs.

**Use cases include:**

-   Uploading a file (e.g., `.zip`, `.pdf`, `.docx`) to extract hashes
-   Pasting a hash from a source like `/etc/shadow`, even if it includes surrounding junk

This process should:

-   Extract or isolate the hash automatically
-   Perform validation on the extracted hash (type, syntax, format)
-   Prevent campaign creation if the hash is malformed or would fail in hashcat
-   Detect the hash type
-   Validate hashcat compatibility
-   Provide preview/feedback of what will be created
-   Automatically create:

    -   A `HashList`
    -   A `Campaign`
    -   One or more preconfigured `Attacks`

Users can then launch the campaign immediately or review/edit first.

<!-- section: web-ui-api-crackable-uploads-required-endpoints -->

#### 🔧 Required Endpoints

-   [ ] `POST /api/v1/web/uploads/` – Upload file or pasted hash blob `task_id:upload.upload_file_or_hash`
-   [ ] `GET /api/v1/web/uploads/{id}/status` – Show analysis result: hash type, extracted preview, validation state `task_id:upload.show_analysis_result`
-   [ ] `POST /api/v1/web/uploads/{id}/launch_campaign` – Generate resources and create campaign with default attacks `task_id:upload.launch_campaign`
-   [ ] `GET /api/v1/web/uploads/{id}/errors` – Show extraction errors or unsupported file type warnings `task_id:upload.show_extraction_errors`
-   [ ] `DELETE /api/v1/web/uploads/{id}` – Remove discarded or invalid upload `task_id:upload.delete_upload`
-   [ ] `GET /api/v1/web/options/agents` – Dropdown/populate menu `task_id:ux.populate_agents_dropdown`
-   [ ] `GET /api/v1/web/options/resources` – Mask/rule/wordlist selection `task_id:ux.populate_resources_dropdown`
-   [ ] `GET /api/v1/web/dashboard/summary` – Campaign/agent/task summary metrics `task_id:ux.summary_dashboard`
-   [ ] `GET /api/v1/web/health/overview` – System health snapshot (agents online, DB latency, task backlog) `task_id:ux.system_health_overview`
-   [ ] `GET /api/v1/web/health/components` – Detail view for system metrics (minio, redis, db) `task_id:ux.system_health_components`

<!-- section: web-ui-api-live-htmx-websockets -->

### _🛳️ Live HTMX / WebSocket Feeds_

These endpoints serve as centralized websocket-compatible feeds that HTMX components can subscribe to for real-time update triggers across the web UI. All dynamic list/detail views related to Campaigns, Attacks, Agents, Hash Lists, and Hash Items should leverage this mechanism.

HTMX v2 uses the `ws` extension for WebSocket support. On the client side, views should include:

```html
<div hx-ext="ws" ws-connect="/api/v1/web/live/agents">
    <!-- dynamic content area -->
</div>
```

Each server-side endpoint below must:

-   Be implemented as an ASGI WebSocket route using FastAPI's `WebSocket` support
-   Emit properly formatted **HTML partials** (HTMX expects rendered content, not raw JSON)
-   Triggered by backend model events or service-layer updates
-   Optionally scoped by project/user context
-   Should include a structured message format or trigger a refresh if content is too complex

#### 🧠 Broadcast Triggers by Feed

-   `campaigns`: on `Attack` or `Task` state changes
-   `agents`: on heartbeat, `DeviceStatus`, or `AgentError`
-   `toasts`: when new `CrackResult` is submitted

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/web/live/campaigns` – Updated rows/fragments for campaign dashboard `task_id:live.campaign_feed`
-   [ ] `GET /api/v1/web/live/toasts` – Batched cracked-hash alerts `task_id:live.toast_feed`
-   [ ] `GET /api/v1/web/live/agents` – Current agent state update feed (may trigger HTML fragment refresh or a targeted `hx-get`) `task_id:live.agent_feed`

💡 Consider fragment-splitting: Toasts and campaigns should push HTML, but agents may push a minimal JSON payload that triggers an HTMX `hx-get` swap for the actual updated fragment.

#### 🧩 WebSocket Handler Implementation Tasks

-   [ ] Implement WebSocket route: `GET /api/v1/web/live/campaigns`
        Broadcast HTML fragments when an `Attack` or `Task` state changes
        `task_id:live.campaign_feed_handler`

-   [ ] Implement WebSocket route: `GET /api/v1/web/live/agents`
        Broadcast agent performance/heartbeat updates; may send HTML or trigger HTMX swap
        `task_id:live.agent_feed_handler`

-   [ ] Implement WebSocket route: `GET /api/v1/web/live/toasts`
        Broadcast cracked hash notifications to display as toasts
        `task_id:live.toast_feed_handler`

-   [ ] Establish pub/sub or internal queue broadcaster system (Redis, asyncio, etc.)
        `task_id:live.websocket_broadcast_layer`

-   [ ] Connect SQLAlchemy/ORM event hooks to broadcast triggers
        (e.g., `after_update` on Task, Agent, CrackResult)
        `task_id:live.websocket_event_hooks`

-   [ ] Define and document standard message format:
        Include `type`, `id`, `html` or `refresh_target`
        `task_id:live.websocket_message_format`

-   [ ] Handle WebSocket authorization via session or project-scoped JWT
        `task_id:live.websocket_auth_check`

-   [x] Add robust unit tests for KeyspaceEstimator covering all attack modes and edge cases

-   [x] Ensure all estimation logic (AttackEstimationService, endpoints, tests) uses strong typing (Pydantic models, enums) instead of dicts/Any for attack/resource parameters
